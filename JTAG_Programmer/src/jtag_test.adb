pragma Style_Checks (Off);
 
with STM32F0x0;      use STM32F0x0;
with STM32F0x0.RCC;  use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;
with STM32F0x0.SPI; use STM32F0x0.SPI;
with STM32F0x0.USART; use STM32F0x0.USART;
with STM32F0x0.DMA; use STM32F0x0.DMA;
with System.Storage_Elements; use System.Storage_Elements;
 
procedure jtag_test is
   TMS_Pin : constant := 4; -- PA4
   TCK_Pin : constant := 5; -- PA5
   TDO_Pin : constant := 6; -- PA6 (Input)
   TDI_Pin : constant := 7; -- PA7
   type Bit_Array is array (Natural range <>) of Bit;
 
   Buffer_Size : constant := 512;
   type Byte_Array is array (0 .. Buffer_Size - 1) of Byte with Volatile;
   DMA_Buffer  : aliased Byte_Array;  --  USART2 RX  (DMA1 Channel 5)
   DMA1_Buffer : aliased Byte_Array;  --  USART1 RX  (DMA1 Channel 3)
 
   -- Helper procedures to drive GPIO pins (PAx) using BSRR
   procedure Pin_High (Pin : Natural) is
   begin
      GPIOA_Periph.BSRR.BS.Arr (Pin) := 1;
   end Pin_High;
 
   procedure Pin_Low (Pin : Natural) is
   begin
      GPIOA_Periph.BSRR.BR.Arr (Pin) := 1;
   end Pin_Low;
 
   procedure SPI_Enable is
   begin
      RCC_Periph.APB2ENR.SPI1EN := 1;
 
      --  CR1: Master mode, Baud rate 12MHz, Software Slave Mgmt, Internal Slave Select
      SPI1_Periph.CR1 := (MSTR     => 1,
                          BR       => 1,
                          CPOL     => 1,
                          CPHA     => 1,
                          LSBFIRST => 0,
                          SSM      => 1,
                          SSI      => 1,
                          SPE      => 1,
                          others   => <>);
 
      --  CR2: 8-bit Data Size (7 is 8-bit), FRXTH must be 1 for 8-bit/Byte access
      SPI1_Periph.CR2 := (DS       => 7,
                          FRXTH    => 1,
                          others   => <>);
 
      GPIOA_Periph.AFRL.Arr (5) := 0; --  AF0 for SPI1
      GPIOA_Periph.AFRL.Arr (6) := 0; --  AF0 for SPI1
      GPIOA_Periph.AFRL.Arr (7) := 0; --  AF0 for SPI1
 
      GPIOA_Periph.MODER.Arr (5) := 2;
      GPIOA_Periph.MODER.Arr (6) := 2;
      GPIOA_Periph.MODER.Arr (7) := 2;
 
 
   end SPI_Enable;
 
   procedure SPI_Disable is
   begin
      while SPI1_Periph.SR.BSY /= 0 loop null; end loop;
 
      Pin_High (TCK_Pin);
      Pin_HIGH (TDI_Pin);
      Pin_Low (TMS_Pin);
 
      GPIOA_Periph.MODER.Arr (5) := 1;
      GPIOA_Periph.MODER.Arr (6) := 0;
      GPIOA_Periph.MODER.Arr (7) := 1;
      RCC_Periph.APB2ENR.SPI1EN := 0;
   end SPI_Disable;
 
   --  Setting GPIO
   procedure Initialize_Hardware is
   begin
      --  Enable GPIOA
      RCC_Periph.AHBENR.IOPAEN := 1;
      RCC_Periph.AHBENR.DMA1EN := 1;
 
      --  Enable USART1 & USART2
      RCC_Periph.APB2ENR.USART1EN := 1;
      RCC_Periph.APB1ENR.USART2EN := 1;
 
      --  PA2, PA3, PA4, PA5, PA6, PA7, PA9, PA10
      GPIOA_Periph.MODER.Arr (2) := 2;
      GPIOA_Periph.MODER.Arr (3) := 2;
      GPIOA_Periph.MODER.Arr (4) := 1;
      GPIOA_Periph.MODER.Arr (5) := 1;
      GPIOA_Periph.MODER.Arr (6) := 0;
      GPIOA_Periph.MODER.Arr (7) := 1;
      GPIOA_Periph.MODER.Arr (9) := 2;
      GPIOA_Periph.MODER.Arr (10) := 2;
 
      --  Set Alternate function for PA2, PA3 (AF1 for USART2)
      GPIOA_Periph.AFRL.Arr (2) := 1; --  AF1 for USART2
      GPIOA_Periph.AFRL.Arr (3) := 1; --  AF1 for USART2
      GPIOA_Periph.AFRH.Arr (9) := 1; --  AF1 for USART1
      GPIOA_Periph.AFRH.Arr (10) := 1; --  AF1 for USART1
 
      --  Initial CS Low(PA4) and TCK, TMS, TDI Low
      GPIOA_Periph.BSRR.BR.Arr (4) := 1;
      GPIOA_Periph.BSRR.BS.Arr (5) := 1;
      GPIOA_Periph.BSRR.BR.Arr (6) := 1;
      GPIOA_Periph.BSRR.BR.Arr (7) := 1;
 
      --  USART1 Configuration (19200 Baud @ 48MHz)
      USART1_Periph.BRR := (DIV_Mantissa => 16#9C#,
                            DIV_Fraction => 16#04#,
                            others       => <>);
 
      --  Enable DMA receive request on USART1
      USART1_Periph.CR3.DMAR := 1;
 
      --  Enable UART, Transmit, and Receive
      USART1_Periph.CR1 := (UE     => 1,
                            TE     => 1,
                            RE     => 1,
                            OVER8  => 0,
                            others => <>);
 
      --  DMA1 Channel 3 -- USART1 RX (fixed mapping on STM32F070RB)
      DMA1_Periph.CPAR3 := UInt32 (To_Integer (USART1_Periph.RDR'Address));
      DMA1_Periph.CMAR3 := UInt32 (To_Integer (DMA1_Buffer'Address));
      DMA1_Periph.CNDTR3.NDT := UInt16 (Buffer_Size);
      DMA1_Periph.CCR3 := (MINC   => 1,
                           CIRC   => 1,
                           PL     => 2,
                           EN     => 1,
                           others => <>);
 
      --  USART2 Configuration (2,000,000 Baud @ 48MHz)
      USART2_Periph.BRR := (DIV_Mantissa => 16#01#,
                            DIV_Fraction => 16#08#,
                            others       => <>);
      
      USART2_Periph.CR3.DMAR := 1;
 
      --  Enable UART, Transmit, and Receive
      USART2_Periph.CR1 := (UE     => 1,
                            TE     => 1,
                            RE     => 1,
                            OVER8  => 0,
                            others => <>);
 
      DMA1_Periph.CPAR5 := UInt32 (To_Integer (USART2_Periph.RDR'Address));
 
      DMA1_Periph.CMAR5 := UInt32 (To_Integer (DMA_Buffer'Address));
 
      DMA1_Periph.CNDTR5.NDT :=  UInt16 (Buffer_Size);
 
      DMA1_Periph.CCR5 := (MINC   => 1,
                           CIRC   => 1,
                           PL     => 2,
                           EN     => 1,
                          others => <>);
   end Initialize_Hardware;
 
   procedure Pulse_TCK is
   begin
      GPIOA_Periph.BSRR.BR.Arr (TCK_Pin) := 1;
      GPIOA_Periph.BSRR.BS.Arr (TCK_Pin) := 1;
   end Pulse_TCK;
 
   function Get_TDO return Bit is
   begin
      return GPIOA_Periph.IDR.IDR.Arr (TDO_Pin);
   end Get_TDO;
 
   procedure Read_TDO is
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-DR
      for I in 0 .. 32 loop
         if (I = 32) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit Shift-DR
         end if;
         Pulse_TCK;
      end loop;
      Pin_High (TMS_PIN);
      Pulse_TCK; -- UPDATE-DR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
   end Read_TDO;
 
   procedure Send_Command (c : Bit_Array) is
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pulse_TCK; -- SELECT-IR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-IR
      Pulse_TCK;
      for I in 0 .. 7 loop
         if c (I) = 1 then
            Pin_High (TDI_Pin);
         else
            Pin_Low (TDI_Pin);
         end if;
         if (I = 7) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit Shift-IR
 
         end if;
         Pulse_TCK;
         --  delay 0.0001;
      end loop;
      Pulse_TCK; -- UPDATE-IR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
 
   end Send_Command;
 
   function Transceive_Byte_JTAG (Data_Out : Byte) return Byte is
      DR_Byte : Byte with Address => SPI1_Periph.DR'Address;
   begin
      while SPI1_Periph.SR.TXE = 0 loop null; end loop;
      DR_Byte := Data_Out;
      return DR_Byte;
   end Transceive_Byte_JTAG;
 
   procedure Transceive_Last_Byte_JTAG (Data_Out : Byte) is
      TDO_Byte : Byte := 0;
   begin
      for Bit in reverse 0 .. 7 loop
         if (Bit = 0) then
            Pin_High (TMS_Pin); -- Pull TMS high on the last bit to exit Shift-DR
         end if;
 
         if (Data_Out and Shift_Left (1, Bit)) /= 0 then
            Pin_High (TDI_Pin);
         else
            Pin_Low (TDI_Pin);
         end if;
 
         Pulse_TCK;
      end loop;
   end Transceive_Last_Byte_JTAG;
 
   function Data_Available_UART return Boolean is
   begin
      return USART2_Periph.ISR.RXNE /= 0;
   end Data_Available_UART;
 
   function Receive_UART return Byte is
   begin
      return Byte (USART2_Periph.RDR.RDR);
   end Receive_UART;
 
   --  MAIN FUNCTIONS : CALLED BY UART COMMANDS
   procedure Reset_TAP is
   begin
      Pin_High (TMS_PIN);
      for I in 1 .. 6 loop
         Pulse_TCK;
      end loop;
   end Reset_TAP;
 
   function Read_IDCODE return Bit_Array is
      IDCODE : Bit_Array (0 .. 31);
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-DR
      for I in 0 .. 31 loop
         if (I = 31) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit
         end if;
         IDCODE (I) := Get_TDO;
         Pulse_TCK;
      end loop;
      Pin_High (TMS_PIN);
      Pulse_TCK; -- UPDATE-DR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
      return IDCODE;
   end Read_IDCODE;
 
   procedure Init_Configuration is
      cmd : Bit_Array (0 .. 7);
   begin
      
      delay 0.001; -- Delay to get to CONFIGURATION state
 
      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command to read Status Register (IR=0x41)
      Send_Command (cmd); -- Send a command to the FPGA (0x41 in this case)
 
      Pin_Low (TMS_PIN);
      for I in 1 .. 10 loop
         Pulse_TCK; -- RUN-TEST/IDLE
      end loop;
      Read_TDO; -- Read the TDO output after sending the command
 
      cmd := (1, 0, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x15)
      Send_Command (cmd); -- Send the command
 
      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);
 
      --  Small Delay
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
 
      Read_TDO; -- Read TDO for staus register
      cmd := (1, 0, 1, 0, 0, 0, 0, 0); -- Example command (IR=0x05)
      Send_Command (cmd); -- Send the command
      cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- Example command (IR=0x02)
      Send_Command (cmd);
      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);
      Read_TDO; -- Read TDO for staus register
      cmd := (1, 0, 0, 1, 0, 0, 0, 0); -- Example command (IR=0x09)
      Send_Command (cmd); -- Send the command
      cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- Example command (IR=0x02)
      Send_Command (cmd);
      cmd := (0, 1, 0, 1, 1, 1, 0, 0); -- Example command (IR=0x3A)
      Send_Command (cmd);
      cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- Example command (IR=0x02)
      Send_Command (cmd);
      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);
      Read_TDO; -- Read TDO for staus register
      cmd := (1, 0, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x15)
      Send_Command (cmd); -- Send the command
      cmd := (0, 1, 0, 0, 1, 0, 0, 0); -- Example command (IR=0x12)
      Send_Command (cmd);
      cmd := (1, 1, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x17)
      Send_Command (cmd);
   end Init_Configuration;
 
   Trash            : Byte;
    cmd             : Bit_Array (0 .. 7);
   Write_Idx        : Natural;
   Read_Idx         : Natural := 0;
   Last_Write_Idx   : Natural := Buffer_Size; -- sentinel: impossible initial value
   Stable_Count     : Natural := 0;
   Stable_Threshold : constant := 10_000; -- tune this to ~several ms of silence
   Has_Data         : Boolean := False;
   procedure Send_Configuration_Bitstream is
      cmd : Bit_Array (0 .. 7);
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-DR
      Pulse_TCK; -- Shift-DR
      SPI_Enable;
      loop
               Write_Idx := Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT);
 
      --  Check if the write pointer has moved since last iteration
      if Write_Idx /= Last_Write_Idx then
         --  New data has arrived: reset the stability counter
         Stable_Count   := 0;
         Last_Write_Idx := Write_Idx;
      else
         --  Write pointer is stable (no new bytes from DMA this iteration)
         if Has_Data then
            Stable_Count := Stable_Count + 1;
         end if;
      end if;
 
      --  Process any newly arrived bytes, keeping the last one in reserve
      if Write_Idx /= Read_Idx then
         Has_Data := True;
 
         if Write_Idx > Read_Idx then
            for I in Read_Idx .. Write_Idx - 2 loop
               Trash := Transceive_Byte_JTAG (DMA_Buffer (I));
            end loop;
            Read_Idx := Write_Idx - 1;
         else
            if Write_Idx = 0 then
               for I in Read_Idx .. Buffer_Size - 2 loop
                  Trash := Transceive_Byte_JTAG (DMA_Buffer (I));
               end loop;
               Read_Idx := Buffer_Size - 1;
            else
               for I in Read_Idx .. Buffer_Size - 1 loop
                  Trash := Transceive_Byte_JTAG (DMA_Buffer (I));
               end loop;
               for I in 0 .. Write_Idx - 2 loop
                  Trash := Transceive_Byte_JTAG (DMA_Buffer (I));
               end loop;
               Read_Idx := Write_Idx - 1;
            end if;
         end if;
      end if;
 
      --  Timeout: write pointer has been stable long enough after seeing data
      if Has_Data and then Stable_Count >= Stable_Threshold then
         SPI_Disable;
         Transceive_Last_Byte_JTAG (DMA_Buffer (Read_Idx));
                  Read_Idx := (Read_Idx + 1) mod Buffer_Size;
                  Pulse_TCK; -- UPDATE-DR
                  Pin_Low (TMS_PIN);
                  Pulse_TCK; -- RUN-TEST/IDLE
                  cmd := (0, 1, 0, 1, 0, 0, 0, 0); -- (IR=0x0A)
                  Send_Command (cmd);
                  Read_TDO;
                  cmd := (0, 0, 0, 1, 0, 0, 0, 0); -- (IR=0x08)
                  Send_Command (cmd);
                  --  Read SRAM
                  cmd := (0, 1, 0, 1, 1, 1, 0, 0); -- IR=0x3A)
                  Send_Command (cmd);
                  cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- (IR=0x02)
                  Send_Command (cmd);
                  cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- (IR=0x41)
                  Send_Command (cmd);
                  Read_TDO;
                  exit;
               
         end if;
 
      end loop;
   end Send_Configuration_Bitstream;
 
procedure Send_Firmware is
      --  Read indices into the two circular DMA buffers for this session
      U2_Read_Idx : Natural;  --  USART2 RX DMA (Laptop -> Tang Nano)
      U1_Read_Idx : Natural;  --  USART1 RX DMA (Tang Nano -> Laptop)
      U2_Write    : Natural;
      U1_Write    : Natural;
   begin
      --  Wait for any in-flight USART2 TX to finish before reconfiguring
      while USART2_Periph.ISR.TC = 0 loop null; end loop;
 
      --  Reconfigure USART2 to 19200 baud to match USART1 / Tang Nano side
      --  USART2_Periph.CR1 := (UE => 0, others => <>);
      --  USART2_Periph.BRR := (DIV_Mantissa => 16#9C#, DIV_Fraction => 16#04#, others => <>);
      --  USART2_Periph.CR3.DMAR := 1;
      --  USART2_Periph.CR1 := (UE => 1, TE => 1, RE => 1, others => <>);
 
      --  --  Reconfigure DMA1 Channel 5 (USART2 RX) with updated baud — disable,
      --  --  reload CNDTR, re-enable so the channel is in a clean state.
      --  DMA1_Periph.CCR5.EN  := 0;
      --  DMA1_Periph.CNDTR5.NDT := UInt16 (Buffer_Size);
      --  DMA1_Periph.CCR5.EN  := 1;
 
      --  Snapshot current DMA write positions so we ignore bytes that
      --  arrived before Send_Firmware was entered.
      U2_Read_Idx := Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT);
      U1_Read_Idx := Buffer_Size - Natural (DMA1_Periph.CNDTR3.NDT);
 
      loop
         --  ---- Part A: Laptop (USART2 DMA buffer) --> Tang Nano (USART1 TX) ----
         U2_Write := Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT);
 
         while U2_Read_Idx /= U2_Write loop
            while USART1_Periph.ISR.TXE = 0 loop null; end loop;
            USART1_Periph.TDR.TDR := RDR_RDR_Field (DMA_Buffer (U2_Read_Idx));
            U2_Read_Idx := (U2_Read_Idx + 1) mod Buffer_Size;
         end loop;
 
         --  ---- Part B: Tang Nano (USART1 DMA buffer) --> Laptop (USART2 TX) ----
         U1_Write := Buffer_Size - Natural (DMA1_Periph.CNDTR3.NDT);
 
         while U1_Read_Idx /= U1_Write loop
            while USART2_Periph.ISR.TXE = 0 loop null; end loop;
            USART2_Periph.TDR.TDR := RDR_RDR_Field (DMA1_Buffer (U1_Read_Idx));
            U1_Read_Idx := (U1_Read_Idx + 1) mod Buffer_Size;
         end loop;
      end loop;
   end Send_Firmware;
 
begin
   --  TODO: Add UART command handling to trigger different JTAG operations (e.g., read IDCODE, send configuration bitstream, etc.)
   Initialize_Hardware;
   Reset_TAP;
   Init_Configuration;
   Send_Configuration_Bitstream;
   Send_Firmware;
end jtag_test;