with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO; use Ada.Text_IO;
with Interfaces; use Interfaces;
with stm32f0x0; use stm32f0x0;
with stm32f0x0.GPIO; use stm32f0x0.GPIO;
with stm32f0x0.RCC; use stm32f0x0.RCC;


procedure FPGA_Programming is




   TMS_Pin : constant := 4; -- PA4
   TCK_Pin : constant := 5; -- PA5
   TDO_Pin : constant := 6; -- PA6 (Input)
   TDI_Pin : constant := 7; -- PA7

   Word : Unsigned_32;

   --  Flags
   RXNE_Flag : constant Unsigned_16 := 16#0001#;
   TXE_Flag : constant Unsigned_16 := 16#0002#;
   BSY_Flag : constant Unsigned_16 := 16#0080#;
   USART_TXE  : constant Unsigned_32 := 16#0000_0080#;
   USART_RXNE : constant Unsigned_32 := 16#0000_0020#; --  Bit 5 in ISR

   --  Setting GPIO
   procedure Initialize_Hardware is
   begin

        --  Enable GPIOA and GPIOB
      RCC_Periph.AHBENR.IOPAEN := 1;
      RCC_Periph.AHBENR.IOPBEN := 1;

      --  Enable SPI1 and USART2
      RCC_Periph.APB2ENR.SPI1EN := 1;
      RCC_Periph.APB1ENR.USART2EN := 1;

      --  PA5, PA6, PA7 (SPI) and PA2, PA3 (UART)
      GPIOA_Periph.MODER := (As_Array => True,
                             Arr      => (4 | 5 | 6 | 7 => 1,
                                          others => 0));

    --  Initial CS Low(PA4) and TCK, TMS, TDI Low
      GPIOA_Periph.BSRR := (BS => (As_Array => True, Arr => (others => 0)),
                            BR => (As_Array => True, Arr => (4 | 5 | 6 | 7 => 1, others => 0)));

 
   end Initialize_Hardware;

   type TMS_Array is array (1 .. 9) of Unsigned_8;
   type TDI_Array is array (1 .. 9) of Unsigned_8;
   type TDI_Clk_Array is array (1 .. 9) of Natural;

   x : Unsigned_32;
   --  Combined JTAG transceive - sends 8 TMS bytes, then on clock 11+ sends TDI alongside TMS
--     procedure JTAG_Sequence (
--        TMS_Bytes : TMS_Array;
--        TDI_Data  : TDI_Array;
--        TDI_Clk : TDI_Clk_Array;
--        TDI_Bits  : Positive := 8) is
      
--        TMS_Bit   : Unsigned_8;
--        TDI_Bit   : Unsigned_8;
--        TDO_Bit   : Unsigned_32;
--        TDO_Buffer    : Unsigned_32 := 0;
--        TDO_Bit_Count : Natural := 0;
--        Clock_Cycle : Natural := 0;
--        TDI_Bit_Index : Natural := 0;
--        TDI_Index : Natural := 1;

--     begin
--        --  Send all 8 TMS bytes (64 bits = clocks 0-63)
--        Word := 0;
--        TDO_Bit_Count := 0;
--        for Byte_Index in TMS_Bytes'Range loop
--           for Bit_Index in 0 .. 7 loop
--              --  while(TIM3_SR and 16#0001#) = 0 loop
--              --     x := x+1;
--              --  end loop;

--              --  TIM3_SR := TIM3_SR and not 16#0001#;

--              Clock_Cycle := Clock_Cycle + 1;
            
--              --  Starting from clock cycle 11, also send TDI
--              if Clock_Cycle > TDI_Clk(TDI_Index) and TDI_Bit_Index < TDI_Bits then
--                 TDI_Bit := Shift_Right (TDI_Data(TDI_Index), TDI_Bit_Index) and 1;
               
--                 if TDI_Bit = 1 then
--                    GPIOA_BSRR := Shift_Left (1, TDI_Pin);
--                 else
--                    GPIOA_BSRR := Shift_Left (1, TDI_Pin + 16);
--                 end if;
               
--                 TDI_Bit_Index := TDI_Bit_Index + 1;
--              end if;
            

--              if(TDI_Bit_Index >= TDI_Bits) then
--                 TDI_Bit_Index := 0;
--                 TDI_Index := TDI_Index + 1;
--              end if;
           
--              --  Clock low (PA5)
--              --  delay until Clock + Nanoseconds(2500);
--              --  GPIOA_BSRR := Shift_Left (1, TCK_Pin + 16);
--  --  WORKING CLOCK VALUES FOR TDO( 24 .. 55)            
            
--              --  Extract TMS bit
--              TMS_Bit := Shift_Right (TMS_Bytes(Byte_Index), Bit_Index) and 1;
            
--              --  Set TMS pin (PA4)
--              if TMS_Bit = 1 then
--                 GPIOA_BSRR := Shift_Left (1, TMS_Pin);
--              else
--                 GPIOA_BSRR := Shift_Left (1, TMS_Pin + 16);
--              end if;
         
--  if Clock_Cycle >= 40 and Clock_Cycle < 72 then

--      TDO_Bit := Shift_Right (GPIOA_IDR, TDO_Pin) and 1;
--     --   TDO_Buffer := TDO_Buffer or Shift_Left(TDO_Bit, TDO_Bit_Count);
--      TDO_Bit_Count := TDO_Bit_Count + 1;
--      Word := Word or Shift_Left(TDO_Bit, TDO_Bit_Count);
    
--      if TDO_Bit_Count = 8 then
--          TDO_Buffer := 0;
--          TDO_Bit_Count := 0;
--      end if;
--  end if;
--              --  Clock high (PA5)
--              --  delay until Clock + Nanoseconds(2500);
--              --  GPIOA_BSRR := Shift_Left (1, TCK_Pin);

--              --  --  Read TDO on rising edge (PA6) - could store if needed
--              --  TDO_Bit := Shift_Right (GPIOA_IDR, TDO_Pin) and 1;

--              --  --  Accumulate TDO into Buffer (LSB First)
--              --  TDO_Buffer := TDO_Buffer or Shift_Left(TDO_Bit, TDO_Bit_Count);
--              --  TDO_Bit_Count := TDO_Bit_Count + 1;
            
--              --  --  If we have collected 8 bits, send byte via UART
--              --  if TDO_Bit_Count = 8 then
--              --     Word := TDO_Buffer;
--              --     Transmit_UART(TDO_Buffer);
--              --     TDO_Buffer := 0;
--              --     TDO_Bit_Count := 0;
--              --  end if;
            
            
--           end loop;
--        end loop;
--     end JTAG_Sequence;

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
      Pin_High (TCK_Pin);
   end Pulse_TCK;

   procedure Set_TDI_Pin (B : Bit) is
   begin
      if B = 1 then
         Pin_High (TDI_Pin);
      else
         Pin_Low (TDI_Pin);
      end if;
   end Set_TDI_Pin;

   --  function Read_TDO return Bit is
   --  begin
   --     return Bit (Shift_Right (GPIOA_IDR, TDO_Pin) and 1);
   --  end Read_TDO;

   procedure TDO_Test is
   

   type Bit_Array is array (Natural range <>) of Bit;
   IDCODE_Raw : Byte := 16#11#;
   IDCODE : Bit_Array (0 .. 7) with Address => IDCODE_Raw'Address;

   TDO_IDCODE : Bit_Array (0 .. 31);

   begin
   --- Reset the TAP
   Set_TMS_Pin (1);
   Pulse_TCK;
   Pulse_TCK;
   Pulse_TCK;
   Pulse_TCK;
   Pulse_TCK;

   --- Go to Idle
   Set_TMS_Pin (0);
   Pulse_TCK;

   -- Load IDCODE
   Set_TMS_Pin (1);
   Pulse_TCK;
   Pulse_TCK;
   Set_TMS_Pin (0);
   Pulse_TCK;
   Set_TMS_Pin (0);
   Pulse_TCK;

   Set_TDI_Pin (1);
   Pulse_TCK;
   Set_TDI_Pin (0);
   Pulse_TCK;
   Set_TDI_Pin (0);
   Pulse_TCK;
   Set_TDI_Pin (0);
   Pulse_TCK;
   Set_TDI_Pin (1);
   Pulse_TCK;
   Set_TDI_Pin (0);
   Pulse_TCK;
   Set_TDI_Pin (0);
   Pulse_TCK;
   Set_TMS_Pin (1);
   Set_TDI_Pin (0);
   Pulse_TCK;

   --  Shift in IDCODE Instruction bits (8 bits)
   --  for I in 0 .. 7 loop
   --     Set_TDI_Pin (IDCODE (I));
   --     if I = 7 then
   --        Set_TMS_Pin (1);
   --     else
   --        Set_TMS_Pin (0);
   --     end if;
   --     Pulse_TCK;
   --  end loop;

   Set_TMS_Pin (1);
   Pulse_TCK;
   Set_TMS_Pin (0);
   Pulse_TCK;
   Pulse_TCK;
   Pulse_TCK;
   Pulse_TCK;
   Pulse_TCK;

   -- Go to Shift-DR
   Set_TMS_Pin (1);
   Pulse_TCK;
   Set_TMS_Pin (0);
   Pulse_TCK;
   Set_TMS_Pin (0);
   Pulse_TCK;

   -- Read 32 bits from TDO
   for I in 0 .. 31 loop
      if I = 31 then
         Set_TMS_Pin (1);
      else
         Set_TMS_Pin (0);
      end if;
      Pulse_TCK;
      --  TDO_IDCODE (I) := Read_TDO;
   end loop;

   Set_TMS_Pin (1);
   Pulse_TCK;
   Set_TMS_Pin (0);
   Pulse_TCK;
   end;

   Incoming_Byte : Unsigned_8;
   TMS_Sequence : TMS_Array;
   TDI_Sequence : TDI_Array;
   TDI_Clk : TDI_Clk_Array;
   TDI_1 : Unsigned_8;

   Trash         : Unsigned_8;
   In_Transfer   : Boolean := False;
   Timeout_Count : Natural := 0;

   --  Main loop
begin
   Initialize_Hardware;
   
   --  TEMP: SEQUENCE WILL HAVE 2 of the data register 0s

   --  WORKING SEQUENCE (OUTPUT: 0x000001FE)

   TMS_Sequence(1) := 16#00#;
   TMS_Sequence(2) := 16#DF#;
   TMS_Sequence(3) := 16#00#;
   TMS_Sequence(4) := 16#02#;
   TMS_Sequence(5) :=16#01#;
   TMS_Sequence(6) := 16#00#;
   TMS_Sequence(7) := 16#00#;
   TMS_Sequence(8) := 16#00#;
   TMS_Sequence(9) := 16#06#;
   


   --  TMS_Sequence(0) := 16#E0#;
   --  TMS_Sequence(1) := 16#1B#;
   --  TMS_Sequence(2) := 16#60#;
   --  TMS_Sequence(3) := 16#08#;
   --  TMS_Sequence(4) := 16#00#;
   --  TMS_Sequence(5) :=16#00#;
   --  TMS_Sequence(6) := 16#00#;
   --  TMS_Sequence(7) := 16#30#;
   --  TMS_Sequence(8) := 16#0C#;
   --  TMS_Sequence(9) := 16#10#;
   --  TMS_Sequence(10) := 16#06#;
   --  TMS_Sequence(11) := 16#18#;
   --  TMS_Sequence(12) := 16#06#;
   --  TMS_Sequence(13) := 16#18#;
   --  TMS_Sequence(14) := 16#C0#;
   --  TMS_Sequence(15) :=16#00#;
   --  TMS_Sequence(16) := 16#C3#;
   --  TMS_Sequence(17) := 16#00#;
   --  TMS_Sequence(18) := 16#C3#;
   --  TMS_Sequence(19) := 16#00#;
   --  TMS_Sequence(20) := 16#C3#;
   --  TMS_Sequence(21) := 16#00#;
   --  TMS_Sequence(22) := 16#C3#;
   --  TMS_Sequence(23) := 16#00#;
   --  TMS_Sequence(24) := 16#43#;
   --  TMS_Sequence(25) := 16#00#;

   --  TDI_Sequence(1) := 16#11#;
   --  TDI_Sequence(2) := 16#15#;
   --  TDI_Sequence(3) := 16#05#;
   --  TDI_Sequence(4) := 16#02#;
   --  TDI_Sequence(5) := 16#09#;
   --  TDI_Sequence(6) := 16#02#;
   --  TDI_Sequence(7) := 16#15#;
   --  TDI_Sequence(8) := 16#12#;
   --  TDI_Sequence(9) := 16#17#;

   TDI_Sequence(1) := 16#41#;
   TDI_Sequence(2) := 16#00#;
   TDI_Sequence(3) := 16#00#;
   TDI_Sequence(4) := 16#00#;
   TDI_Sequence(5) := 16#00#;
   TDI_Sequence(6) := 16#00#;
   TDI_Sequence(7) := 16#00#;
   TDI_Sequence(8) := 16#00#;
   TDI_Sequence(9) := 16#00#;

   TDI_Clk(1) := 18;
   TDI_Clk(2) := 70;
   TDI_Clk(3) := 85;
   TDI_Clk(4) := 101;
   TDI_Clk(5) := 122;
   TDI_Clk(6) := 138;
   TDI_Clk(7) := 154;
   TDI_Clk(8) := 170;
   TDI_Clk(9) := 186;




   TDO_Test;
   --  Ada.Text_IO.Put_Line(Ada.Real_Time.Clock);
   --  JTAG_Sequence (TMS_Sequence, TDI_Sequence, TDI_Clk, 8);
   --  Read_ID_Final;
   --  System_Clock : = HAL.RCC.SystemCoreClock;
   --  Ada.Text_IO.Put_Line("System Clock: " 7Integer'im)
   loop
      null;
   end loop;
end FPGA_Programming;