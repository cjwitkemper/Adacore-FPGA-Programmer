with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO; use Ada.Text_IO;
with Interfaces; use Interfaces;


procedure FPGA_Programming is

   --  Register Definitions
   --  RCC
   RCC_AHBENR  : Unsigned_32 with Address => To_Address (16#4002_1014#);
   RCC_APB2ENR : Unsigned_32 with Address => To_Address (16#4002_1018#);
   RCC_APB1ENR : Unsigned_32 with Address => To_Address (16#4002_101C#);
   --  GPIOA
   GPIOA_MODER : Unsigned_32 with Address => To_Address (16#4800_0000#);
   GPIOA_BSRR  : Unsigned_32 with Address => To_Address (16#4800_0018#);
   GPIOA_AFRL  : Unsigned_32 with Address => To_Address (16#4800_0020#);
   GPIOA_IDR   : Unsigned_32 with Address => To_Address (16#4800_0010#);
   GPIOA_PUPDR : Unsigned_32 with Address => To_Address(16#4800_000C#);
   --  GPIOB
   GPIOB_MODER   : Unsigned_32 with Address => To_Address(16#4800_0400#);
   GPIOB_AFRL    : Unsigned_32 with Address => To_Address(16#4800_0420#);
   --  SPI1
   SPI1_CR1    : Unsigned_16 with Address => To_Address (16#4001_3000#);
   SPI1_CR2    : Unsigned_16 with Address => To_Address (16#4001_3004#);
   SPI1_SR     : Unsigned_16 with Address => To_Address (16#4001_3008#);
   SPI1_DR     : Unsigned_8  with Address => To_Address (16#4001_300C#);
   --  USART2
   USART2_CR1  : Unsigned_32 with Address => To_Address (16#4000_4400#);
   USART2_BRR  : Unsigned_32 with Address => To_Address (16#4000_440C#);
   USART2_ISR  : Unsigned_32 with Address => To_Address (16#4000_441C#);
   USART2_RDR  : Unsigned_8  with Address => To_Address (16#4000_4424#);
   USART2_TDR  : Unsigned_32  with Address => To_Address (16#4000_4428#);

   --  Timer 3 Registers
   TIM3_CR1   : Unsigned_32 with Address => To_Address(16#4000_0400#);
   TIM3_CCMR2 : Unsigned_32 with Address => To_Address(16#4000_041C#);
   TIM3_CCER  : Unsigned_32 with Address => To_Address(16#4000_0420#);
   TIM3_PSC   : Unsigned_32 with Address => To_Address(16#4000_0428#);
   TIM3_ARR   : Unsigned_32 with Address => To_Address(16#4000_042C#);
   TIM3_CCR3  : Unsigned_32 with Address => To_Address(16#4000_043C#);
   TIM3_EGR   : Unsigned_32 with Address => To_Address(16#4000_0414#);
   TIM3_DIER    : Unsigned_32 with Address => To_Address(16#4000_040C#);
   TIM3_SR      : Unsigned_32 with Address => To_Address(16#4000_0410#);

   -- NVIC registers (specific to Cortex-M0)
NVIC_ISER    : Unsigned_32 with Address => To_Address(16#E000_E100#);   

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

      --  Clocks for GPIOA and SPI1 and USART2
      RCC_AHBENR  := RCC_AHBENR or 16#0006_0000#; --  GPIOA
      --  RCC_APB2ENR := RCC_APB2ENR or 16#0000_1000#; --  SPI1 (bit 12)
      RCC_APB1ENR  := RCC_APB1ENR or 16#0002_0002#; --  USART2 (bit 17)

      --  Setting pins SPI(PA5,6,7) UART(PA2,PA3)
      GPIOA_MODER := (GPIOA_MODER and 16#FFFF_000F#) or 16#0000_45A0#;

      --  Select Alternate function for PA5, PA6, PA7
      GPIOA_AFRL := (GPIOA_AFRL and 16#FFFF_00FF#) or 16#0000_1100#;

      --  PA6 to PUll-down
      GPIOA_PUPDR := (GPIOA_PUPDR and 16#FFFF_CFFF#) or 16#0000_2000#;

      --  CR1: Master, Baud Rate
      SPI1_CR1    := 16#033C# or 16#0080#; --  Master, 256 LSB First
      SPI1_CR2    := 16#0700# or 16#1000#; --  8-bit mode
      SPI1_CR1    := SPI1_CR1 or 16#0040#; --  Enable

      --  UART Config (115200 Baud @ 48MHz Clock)
      USART2_BRR := 16#01A1#; --  48,000,000 / 115,200 = 417 (0x1A1)
      USART2_CR1 := 16#0000_000D#;

      GPIOB_MODER := (GPIOB_MODER and not 16#0000_0003#) or 16#0000_0002#;
      -- AFRL: Set AF1 (0001) for Pin 0
      GPIOB_AFRL  := (GPIOB_AFRL and not 16#0000_000F#) or 16#0000_0001#;

      -- 3. Configure Timer 3
      TIM3_PSC := 0;      -- Prescaler
      TIM3_ARR := 999;    -- Auto-reload (1kHz frequency)
      TIM3_CCR3 := 500;   -- 50% Duty Cycle initial value

      -- 4. Configure Channel 3 for PWM Mode 1
      -- CCMR2: OC3M bits (bits 4-6) to 110 (PWM mode 1), OC3PE (bit 3) to 1 (Preload enable)
      TIM3_CCMR2 := (TIM3_CCMR2 and not 16#0000_0070#) or 16#0000_0068#;

      -- 5. Enable Output for Channel 3
      TIM3_CCER := TIM3_CCER or 16#0000_0100#; -- CC3E bit

      -- 6. Initialize registers and start timer
      TIM3_EGR := 16#0001#; -- Update Generation (UG bit)
      TIM3_CR1 := TIM3_CR1 or 16#0001#; -- CEN (Counter Enable)

      --  Set CS High initially
      GPIOA_BSRR := 16#0000_0010#;
   end Initialize_Hardware;

   --  Checks sends and receives
   function Transceive (Data_Out : Unsigned_8) return Unsigned_8 is
   begin
      while (SPI1_SR and TXE_Flag) = 0 loop null; end loop;
      SPI1_DR := Data_Out;
      while (SPI1_SR and RXNE_Flag) = 0 loop null; end loop;
      return SPI1_DR;
   end Transceive;

   --  UART Transmit Procedure
   procedure Transmit_UART (Data : Unsigned_32) is
   begin
      --  Wait for Transmit Data Register Empty (TXE)
      while (USART2_ISR and USART_TXE) = 0 loop 
         null; 
      end loop;
      USART2_TDR := Data;
   end Transmit_UART;

   procedure Transmit_Hex_32 (Value : Unsigned_32) is
   -- Lookup table for hex characters
   Hex_Chars : constant array (0 .. 15) of Character := 
     ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
   
   Nibble : Unsigned_32;
   Shift  : Integer;
   begin
      --  Iterate through the 32-bit value 4 bits at a time, starting from the top
      for I in reverse 0 .. 7 loop
         Shift := I * 4;
         --  Isolate the 4-bit nibble and shift it to the LSB position
         Nibble := Shift_Right(Value, Shift) and 16#F#;
      
         --  Wait for TXE (Transmit Data Register Empty)
         while (USART2_ISR and USART_TXE) = 0 loop 
            null; 
         end loop;
      
         --  Map nibble to ASCII character and transmit
         USART2_TDR := Unsigned_32(Character'Pos(Hex_Chars(Integer(Nibble))));
      end loop;
   end Transmit_Hex_32;

   type TMS_Array is array (0 .. 9) of Unsigned_8;
   x : Unsigned_32;
   --  Combined JTAG transceive - sends 8 TMS bytes, then on clock 11+ sends TDI alongside TMS
   procedure JTAG_Sequence (
      TMS_Bytes : TMS_Array;
      TDI_Data  : Unsigned_8;
      TDI_Bits  : Positive := 8) is
      
      TMS_Bit   : Unsigned_8;
      TDI_Bit   : Unsigned_8;
      TDO_Bit   : Unsigned_32;
      TDO_Buffer    : Unsigned_32 := 0;
      TDO_Bit_Count : Natural := 0;
      Clock_Cycle : Natural := 0;
      TDI_Bit_Index : Natural := 0;
   begin
      --  Send all 8 TMS bytes (64 bits = clocks 0-63)
      Word := 0;
      TDO_Bit_Count := 0;
      for Byte_Index in TMS_Bytes'Range loop
         for Bit_Index in 0 .. 7 loop
            while(TIM3_SR and 16#0001#) = 0 loop
               x := x+1;
            end loop;

            TIM3_SR := TIM3_SR and not 16#0001#;

            Clock_Cycle := Clock_Cycle + 1;
            
            --  Starting from clock cycle 11, also send TDI
            if Clock_Cycle > 18 and TDI_Bit_Index < TDI_Bits then
               TDI_Bit := Shift_Right (TDI_Data, TDI_Bit_Index) and 1;
               
               if TDI_Bit = 1 then
                  GPIOA_BSRR := Shift_Left (1, TDI_Pin);
               else
                  GPIOA_BSRR := Shift_Left (1, TDI_Pin + 16);
               end if;
               
               TDI_Bit_Index := TDI_Bit_Index + 1;
            end if;
            
           
            --  Clock low (PA5)
            --  delay until Clock + Nanoseconds(2500);
            --  GPIOA_BSRR := Shift_Left (1, TCK_Pin + 16);
--  WORKING CLOCK VALUES FOR TDO( 24 .. 55)            
            
            --  Extract TMS bit
            TMS_Bit := Shift_Right (TMS_Bytes(Byte_Index), Bit_Index) and 1;
            
            --  Set TMS pin (PA4)
            if TMS_Bit = 1 then
               GPIOA_BSRR := Shift_Left (1, TMS_Pin);
            else
               GPIOA_BSRR := Shift_Left (1, TMS_Pin + 16);
            end if;
         
if Clock_Cycle >= 40 and Clock_Cycle < 72 then

    TDO_Bit := Shift_Right (GPIOA_IDR, TDO_Pin) and 1;
   --   TDO_Buffer := TDO_Buffer or Shift_Left(TDO_Bit, TDO_Bit_Count);
    TDO_Bit_Count := TDO_Bit_Count + 1;
    Word := Word or Shift_Left(TDO_Bit, TDO_Bit_Count);
    
    if TDO_Bit_Count = 8 then
        TDO_Buffer := 0;
        TDO_Bit_Count := 0;
    end if;
end if;
            --  Clock high (PA5)
            --  delay until Clock + Nanoseconds(2500);
            --  GPIOA_BSRR := Shift_Left (1, TCK_Pin);

            --  --  Read TDO on rising edge (PA6) - could store if needed
            --  TDO_Bit := Shift_Right (GPIOA_IDR, TDO_Pin) and 1;

            --  --  Accumulate TDO into Buffer (LSB First)
            --  TDO_Buffer := TDO_Buffer or Shift_Left(TDO_Bit, TDO_Bit_Count);
            --  TDO_Bit_Count := TDO_Bit_Count + 1;
            
            --  --  If we have collected 8 bits, send byte via UART
            --  if TDO_Bit_Count = 8 then
            --     Word := TDO_Buffer;
            --     Transmit_UART(TDO_Buffer);
            --     TDO_Buffer := 0;
            --     TDO_Bit_Count := 0;
            --  end if;
            
            
         end loop;
      end loop;
   end JTAG_Sequence;

--  procedure Read_IDCODE_Manual is
--     procedure Clock_TMS(TMS : Unsigned_32; TDI : Unsigned_32 := 0) is
--     begin
--        -- Set TMS
--        if TMS = 1 then GPIOA_BSRR := Shift_Left(1, TMS_Pin);
--        else GPIOA_BSRR := Shift_Left(1, TMS_Pin + 16); end if;
--        -- Set TDI
--        if TDI = 1 then GPIOA_BSRR := Shift_Left(1, TDI_Pin);
--        else GPIOA_BSRR := Shift_Left(1, TDI_Pin + 16); end if;
      
--        for I in 1..500 loop null; end loop;
--        GPIOA_BSRR := Shift_Left(1, TCK_Pin + 16); -- Clock Low
--        for I in 1..500 loop null; end loop;
--        GPIOA_BSRR := Shift_Left(1, TCK_Pin);      -- Clock High
--     end Clock_TMS;

--  begin
--     Word := 0;
--     -- 1. Reset
--     for I in 1..5 loop Clock_TMS(1); end loop;
--     -- 2. Idle
--     Clock_TMS(0);
--     -- 3. Move to Shift-IR (TMS: 1, 1, 0, 0)
--     Clock_TMS(1); Clock_TMS(1); Clock_TMS(0); Clock_TMS(0);
--     -- 4. Shift Instruction 0x11 (8 bits: 1, 0, 0, 0, 1, 0, 0, 0)
--     -- Last bit must have TMS=1 to move to Exit1-IR
--     Clock_TMS(0, 1); Clock_TMS(0, 0); Clock_TMS(0, 0); Clock_TMS(0, 0);
--     Clock_TMS(0, 1); Clock_TMS(0, 0); Clock_TMS(0, 0); Clock_TMS(1, 0);
--     -- 5. Move to Shift-DR (Update-IR -> SelDR -> CapDR -> ShiftDR) (TMS: 1, 1, 0, 0)
--     Clock_TMS(1); Clock_TMS(1); Clock_TMS(0); Clock_TMS(0);
--     -- 6. Read 32 bits
--  for I in 0 .. 31 loop
--     -- Force TDI Low (PA7)
--     GPIOA_BSRR := Shift_Left(1, TDI_Pin + 16); 
   
--     -- Clock Low
--     GPIOA_BSRR := Shift_Left(1, TCK_Pin + 16);
--     for J in 1 .. 1000 loop null; end loop;

--     -- Read TDO
--     if (Shift_Right(GPIOA_IDR, TDO_Pin) and 1) = 1 then
--        Transmit_UART(Character'Pos('#'));
--     else
--        Transmit_UART(Character'Pos('.'));
--     end if;

--     -- Clock High
--     GPIOA_BSRR := Shift_Left(1, TCK_Pin);
--     for J in 1 .. 1000 loop null; end loop;
--  end loop;
--  end Read_IDCODE_Manual;

procedure Read_ID_Final is
   -- Use a very slow toggle to be sure
   procedure TCK_Step(TMS : Unsigned_32; TDI : Unsigned_32) is
   begin
      -- Set TMS/TDI
      if TMS = 1 then GPIOA_BSRR := Shift_Left(1, TMS_Pin);
      else GPIOA_BSRR := Shift_Left(1, TMS_Pin + 16); end if;
      
      if TDI = 1 then GPIOA_BSRR := Shift_Left(1, TDI_Pin);
      else GPIOA_BSRR := Shift_Left(1, TDI_Pin + 16); end if;

      for J in 1 .. 1000 loop null; end loop;
      GPIOA_BSRR := Shift_Left(1, TCK_Pin + 16); -- TCK Low
      for J in 1 .. 1000 loop null; end loop;
      GPIOA_BSRR := Shift_Left(1, TCK_Pin);      -- TCK High
   end TCK_Step;

begin
   Word := 0;

   -- 1. Reset TAP: 8 clocks with TMS=1 ensures we are in Test-Logic-Reset
   for I in 1 .. 8 loop TCK_Step(1, 0); end loop;

   -- 2. Move to Shift-IR: TMS Sequence 0 -> 1 -> 1 -> 0 -> 0
   TCK_Step(0, 0); -- Run-Test/Idle
   TCK_Step(1, 0); -- Select-DR-Scan
   TCK_Step(1, 0); -- Select-IR-Scan
   TCK_Step(0, 0); -- Capture-IR
   TCK_Step(0, 0); -- Shift-IR

   -- 3. Shift in IDCODE Command: 0x11 (8 bits, LSB first: 1,0,0,0,1,0,0,0)
   -- Shift first 7 bits
   TCK_Step(0, 1); TCK_Step(0, 0); TCK_Step(0, 0); TCK_Step(0, 0);
   TCK_Step(0, 1); TCK_Step(0, 0); TCK_Step(0, 0);
   -- 8th bit: TMS=1 to move to Exit1-IR
   TCK_Step(1, 0); 

   -- 4. Move to Shift-DR: TMS Sequence 1 -> 1 -> 0 -> 0
   TCK_Step(1, 0); -- Update-IR
   TCK_Step(1, 0); -- Select-DR-Scan
   TCK_Step(0, 0); -- Capture-DR
   TCK_Step(0, 0); -- Shift-DR

   -- 5. Read 32 bits
   for I in 0 .. 31 loop
      -- Pull TCK Low
      GPIOA_BSRR := Shift_Left(1, TCK_Pin + 16);
      for J in 1 .. 1000 loop null; end loop;

      -- Sample TDO
      if (Shift_Right(GPIOA_IDR, TDO_Pin) and 1) = 1 then
         Word := Word or Shift_Left(1, I);
      end if;

      -- Pull TCK High
      -- On bit 31, set TMS=1 to exit Shift-DR
      if I = 31 then
         GPIOA_BSRR := Shift_Left(1, TMS_Pin);
      end if;
      
      GPIOA_BSRR := Shift_Left(1, TCK_Pin);
      for J in 1 .. 1000 loop null; end loop;
   end loop;

   -- 6. Clean up to Idle
   TCK_Step(1, 0); -- Update-DR
   TCK_Step(0, 0); -- Run-Test/Idle
end Read_ID_Final;


   function Data_Available_UART return Boolean is
   begin
      return (USART2_ISR and USART_RXNE) /= 0;
   end Data_Available_UART;

   function Receive_UART return Unsigned_8 is
   begin
      return USART2_RDR;
   end Receive_UART;

   Incoming_Byte : Unsigned_8;
   TMS_Sequence : TMS_Array;

   TDI_1 : Unsigned_8;

   Trash         : Unsigned_8;
   In_Transfer   : Boolean := False;
   Timeout_Count : Natural := 0;

   --  Main loop
begin
   Initialize_Hardware;
   
   --  TEMP: SEQUENCE WILL HAVE 2 of the data register 0s

   --  WORKING SEQUENCE (OUTPUT: 0x000001FE)
   --  TMS_Sequence(1) := 16#FB#;
   --  TMS_Sequence(2) := 16#00#;
   --  TMS_Sequence(3) := 16#7C#;
   --  TMS_Sequence(4) := 16#20#;
   --  TMS_Sequence(5) :=16#00#;
   --  TMS_Sequence(6) := 16#00#;
   --  TMS_Sequence(7) := 16#00#;
   --  TMS_Sequence(8) := 16#0F#;
   --  TMS_Sequence(9) := 16#80#;

   --  TMS_Sequence(1) := 16#01#;
   TMS_Sequence(0) := 16#00#;
   TMS_Sequence(1) := 16#DF#;
   TMS_Sequence(2) := 16#00#;
   TMS_Sequence(3) := 16#3E#;
   TMS_Sequence(4) := 16#10#;
   TMS_Sequence(5) :=16#00#;
   TMS_Sequence(6) := 16#00#;
   TMS_Sequence(7) := 16#00#;
   TMS_Sequence(8) := 16#C0#;
   TMS_Sequence(9) := 16#07#;

   TDI_1 := 16#11#;
   --  Ada.Text_IO.Put_Line(Ada.Real_Time.Clock);
   JTAG_Sequence (TMS_Sequence, TDI_1, 8);
   --  Read_ID_Final;
   --  System_Clock : = HAL.RCC.SystemCoreClock;
   --  Ada.Text_IO.Put_Line("System Clock: " 7Integer'im)
   loop
      Transmit_Hex_32 (Word);
      delay until Clock + Milliseconds(1000);
   end loop;

   --  --  If this is the first byte of a stream, pull CS low
   --     if not In_Transfer then
   --        GPIOA_BSRR := 16#0010_0000#; -- CS Low (PA4)
   --        In_Transfer := True;
   --     end if;


   --  --  Forward to SPI
   --  Trash := TransceiveTDI (TDI);

   --  loop
   --     if Data_Available_UART then
   --        Incoming_Byte := Receive_UART;

   --        --  If this is the first byte of a stream, pull CS low
   --        if not In_Transfer then
   --           GPIOA_BSRR := 16#0010_0000#; -- CS Low (PA4)
   --           In_Transfer := True;
   --        end if;

   --        --  Forward to SPI
   --        Trash := Transceive (Incoming_Byte);

   --        --  Reset timeout because we are active
   --        Timeout_Count := 0;
   --     else
   --        --  If we were in a transfer but no data is coming
   --        if In_Transfer then
   --           Timeout_Count := Timeout_Count + 1;
   --           --  Small artificial delay to define "End of File"
   --           if Timeout_Count > 50_000 then
   --              --  Wait for SPI to finish last bits
   --              while (SPI1_SR and BSY_Flag) /= 0 loop null; end loop;

   --              GPIOA_BSRR := 16#0000_0010#; -- CS High (PA4)
   --              In_Transfer := False;
   --              Timeout_Count := 0;
   --           end if;
   --        end if;
   --     end if;
   --  end loop;

end FPGA_Programming;