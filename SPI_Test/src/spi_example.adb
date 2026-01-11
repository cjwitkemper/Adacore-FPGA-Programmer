with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
with Interfaces; use Interfaces;

procedure SPI_Master_Example is

   --  Register Definitions
   RCC_AHBENR  : Unsigned_32 with Address => To_Address (16#4002_1014#);
   RCC_APB2ENR : Unsigned_32 with Address => To_Address (16#4002_1018#);
   GPIOA_MODER : Unsigned_32 with Address => To_Address (16#4800_0000#);
   GPIOA_BSRR  : Unsigned_32 with Address => To_Address (16#4800_0018#);
   SPI1_CR1    : Unsigned_16 with Address => To_Address (16#4001_3000#);
   SPI1_CR2    : Unsigned_16 with Address => To_Address (16#4001_3004#);
   SPI1_SR     : Unsigned_16 with Address => To_Address (16#4001_3008#);
   SPI1_DR     : Unsigned_8  with Address => To_Address (16#4001_300C#);

   TXE_Flag : constant Unsigned_16 := 16#0002#;
   BSY_Flag : constant Unsigned_16 := 16#0080#;
   Message  : constant String      := "Hello Arduino Uno";
   Delay_Counter : Unsigned_32 := 0 with Volatile;
   procedure Initialize_SPI is
   begin
      RCC_AHBENR  := RCC_AHBENR or 16#0002_0000#;
      RCC_APB2ENR := RCC_APB2ENR or 16#0000_1000#;
      GPIOA_MODER := (GPIOA_MODER and 16#FFFF_00FF#) or 16#0000_A900#;
      SPI1_CR1    := 16#033C#; --  Master, Slowest Clock
      SPI1_CR2    := 16#0704#; --  8-bit mode
      SPI1_CR1    := SPI1_CR1 or 16#0040#; --  Enable
   end Initialize_SPI;

   function Transceive (Data_Out : Unsigned_8) return Unsigned_8 is
      Dummy : Unsigned_8;
   begin
      while (SPI1_SR and TXE_Flag) = 0 loop null; end loop;
      SPI1_DR := Data_Out;
      while (SPI1_SR and BSY_Flag) /= 0 loop null; end loop;
      Dummy := SPI1_DR;
      return Dummy;
   end Transceive;

   Trash : Unsigned_8;

begin
   Initialize_SPI;

   loop
      --  1. Pull CS LOW (Start of the sentence)
      GPIOA_BSRR := 16#0010_0000#; 

      for I in Message'Range loop
         --  Transceive the letter
         Trash := Transceive (Unsigned_8 (Character'Pos (Message (I))));

         --  Inter-character delay (helps Arduino process Serial)
         for J in 1 .. 100_000 loop
            null;
         end loop;
      end loop;

      --  2. Send the Newline (tells Arduino to start a new line)
      Trash := Transceive (10);

      --  3. Pull CS HIGH (End of the sentence)
      GPIOA_BSRR := 16#0000_0010#;

      --  4. THE BIG DELAY (Roughly 5 seconds)
      --  Using a nested loop prevents the compiler from skipping the delay

      

      --  Inside the loop, after CS High
      for Outer in 1 .. 10_000 loop
         for Inner in 1 .. 2_000 loop
            Delay_Counter := Delay_Counter + 1; --  Forces CPU to actually work
         end loop;
      end loop;
   end loop;
end SPI_Master_Example;
