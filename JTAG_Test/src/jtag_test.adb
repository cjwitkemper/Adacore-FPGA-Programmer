with Interfaces;     use Interfaces;
with STM32F0x0;      use STM32F0x0;
with STM32F0x0.RCC;  use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;
with STM32F0x0.USART; use STM32F0x0.USART;
with Ada.Real_Time;  use Ada.Real_Time;

procedure jtag_test is
   TMS_Pin : constant := 4; -- PA4
   TCK_Pin : constant := 5; -- PA5
   TDO_Pin : constant := 6; -- PA6 (Input)
   TDI_Pin : constant := 7; -- PA7
   type Bit_Array is array (Natural range <>) of Bit;

   Word : Unsigned_32;

   --  Setting GPIO
   procedure Initialize_Hardware is
   begin

      --  Enable GPIOA
      RCC_Periph.AHBENR.IOPAEN := 1;

      --  Enable USART2
      RCC_Periph.APB1ENR.USART2EN := 1;

      --  PA4, PA5, PA6, PA7
      GPIOA_Periph.MODER.Arr (4) := 1;
      GPIOA_Periph.MODER.Arr (5) := 1;
      GPIOA_Periph.MODER.Arr (6) := 0;
      GPIOA_Periph.MODER.Arr (7) := 1;

      --  Initial CS Low(PA4) and TCK, TMS, TDI Low
      GPIOA_Periph.BSRR.BR.Arr (4) := 1;
      GPIOA_Periph.BSRR.BR.Arr (5) := 1;
      GPIOA_Periph.BSRR.BR.Arr (6) := 1;
      GPIOA_Periph.BSRR.BR.Arr (7) := 1;

      --  USART2 Configuration (115200 Baud @ 48MHz)
      USART2_Periph.BRR := (DIV_Mantissa => 16#416#,
                            DIV_Fraction => 0,
                            others       => <>);

      --  Enable UART, Transmit, and Receive
      USART2_Periph.CR1 := (UE     => 1,
                            TE     => 1,
                            RE     => 1,
                            OVER8  => 0,
                            others => <>);

   end Initialize_Hardware;

   -- Helper procedures to drive GPIO pins (PAx) using BSRR
   procedure Pin_High (Pin : Natural) is
   begin
      if Pin <= 15 then
         GPIOA_Periph.BSRR.BS.Arr (Pin) := 1;
      end if;
   end Pin_High;

   procedure Pin_Low (Pin : Natural) is
   begin
      if Pin <= 15 then
         GPIOA_Periph.BSRR.BR.Arr (Pin) := 1;
      end if;
   end Pin_Low;

   procedure Set_TMS_Pin (B : Bit) is
   begin
      if B = 1 then
         Pin_High (TMS_Pin);
      else
         Pin_Low (TMS_Pin);
      end if;
   end Set_TMS_Pin;

   procedure Pulse_TCK is
   begin
      Pin_Low (TCK_Pin);
      delay until
        Ada.Real_Time.Clock + Nanoseconds (1); -- 1ns delay for TCK low time
      Pin_High (TCK_Pin);
   end Pulse_TCK;

   function Get_TDO return Bit is
   begin
      return GPIOA_Periph.IDR.IDR.Arr (TDO_Pin);
   end Get_TDO;

   procedure Read_TDO is
   begin
      Set_TMS_Pin (1);
      Pulse_TCK; -- SELECT-DR-SCAN
      Set_TMS_Pin (0);
      Pulse_TCK; -- CAPTURE-DR
      for I in 0 .. 32 loop
         if (I = 32) then
            Set_TMS_Pin (1); -- Pull TMS high on the last bit to exit Shift-DR

         end if;
         Pulse_TCK;
      end loop;
      Set_TMS_Pin (1);
      Pulse_TCK; -- UPDATE-DR
      Set_TMS_Pin (0);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
   end Read_TDO;

   procedure Send_Command (c : Bit_Array) is
   begin
      Set_TMS_Pin (1);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pulse_TCK; -- SELECT-IR-SCAN
      Set_TMS_Pin (0);
      Pulse_TCK; -- CAPTURE-IR
      Pulse_TCK;
      for I in 0 .. 7 loop
         if c (I) = 1 then
            Pin_High (TDI_Pin);
         else
            Pin_Low (TDI_Pin);
         end if;
         if (I = 7) then
            Set_TMS_Pin (1); -- Pull TMS high on the last bit to exit Shift-IR

         end if;
         Pulse_TCK;
         delay 0.0001;
      end loop;
      Pulse_TCK; -- UPDATE-IR
      Set_TMS_Pin (0);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command

   end Send_Command;

   procedure Transceive_Byte_JTAG (Data_Out : Byte; Last_Byte : Boolean) is
      TDO_Byte : Byte := 0;
   begin
      for Bit in 0 .. 7 loop
         if Last_Byte and then (Bit = 7) then
            Set_TMS_Pin (1); -- Pull TMS high on the last bit to exit Shift-DR
         end if;

         if (Data_Out and Shift_Left (1, Bit)) /= 0 then
            Pin_High (TDI_Pin);
         else
            Pin_Low (TDI_Pin);
         end if;

         Pulse_TCK;
      end loop;
   end Transceive_Byte_JTAG;

   function Data_Available_UART return Boolean is
   begin
      return USART2_Periph.ISR.RXNE /= 0;
   end Data_Available_UART;

   function Receive_UART return Byte is
   begin
      return Byte (USART2_Periph.RDR.RDR);
   end Receive_UART;

   procedure TDO_Test is

      cmd : Bit_Array (0 .. 7);

      TDO_IDCODE : Bit_Array (0 .. 31);

   begin
      --  Reset the TAP
      Set_TMS_Pin (1);
      for I in 1 .. 6 loop
         Pulse_TCK;
      end loop;

      --  Go to Idle
      Set_TMS_Pin (0);
      Pulse_TCK;

      --  2. RUN-TEST/IDLE
      Set_TMS_Pin (0);
      Pulse_TCK;

      Read_TDO; -- Read IDCODE (32 bits) from the FPGA's JTAG interface

      delay 0.001; -- Delay to get to CONFIGURATION state

      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command to read Status Register (IR=0x41)
      Send_Command (cmd); -- Send a command to the FPGA (0x41 in this case)

      Set_TMS_Pin (0);
      for I in 1 .. 10 loop
         Pulse_TCK; -- RUN-TEST/IDLE
      end loop;
      Read_TDO; -- Read the TDO output after sending the command

      cmd := (1, 0, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x15)
      Send_Command (cmd); -- Send the command

      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);

      --  Small Delay
      Set_TMS_Pin (0);
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

      Set_TMS_Pin (1);
      Pulse_TCK; -- SELECT-DR-SCAN
      Set_TMS_Pin (0);
      Pulse_TCK; -- CAPTURE-DR
      Pulse_TCK; -- Shift-DR
   end TDO_Test;

   First_Byte : Byte;
   Second_Byte : Byte;
   Byte_Count : Natural := 0;
   In_Transfer : Boolean := False;
   Timeout_Count : Natural := 0;
begin
   Initialize_Hardware;

   TDO_Test;

   loop
      if Data_Available_UART then
         First_Byte := Second_Byte;
         Second_Byte := Receive_UART;
         Byte_Count := Byte_Count + 1;
         if not In_Transfer then
            In_Transfer := True;
         end if;

         if Byte_Count > 1 then
            Transceive_Byte_JTAG (First_Byte, False);
         end if;
         Timeout_Count := 0;
      else
         if In_Transfer then
            Timeout_Count := Timeout_Count + 1;
            if Timeout_Count > 50_000 then
               In_Transfer := False;
               Byte_Count := 0;
               Transceive_Byte_JTAG (Second_Byte, True);
            end if;
         end if;
      end if;

   end loop;
end jtag_test;
