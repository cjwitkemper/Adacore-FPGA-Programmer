with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
with Interfaces; use Interfaces;
with STM32F0x0;
with STM32F0x0.RCC; use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;
with STM32F0x0.SPI; use STM32F0x0.SPI;
with STM32F0x0.USART; use STM32F0x0.USART;

procedure uart_example is
   --  Register Definitions
   --  RCC
   RCC_AHBENR  : Unsigned_32 with Address => To_Address (16#4002_1014#);
   RCC_APB2ENR : Unsigned_32 with Address => To_Address (16#4002_1018#);
   RCC_APB1ENR : Unsigned_32 with Address => To_Address (16#4002_101C#);
   --  GPIOA
   GPIOA_MODER : Unsigned_32 with Address => To_Address (16#4800_0000#);
   GPIOA_BSRR  : Unsigned_32 with Address => To_Address (16#4800_0018#);
   GPIOA_AFRL  : Unsigned_32 with Address => To_Address (16#4800_0020#);
   --  GPIOB
   GPIOB_MODER : Unsigned_32 with Address => To_Address (16#4800_0400#);
   GPIOB_BSRR  : Unsigned_32 with Address => To_Address (16#4800_0418#);
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

   --  Flags
   RXNE_Flag : constant Unsigned_16 := 16#0001#;
   TXE_Flag : constant Unsigned_16 := 16#0002#;
   BSY_Flag : constant Unsigned_16 := 16#0080#;
   USART_RXNE : constant Unsigned_32 := 16#0000_0020#; --  Bit 5 in ISR

   procedure Initialize_Hardware is
   begin
      --  Clocks for GPIOA and SPI1 and USART2
      RCC_AHBENR  := RCC_AHBENR or 16#0006_0000#; --  GPIOA & GPIOB (bits 17 & 18)
      RCC_APB2ENR := RCC_APB2ENR or 16#0000_1000#; --  SPI1 (bit 12)
      RCC_APB1ENR  := RCC_APB1ENR or 16#0002_0000#; --  USART2 (bit 17)

      --  Setting pins SPI(PA5,6,7) UART(PA2,PA3)
      GPIOA_MODER := (GPIOA_MODER and 16#FFFF_000F#) or 16#0000_A9A0#;

      --  Select Alternate function for PA5, PA6, PA7
      GPIOA_AFRL := (GPIOA_AFRL and 16#0000_00FF#) or 16#0000_1100#;

      --  Configure PB3, PB4, PB5 as General Purpose Output (01)
      GPIOB_MODER := (GPIOB_MODER and 16#FFFF_F03F#) or 16#0000_0540#;

      --  Set PB3 HIGH, PB4 and PB5 LOW
      GPIOB_BSRR := 16#0030_0008#;

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

   function Data_Available_UART return Boolean is
   begin
      return (USART2_ISR and USART_RXNE) /= 0;
   end Data_Available_UART;

   function Receive_UART return Unsigned_8 is
   begin
      return USART2_RDR;
   end Receive_UART;

   Incoming_Byte : Unsigned_8;
   Trash         : Unsigned_8;
   In_Transfer   : Boolean := False;
   Timeout_Count : Natural := 0;

   --  Main loop
begin
   Initialize_Hardware;

   loop
      if Data_Available_UART then
         Incoming_Byte := Receive_UART;

         --  If this is the first byte of a stream, pull CS low
         if not In_Transfer then
            GPIOA_BSRR := 16#0010_0000#; -- CS Low (PA4)
            In_Transfer := True;
         end if;

         --  Forward to SPI
         Trash := Transceive (Incoming_Byte);

         --  Reset timeout because we are active
         Timeout_Count := 0;
      else
         --  If we were in a transfer but no data is coming
         if In_Transfer then
            Timeout_Count := Timeout_Count + 1;
            --  Small artificial delay to define "End of File"
            if Timeout_Count > 50_000 then
               --  Wait for SPI to finish last bits
               while (SPI1_SR and BSY_Flag) /= 0 loop null; end loop;

               GPIOA_BSRR := 16#0000_0010#; -- CS High (PA4)
               In_Transfer := False;
               Timeout_Count := 0;
            end if;
         end if;
      end if;
   end loop;

end uart_example;
