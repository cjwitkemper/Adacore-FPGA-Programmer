with STM32F0X0.RCC;  use STM32F0X0.RCC;
with STM32F0X0.GPIO; use STM32F0X0.GPIO;

procedure Stm32f070rb_Blinky is
begin
   RCC_Periph.AHBENR.IOPAEN := 1;         -- Enable GPIOA clock
   GPIOA_Periph.MODER.Arr (5) := 2#01#;   -- OUTPUT mode
   GPIOA_Periph.OTYPER.OT.Arr (5) := 0;   -- Push-pull
   GPIOA_Periph.PUPDR.Arr (5) := 2#00#;   -- No pull
   GPIOA_Periph.OSPEEDR.Arr (5) := 2#00#; -- Low speed
   GPIOA_Periph.BSRR.BR.Arr (5) := 1;     -- Ensure LED is OFF initially
   loop
      GPIOA_Periph.BSRR.BS.Arr (5) := 1;  -- LED ON
      delay 1.0;
      GPIOA_Periph.BSRR.BR.Arr (5) := 1;  -- LED OFF
      delay 1.0;
   end loop;
end Stm32f070rb_Blinky;
