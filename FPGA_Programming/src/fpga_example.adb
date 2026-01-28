with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
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
      RCC_AHBENR  := RCC_AHBENR or 16#0002_0000#; --  GPIOA
      RCC_APB2ENR := RCC_APB2ENR or 16#0000_1000#; --  SPI1 (bit 12)
      RCC_APB1ENR  := RCC_APB1ENR or 16#0002_0000#; --  USART2 (bit 17)

      --  Setting pins SPI(PA5,6,7) UART(PA2,PA3)
      GPIOA_MODER := (GPIOA_MODER and 16#FFFF_000F#) or 16#0000_45A0#;

      --  Select Alternate function for PA5, PA6, PA7
      GPIOA_AFRL := (GPIOA_AFRL and 16#FFFF_00FF#) or 16#0000_1100#;

      --  CR1: Master, Baud Rate
      SPI1_CR1    := 16#033C# or 16#0080#; --  Master, 256 LSB First
      SPI1_CR2    := 16#0700# or 16#1000#; --  8-bit mode
      SPI1_CR1    := SPI1_CR1 or 16#0040#; --  Enable

      --  UART Config (115200 Baud @ 48MHz Clock)
      USART2_BRR := 16#01A1#; --  48,000,000 / 115,200 = 417 (0x1A1)
      USART2_CR1 := 16#0000_000D#;

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

   type TMS_Array is array (1 .. 8) of Unsigned_8;
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
            Clock_Cycle := Clock_Cycle + 1;
            
            --  Extract TMS bit
            TMS_Bit := Shift_Right (TMS_Bytes(Byte_Index), Bit_Index) and 1;
            
            --  Set TMS pin (PA4)
            if TMS_Bit = 1 then
               GPIOA_BSRR := Shift_Left (1, TMS_Pin);
            else
               GPIOA_BSRR := Shift_Left (1, TMS_Pin + 16);
            end if;
            
            --  Starting from clock cycle 11, also send TDI
            if Clock_Cycle >= 11 and TDI_Bit_Index < TDI_Bits then
               TDI_Bit := Shift_Right (TDI_Data, TDI_Bit_Index) and 1;
               
               if TDI_Bit = 1 then
                  GPIOA_BSRR := Shift_Left (1, TDI_Pin);
               else
                  GPIOA_BSRR := Shift_Left (1, TDI_Pin + 16);
               end if;
               
               TDI_Bit_Index := TDI_Bit_Index + 1;
            end if;
            
            for I in 1 .. 500 loop null; end loop;
            --  Clock low (PA5)
            GPIOA_BSRR := Shift_Left (1, TCK_Pin + 16);
            for I in 1 .. 500 loop null; end loop;
            
if Clock_Cycle >= 24 and Clock_Cycle < 55 then

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
            GPIOA_BSRR := Shift_Left (1, TCK_Pin);
            

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
            
            for I in 1 .. 500 loop null; end loop;
         end loop;
      end loop;
   end JTAG_Sequence;

procedure Read_IDCODE_Manual is
   procedure Clock_TMS(TMS : Unsigned_32; TDI : Unsigned_32 := 0) is
   begin
      -- Set TMS
      if TMS = 1 then GPIOA_BSRR := Shift_Left(1, TMS_Pin);
      else GPIOA_BSRR := Shift_Left(1, TMS_Pin + 16); end if;
      -- Set TDI
      if TDI = 1 then GPIOA_BSRR := Shift_Left(1, TDI_Pin);
      else GPIOA_BSRR := Shift_Left(1, TDI_Pin + 16); end if;
      
      for I in 1..500 loop null; end loop;
      GPIOA_BSRR := Shift_Left(1, TCK_Pin + 16); -- Clock Low
      for I in 1..500 loop null; end loop;
      GPIOA_BSRR := Shift_Left(1, TCK_Pin);      -- Clock High
   end Clock_TMS;

begin
   Word := 0;
   -- 1. Reset
   for I in 1..5 loop Clock_TMS(1); end loop;
   -- 2. Idle
   Clock_TMS(0);
   -- 3. Move to Shift-IR (TMS: 1, 1, 0, 0)
   Clock_TMS(1); Clock_TMS(1); Clock_TMS(0); Clock_TMS(0);
   -- 4. Shift Instruction 0x11 (8 bits: 1, 0, 0, 0, 1, 0, 0, 0)
   -- Last bit must have TMS=1 to move to Exit1-IR
   Clock_TMS(0, 1); Clock_TMS(0, 0); Clock_TMS(0, 0); Clock_TMS(0, 0);
   Clock_TMS(0, 1); Clock_TMS(0, 0); Clock_TMS(0, 0); Clock_TMS(1, 0);
   -- 5. Move to Shift-DR (Update-IR -> SelDR -> CapDR -> ShiftDR) (TMS: 1, 1, 0, 0)
   Clock_TMS(1); Clock_TMS(1); Clock_TMS(0); Clock_TMS(0);
   -- 6. Read 32 bits
for I in 0 .. 31 loop
   -- Force TDI Low (PA7)
   GPIOA_BSRR := Shift_Left(1, TDI_Pin + 16); 
   
   -- Clock Low
   GPIOA_BSRR := Shift_Left(1, TCK_Pin + 16);
   for J in 1 .. 1000 loop null; end loop;

   -- Read TDO
   if (Shift_Right(GPIOA_IDR, TDO_Pin) and 1) = 1 then
      Transmit_UART(Character'Pos('#'));
   else
      Transmit_UART(Character'Pos('.'));
   end if;

   -- Clock High
   GPIOA_BSRR := Shift_Left(1, TCK_Pin);
   for J in 1 .. 1000 loop null; end loop;
end loop;
end Read_IDCODE_Manual;

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
   
   --  TMS_Sequence(1) := 16#07#;
   --  TMS_Sequence(2) := 16#D8#;
   --  TMS_Sequence(3) := 16#03#;
   --  TMS_Sequence(4) := 16#08#;
   --  TMS_Sequence(5) :=16#00#;
   --  TMS_Sequence(6) := 16#00#;
   --  TMS_Sequence(7) := 16#00#;
   --  TMS_Sequence(8) := 16#02#;

   TMS_Sequence(1) := 16#1F#;
   TMS_Sequence(2) := 16#0C#;
   TMS_Sequence(3) := 16#80#;
   TMS_Sequence(4) := 16#03#;
   TMS_Sequence(5) :=16#00#;
   TMS_Sequence(6) := 16#00#;
   TMS_Sequence(7) := 16#00#;
   TMS_Sequence(8) := 16#01#;

   TDI_1 := 16#44#;

   --  JTAG_Sequence (TMS_Sequence, TDI_1, 8);
   Read_IDCODE_Manual;
   --  loop
   --     Transmit_Hex_32 (Word);
   --     for I in 1 .. 1000000 loop null; end loop;
   --  end loop;

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
