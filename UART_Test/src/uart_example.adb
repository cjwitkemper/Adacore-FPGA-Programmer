with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
with Interfaces; use Interfaces;

procedure uart_example is

   --  Register Definitions
   RCC_AHBENR  : Unsigned_32 with Address => To_Address (16#4002_1014#);
   RCC_APB2ENR : Unsigned_32 with Address => To_Address (16#4002_1018#);
   RCC_APB1ENR : Unsigned_32 with Address => To_Address (16#4002_101C#);
   GPIOA_MODER : Unsigned_32 with Address => To_Address (16#4800_0000#);
   GPIOA_BSRR  : Unsigned_32 with Address => To_Address (16#4800_0018#);
   GPIOA_AFRL  : Unsigned_32 with Address => To_Address (16#4800_0020#);
   SPI1_CR1    : Unsigned_16 with Address => To_Address (16#4001_3000#);
   SPI1_CR2    : Unsigned_16 with Address => To_Address (16#4001_3004#);
   SPI1_SR     : Unsigned_16 with Address => To_Address (16#4001_3008#);
   SPI1_DR     : Unsigned_8  with Address => To_Address (16#4001_300C#);
   USART2_CR1  : Unsigned_32 with Address => To_Address (16#4000_4400#);
   USART2_BRR  : Unsigned_32 with Address => To_Address (16#4000_440C#);
   USART2_ISR  : Unsigned_32 with Address => To_Address (16#4000_441C#);
   USART2_RDR  : Unsigned_8  with Address => To_Address (16#4000_4424#);

   --  Flags
   RXNE_Flag : constant Unsigned_16 := 16#0001#;
   TXE_Flag : constant Unsigned_16 := 16#0002#;
   BSY_Flag : constant Unsigned_16 := 16#0080#;
   UART_RXNE : constant Unsigned_32 := 16#0000_0020#; --  Bit 5 in ISR

   Incoming_Byte : Unsigned_8;

   --  Setting GPIO
   procedure Initialize_Hardware is
   begin

      --  Clocks for GPIOA and SPI1
      RCC_AHBENR  := RCC_AHBENR or 16#0002_0000#;
      RCC_APB2ENR := RCC_APB2ENR or 16#0000_1000#; --  SPI1 (bit 12)
      RCC_APB1ENR  := RCC_APB1ENR or 16#0002_0000#; --  USART2 (bit 17)

      --  Setting pins SPI(PA5,6,7) UART(PA2,PA3)
      GPIOA_MODER := (GPIOA_MODER and 16#FFFF_003F#) or 16#0000_A9A0#;

      --  Select Alternate function for PA5, PA6, PA7
      GPIOA_AFRL := (GPIOA_AFRL and 16#000F_FFFF#) or 16#0000_1100#;

      --  CR1: Master, Baud Rate
      SPI1_CR1    := 16#0304#; --  Master, 256
      SPI1_CR2    := 16#0700# or 16#1000#; --  8-bit mode
      SPI1_CR1    := SPI1_CR1 or 16#0040#; --  Enable

      --  UART Config (115200 Baud @ 8MHz Clock)
      --  USART2_BRR := 16#0045#; --  8,000,000 / 115,200 = 69 (0x45)
      USART2_BRR := 16#01A1#; -- 48,000,000 / 115,200 = 417 (0x1A1)
      USART2_CR1 := 16#0000_000D#;

      --  Set CS High initially
      GPIOA_BSRR := 16#0000_0010#;
   end Initialize_Hardware;

   --  Checks sends and receives
   function Transceive (Data_Out : Unsigned_8) return Unsigned_8 is
   begin
      --  Wait for TX buffer to be empty
      while (SPI1_SR and TXE_Flag) = 0 loop null; end loop;

      --  Send byte
      SPI1_DR := Data_Out;

      --  Wait for RX buffer to have data (Arduino response)
      while (SPI1_SR and RXNE_Flag) = 0 loop null; end loop;
      return SPI1_DR;
   end Transceive;

   --  Main loop
begin
   Initialize_Hardware;

   loop
      --  Check if a byte arrived from Ubuntu via the USB cable
      if (USART2_ISR and UART_RXNE) /= 0 then

         --  Read the file byte from USART2
         Incoming_Byte := USART2_RDR;

         --  SEND TO ARDUINO
         GPIOA_BSRR := 16#0010_0000#; --  CS LOW

         declare
            Trash : Unsigned_8;
         begin
            Trash := Transceive (Incoming_Byte);
         end;

         --  Ensure SPI is finished before lifting CS
         while (SPI1_SR and BSY_Flag) /= 0 loop null; end loop;

         GPIOA_BSRR := 16#0000_0010#; --  CS HIGH
         
         --  Small delay to let Arduino process the byte
         for J in 1 .. 50_000 loop
            null;
         end loop;
      end if;
   end loop;

end uart_example;
