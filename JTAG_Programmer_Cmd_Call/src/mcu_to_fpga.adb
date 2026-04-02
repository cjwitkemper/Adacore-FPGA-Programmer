pragma Style_Checks (Off);
with STM32F0x0;               use STM32F0x0;
with STM32F0x0.RCC;           use STM32F0x0.RCC;
with STM32F0x0.GPIO;          use STM32F0x0.GPIO;
with STM32F0x0.SPI;           use STM32F0x0.SPI;
with STM32F0x0.USART;         use STM32F0x0.USART;
with STM32F0x0.DMA;           use STM32F0x0.DMA;
with System.Storage_Elements; use System.Storage_Elements;
------------------------------------------------------------------------------
--  File:        mcu_to_fpga.adb
--  Description: Package body for MCU-to-FPGA communication over JTAG.
--               Implements TAP (Test Access Port) state machine control,
--               JTAG command transmission, configuration bitstream loading
--               via SPI/DMA, and firmware forwarding between USART interfaces.
--
--  Components:
--               Send_Command             -- Shifts an 8-bit IR command into
--                                           the FPGA via JTAG Shift-IR state
--               Read_TDO                 -- Clocks through the DR chain to
--                                           capture TDO output
--               Init_Configuration       -- Executes the FPGA configuration
--                                           initialization sequence
--               Read_IDCODE              -- Reads the JTAG IDCODE register
--               Reset_TAP                -- Forces TAP controller to
--                                           Test-Logic-Reset state
--               Send_Configuration_Bitstream -- Streams bitstream data from
--                                           DMA circular buffer over JTAG
--               Send_Firmware            -- Bridges USART2 (host) to USART1
--                                           (Tang Nano) for firmware upload
--               M2F (Task)               -- State-machine task driving the
--                                           above procedures
--
--  Target:      STM32F0x0
--  Language:    Ada 2012
------------------------------------------------------------------------------
package body mcu_to_fpga is

   Write_Idx        : Natural;
   Read_Idx         : Natural := 0;
   Last_Write_Idx   : Natural := Buffer_Size;
   Stable_Count     : Natural := 0;
   Stable_Threshold : constant :=
     10_000; -- tune this to ~several ms of silence
   Has_Data         : Boolean := False;
   cmd : Bit_Array (0 .. 7);

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
         delay 0.0001;
      end loop;
      Pulse_TCK; -- UPDATE-IR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command

   end Send_Command;

   --  CHANGE TO FUNCTION LATER: SHOULD RETURN THE VALUE OF TDO
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

      --  cmd := (0, 0, 1, 1, 1, 1, 0, 0); -- Example command (IR=0x3C)
      --  Send_Command (cmd);
      --  delay 0.015;

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

   procedure Read_IDCODE is
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-DR
      for I in 0 .. 31 loop
         if (I = 31) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit
         end if;
         Pulse_TCK;
      end loop;
      Pin_High (TMS_PIN);
      Pulse_TCK; -- UPDATE-DR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
   end Read_IDCODE;

   procedure Reset_TAP is
   begin
      Pin_High (TMS_PIN);
      for I in 1 .. 6 loop
         Pulse_TCK;
      end loop;
   end Reset_TAP;

   procedure Send_Configuration_Bitstream is
      cmd : Bit_Array (0 .. 7);
   begin
      Pin_High (tms_pin);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (tms_pin);
      Pulse_TCK; -- CAPTURE-DR
      Pulse_TCK; -- Shift-DR
      SPI_Enable;
      loop
         Write_Idx := Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT);

         --  Check if the write pointer has moved since last iteration
         if Write_Idx /= Last_Write_Idx then
            --  New data has arrived: reset the stability counter
            Stable_Count := 0;
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
                  Transceive_Byte(DMA_Buffer (I));
               end loop;
               Read_Idx := Write_Idx - 1;
            else
               if Write_Idx = 0 then
                  for I in Read_Idx .. Buffer_Size - 2 loop
                     Transceive_Byte (DMA_Buffer (I));
                  end loop;
                  Read_Idx := Buffer_Size - 1;
               else
                  for I in Read_Idx .. Buffer_Size - 1 loop
                     Transceive_Byte (DMA_Buffer (I));
                  end loop;
                  for I in 0 .. Write_Idx - 2 loop
                     Transceive_Byte (DMA_Buffer (I));
                  end loop;
                  Read_Idx := Write_Idx - 1;
               end if;
            end if;
         end if;

         --  Timeout
         if Has_Data and then Stable_Count >= Stable_Threshold then
            SPI_Disable;
            Transceive_Last_Byte (DMA_Buffer (Read_Idx));
            Read_Idx := (Read_Idx + 1) mod Buffer_Size;
            Pulse_TCK; -- UPDATE-DR
            Pin_Low (TMS_Pin);
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
      U2_Read_Idx      : Natural;
      U1_Read_Idx      : Natural;
      U2_Write         : Natural;
      U1_Write         : Natural;
      Last_U2_Write    : Natural;
      Stable_Count     : Natural := 0;
      Stable_Threshold : constant := 10_000;
      Has_Data         : Boolean := False;
   begin
      --  Wait for any in-flight USART2 TX to finish before reconfiguring
      while USART2_Periph.ISR.TC = 0 loop
         null;
      end loop;

      --  Reconfigure USART2 to 19200 baud to match USART1 / Tang Nano side
      USART2_Periph.CR1 := (UE => 0, others => <>);
      USART2_Periph.BRR :=
        (DIV_Mantissa => 16#9C#, DIV_Fraction => 16#04#, others => <>);
      USART2_Periph.CR3.DMAR := 1;
      USART2_Periph.CR1 := (UE => 1, TE => 1, RE => 1, others => <>);

      --  Reconfigure DMA1 Channel 5 (USART2 RX) with updated baud — disable,
      --  reload CNDTR, re-enable so the channel is in a clean state.
      DMA1_Periph.CCR5.EN := 0;
      DMA1_Periph.CNDTR5.NDT := UInt16 (Buffer_Size);
      DMA1_Periph.CCR5.EN := 1;

      U2_Read_Idx := Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT);
      U1_Read_Idx := Buffer_Size - Natural (DMA1_Periph.CNDTR3.NDT);
      Last_U2_Write := U2_Read_Idx;

      delay 0.1;
      USART1_Periph.TDR.TDR := RDR_RDR_Field (16#75#);
      delay 0.1;
      USART1_Periph.TDR.TDR := RDR_RDR_Field (16#75#);

      while U2_Read_Idx = Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT) loop
         null;
      end loop;

      loop
         --  Snapshot write pointer ONCE at the top before any draining
         U2_Write := Buffer_Size - Natural (DMA1_Periph.CNDTR5.NDT);

         if U2_Write /= Last_U2_Write then
            Stable_Count := 0;
            Last_U2_Write := U2_Write;
            Has_Data := True;
         else
            if Has_Data then
               Stable_Count := Stable_Count + 1;
            end if;
         end if;

         --  Drain only up to the snapshot — do NOT re-read CNDTR5 here
         while U2_Read_Idx /= U2_Write loop
            while USART1_Periph.ISR.TXE = 0 loop
               null;
            end loop;
            USART1_Periph.TDR.TDR := RDR_RDR_Field (DMA_Buffer (U2_Read_Idx));
            U2_Read_Idx := (U2_Read_Idx + 1) mod Buffer_Size;
         end loop;

         --  Tang Nano --> Laptop (unchanged)
         U1_Write := Buffer_Size - Natural (DMA1_Periph.CNDTR3.NDT);
         while U1_Read_Idx /= U1_Write loop
            while USART2_Periph.ISR.TXE = 0 loop
               null;
            end loop;
            USART2_Periph.TDR.TDR := RDR_RDR_Field (DMA1_Buffer (U1_Read_Idx));
            U1_Read_Idx := (U1_Read_Idx + 1) mod Buffer_Size;
         end loop;

         exit when Has_Data and then Stable_Count >= Stable_Threshold;
      end loop;

      while USART1_Periph.ISR.TC = 0 loop
         null;
      end loop;

      --  Clear TC flag by writing to ICR before sending next byte
      USART1_Periph.ICR.TCCF := 1;

      while USART1_Periph.ISR.TXE = 0 loop
         null;
      end loop;
      USART1_Periph.TDR.TDR := RDR_RDR_Field (16#65#);

      --  Wait for this byte to finish too
      while USART1_Periph.ISR.TC = 0 loop
         null;
      end loop;

      loop
         null;
      end loop;
   end Send_Firmware;


   task body M2F is
   begin
      loop
         case Current_State.Get is
            when IDLE =>
               null;
            when INIT_CONFIG =>
               Reset_TAP;
               Init_Configuration;
            when PROG_BITSTREAM =>
               Send_Configuration_Bitstream;
            when PROG_FIRMWARE =>
               Send_Firmware;
            when ESCAPE =>
               exit;
         end case;
      end loop;
   end M2F;

end mcu_to_fpga;