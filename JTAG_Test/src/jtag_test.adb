with Interfaces; use Interfaces;
with STM32F0x0; use STM32F0x0;
with STM32F0x0.RCC; use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;
with Ada.Real_Time; use Ada.Real_Time;


procedure jtag_test is
   TMS_Pin : constant := 4; -- PA4
   TCK_Pin : constant := 5; -- PA5
   TDO_Pin : constant := 6; -- PA6 (Input)
   TDI_Pin : constant := 7; -- PA7

   Word : Unsigned_32;

   --  Setting GPIO
   procedure Initialize_Hardware is
   begin

      --  Enable GPIOA
      RCC_Periph.AHBENR.IOPAEN := 1;

      --  PA4, PA5, PA6, PA7
      GPIOA_Periph.MODER := (As_Array => True,
                             Arr      => (6 => 0, -- PA6 as Input
                                          4 | 5 | 7 => 1,
                                          others => 0));

      --  Initial CS Low(PA4) and TCK, TMS, TDI Low
      GPIOA_Periph.BSRR := (BS => (As_Array => True, Arr => (others => 0)),
                            BR => (As_Array => True, Arr => (4 | 5 | 6 | 7 => 1,
                                                            others => 0)));

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
      delay until Ada.Real_Time.Clock + Nanoseconds (1); -- 1ns delay for TCK low time
      Pin_High (TCK_Pin);
   end Pulse_TCK;

   function Read_TDO return Bit is
   begin
      return GPIOA_Periph.IDR.IDR.Arr (TDO_Pin);
   end Read_TDO;

   procedure TDO_Test is

      type Bit_Array is array (Natural range <>) of Bit;
      IDCODE_Raw : Byte := 16#11#;
      IDCODE : Bit_Array (0 .. 7) with Address => IDCODE_Raw'Address;

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

      --  3. SELECT-DR-SCAN
      Set_TMS_Pin (1);
      Pulse_TCK;

      --  4. CAPTURE-DR
      --  The FPGA hardware ID is dumped into the shift register on this state
      Set_TMS_Pin (0);
      Pulse_TCK;

      --  5. SHIFT-DR (Reading the 32 bits)
      Set_TMS_Pin (0);
      for I in 0 .. 31 loop

            --  On the very last bit, we must pull TMS high to exit the Shift state
            if I = 31 then
               Set_TMS_Pin (1);
            end if;

            --  Falling edge: FPGA places the next bit on the TDO line
            Pin_Low (TCK_Pin);
            for D in 1 .. 5 loop null; end loop; --  Setup delay

            --  Sample TDO and pack it into our 32-bit Word (LSB first)
            if Read_TDO = 1 then
               Word := Word or Shift_Left (Unsigned_32'(1), I);
            end if;

            --  Rising edge: FPGA samples our TMS pin and shifts its internal register
            Pin_High (TCK_Pin);
            for D in 1 .. 5 loop null; end loop; -- Hold delay

      end loop;

      --  6. UPDATE-DR (Moving from Exit1-DR)
      Set_TMS_Pin (1);
      Pulse_TCK;

      --  7. RUN-TEST/IDLE
      Set_TMS_Pin (0);
      Pulse_TCK;

   end TDO_Test;

begin
   Initialize_Hardware;

   TDO_Test;
   --  Ada.Text_IO.Put_Line(Ada.Real_Time.Clock);
   --  JTAG_Sequence (TMS_Sequence, TDI_Sequence, TDI_Clk, 8);
   --  Read_ID_Final;
   --  System_Clock : = HAL.RCC.SystemCoreClock;
   --  Ada.Text_IO.Put_Line("System Clock: " 7Integer'im)
   loop
      null;
   end loop;
end jtag_test;