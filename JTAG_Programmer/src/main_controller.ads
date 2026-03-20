package main_controller is
   procedure Initialize_Hardware;

   procedure Pin_High (Pin : Natural) is
   begin
      GPIOA_Periph.BSRR.BS.Arr (Pin) := 1;
   end Pin_High;

   procedure Pin_Low (Pin : Natural) is
   begin
      GPIOA_Periph.BSRR.BR.Arr (Pin) := 1;
   end Pin_Low;

   procedure Pulse_TCK is
   begin
      Pin_Low (TCK_Pin);
      Asm ("nop", Volatile => True);
      Asm ("nop", Volatile => True);
      Pin_High (TCK_Pin);
   end Pulse_TCK;
end main_controller;