procedure main_controller is
procedure Initialize_Hardware is
   begin

      --  Enable GPIOA
      RCC_Periph.AHBENR.IOPAEN := 1;

      --  Enable USART2
      RCC_Periph.APB1ENR.USART2EN := 1;

      --  PA0, PA2, PA3, PA4, PA5, PA6, PA7
      GPIOA_Periph.MODER.Arr (0) := 2;
      GPIOA_Periph.MODER.Arr (2) := 2;
      GPIOA_Periph.MODER.Arr (3) := 2;
      GPIOA_Periph.MODER.Arr (4) := 1;
      GPIOA_Periph.MODER.Arr (5) := 1;
      GPIOA_Periph.MODER.Arr (6) := 0;
      GPIOA_Periph.MODER.Arr (7) := 1;

      --  Set Alternate function for PA2, PA3 (AF1 for USART2)
      GPIOA_Periph.AFRL.Arr (0) := 1; --  AF1 for USART2
      GPIOA_Periph.AFRL.Arr (2) := 1; --  AF1 for USART2
      GPIOA_Periph.AFRL.Arr (3) := 1; --  AF1 for USART2

      --  Initial CS Low(PA4) and TCK, TMS, TDI Low
      GPIOA_Periph.BSRR.BR.Arr (4) := 1;
      GPIOA_Periph.BSRR.BR.Arr (5) := 1;
      GPIOA_Periph.BSRR.BR.Arr (6) := 1;
      GPIOA_Periph.BSRR.BR.Arr (7) := 1;

      USART2_Periph.CR3.CTSE := 1;

      --  USART2 Configuration (115200 Baud @ 48MHz)
      USART2_Periph.BRR := (DIV_Mantissa => 16#0D#,
                            DIV_Fraction => 0,
                            others       => <>);

      --  Enable UART, Transmit, and Receive
      USART2_Periph.CR1 := (UE     => 1,
                            TE     => 1,
                            RE     => 1,
                            RXNEIE => 0,
                            OVER8  => 0,
                            others => <>);
   end Initialize_Hardware;
begin
   null;
end main_controller;
