with STM32F0x0; use STM32F0x0;
with STM32F0x0.RCC; use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;
with STM32F0x0.SPI; use STM32F0x0.SPI;
with STM32F0x0.USART; use STM32F0x0.USART;
with Ada.Real_Time; use Ada.Real_Time;

procedure uart_example is

   procedure Initialize_Hardware is
   begin
      --  Enable GPIOA and GPIOB
      RCC_Periph.AHBENR.IOPAEN := 1;
      RCC_Periph.AHBENR.IOPBEN := 1;

      --  Enable SPI1 and USART2
      RCC_Periph.APB2ENR.SPI1EN := 1;
      RCC_Periph.APB1ENR.USART2EN := 1;

      --  PA5, PA6, PA7 (SPI) and PA2, PA3 (UART)
      GPIOA_Periph.MODER.Arr (2) := 2;
      GPIOA_Periph.MODER.Arr (3) := 2;
      GPIOA_Periph.MODER.Arr (5) := 2;
      GPIOA_Periph.MODER.Arr (6) := 2;
      GPIOA_Periph.MODER.Arr (7) := 2;
      --  PA4 Output for CS
      GPIOA_Periph.MODER.Arr (4) := 1;

      --  Set Alternate function for PA5, PA6, PA7 (AF0 for SPI1 on F070)
      GPIOA_Periph.AFRL.Arr (2) := 1; --  AF1 for USART2
      GPIOA_Periph.AFRL.Arr (3) := 1; --  AF1 for USART2
      GPIOA_Periph.AFRL.Arr (5) := 0; --  AF0 for SPI1
      GPIOA_Periph.AFRL.Arr (6) := 0; --  AF0 for SPI1
      GPIOA_Periph.AFRL.Arr (7) := 0; --  AF0 for SPI1

      --  Set PB2, PB3, PB4, and PB5 as Output and PB1 as Input
      GPIOB_Periph.MODER.Arr (1) := 0;
      GPIOB_Periph.MODER.Arr (2) := 1;
      GPIOB_Periph.MODER.Arr (3) := 1;
      GPIOB_Periph.MODER.Arr (4) := 1;
      GPIOB_Periph.MODER.Arr (5) := 1;

      -- Set  PB2, PB3 High and PB4, PB5 Low
      GPIOB_Periph.BSRR.BS.Arr (2) := 1;
      GPIOB_Periph.BSRR.BS.Arr (3) := 1;
      GPIOB_Periph.BSRR.BR.Arr (4) := 1;
      GPIOB_Periph.BSRR.BR.Arr (5) := 1;

      --  PI1 Configuration (SVD Record)
      --  CR1: Master mode, Baud rate 12MHz, Software Slave Mgmt, Internal Slave Select
      SPI1_Periph.CR1 := (MSTR     => 1,
                          BR       => 1,
                          LSBFIRST => 0,
                          SSM      => 1,
                          SSI      => 1,
                          SPE      => 1,
                          others   => <>);

      --  CR2: 8-bit Data Size (7 is 8-bit), FRXTH must be 1 for 8-bit/Byte access
      SPI1_Periph.CR2 := (DS       => 7,
                          FRXTH    => 1,
                          others   => <>);

      -- USART2 Configuration (115200 Baud @ 48MHz)
      -- 16#01A1# -> Mantissa 26 (16#1A#), Fraction 1
      USART2_Periph.BRR := (DIV_Mantissa => 16#18#,
                            DIV_Fraction => 0,
                            others       => <>);

      -- Enable UART, Transmit, and Receive
      USART2_Periph.CR1 := (UE     => 1,
                            TE     => 1,
                            RE     => 1,
                            OVER8  => 1,
                            others => <>);

      --  Initial CS High (PA4)
      GPIOA_Periph.BSRR.BS.Arr (4) := 1;
   end Initialize_Hardware;

   --  Checks sends and receives
   function Transceive (Data_Out : Byte) return Byte is
   DR_8 : Byte with Address => SPI1_Periph.DR'Address;
   begin
      while SPI1_Periph.SR.TXE = 0 loop null; end loop;
      DR_8 := Data_Out;
      while SPI1_Periph.SR.RXNE = 0 loop null; end loop;
      return DR_8;
   end Transceive;

   function Transceive_File (Data_Out : Byte) return Byte is
   DR_8 : Byte with Address => SPI1_Periph.DR'Address;
   begin
      while SPI1_Periph.SR.TXE = 0 loop null; end loop;
      DR_8 := Data_Out;
      return DR_8;
   end Transceive_File;

   function Data_Available_UART return Boolean is
   begin
      return USART2_Periph.ISR.RXNE /= 0;
   end Data_Available_UART;

   function Receive_UART return Byte is
   begin
      return Byte (USART2_Periph.RDR.RDR);
   end Receive_UART;

   procedure CS_Low is
   begin
      GPIOA_Periph.BSRR.Br.Arr (4) := 1;
   end CS_Low;

   procedure CS_High is
   begin
      GPIOA_Periph.BSRR.BS.Arr (4) := 1;
   end CS_High;

   Incoming_Byte : Byte;
   Trash         : Byte;
   In_Transfer   : Boolean := False;
   Timeout_Count : Natural := 0;
   type Status_Buffer is array (1 .. 7) of Byte;
   Status_Data : Status_Buffer;

   -- A helper to avoid code repetition
   procedure Send_Command (Cmd : Byte) is
      Dummy : Byte;
   begin
      CS_Low;

      Dummy := Transceive (Cmd);
      Dummy := Transceive (16#00#);

      -- Wait for SPI to finish last bit before raising CS
      while SPI1_Periph.SR.BSY /= 0 loop null; end loop;

      CS_High;
   end Send_Command;

   --  Main loop
begin
   Initialize_Hardware;
   delay until Ada.Real_Time.Clock + Milliseconds (10);

   --  Pulse Reconfig_N PB2
   GPIOB_Periph.BSRR.BR.Arr (2) := 1;
   delay until Ada.Real_Time.Clock + Milliseconds (2);
   GPIOB_Periph.BSRR.BS.Arr (2) := 1;

   --  Check if PB1 ready = 1
   while GPIOB_Periph.IDR.IDR.Arr (1) = 0 loop null; end loop;

   --  Read Status (0x41) + 7 dummy bytes
   CS_Low;
   Trash := Transceive (16#41#);
   for I in 1 .. 7 loop Status_Data (I) := Transceive (16#00#); end loop;
   while SPI1_Periph.SR.BSY /= 0 loop null; end loop;
   CS_High;
   delay until Ada.Real_Time.Clock + Milliseconds (1);
   
   --  Wait for bit 13 to be 0
   if (Status_Data (6) and 16#02#) = 1 then
      --  Erase SRAM
      Send_Command (16#05#);
      delay until Ada.Real_Time.Clock + Milliseconds (1);
   end if;

   --  Check if PB1 ready = 1
   while GPIOB_Periph.IDR.IDR.Arr (1) = 0 loop null; end loop;

   --  Read ID (0x11) + 7 dummy bytes
   CS_Low;
   Trash := Transceive (16#11#);
   for I in 1 .. 7 loop Trash := Transceive (16#00#); end loop;
   while SPI1_Periph.SR.BSY /= 0 loop null; end loop;
   CS_High;
   delay until Ada.Real_Time.Clock + Milliseconds (1);

   --  Init Adress
   Send_Command (16#12#);
   delay until Ada.Real_Time.Clock + Milliseconds (1);

   --  Write Enable (0x15)
   Send_Command (16#15#);
   delay until Ada.Real_Time.Clock + Milliseconds (1);

   loop
      if Data_Available_UART then
         Incoming_Byte := Receive_UART;

         --  If this is the first byte of a stream, pull CS low
         if not In_Transfer then
            CS_Low;
            Trash := Transceive (16#3B#); --  Write Data
            In_Transfer := True;
         end if;

         --  Forward to SPI
         Trash := Transceive_File (Incoming_Byte);

         --  Reset timeout because we are active
         Timeout_Count := 0;
      else
         --  If we were in a transfer but no data is coming
         if In_Transfer then
            Timeout_Count := Timeout_Count + 1;
            --  Small artificial delay to define "End of File"
            if Timeout_Count > 50_000 then
               --  Wait for SPI to finish last bits
               while SPI1_Periph.SR.BSY /= 0 loop null; end loop;

               CS_High;
               Send_Command (16#3A#); --  Write Disable
               delay until Ada.Real_Time.Clock + Milliseconds (1);
               In_Transfer := False;
               Timeout_Count := 0;

               --  Read Status (0x41) + 7 dummy bytes
               CS_Low;
               Trash := Transceive (16#41#);
               for I in 1 .. 7 loop Trash := Transceive (16#00#); end loop;
               while SPI1_Periph.SR.BSY /= 0 loop null; end loop;
               CS_High;
               delay until Ada.Real_Time.Clock + Milliseconds (1);
               if (Status_Data (6) and 16#02#) = 1 then
                  --  Go back to beggining TODO
                  null;
               end if;
            end if;
         end if;
      end if;
   end loop;

end uart_example;
