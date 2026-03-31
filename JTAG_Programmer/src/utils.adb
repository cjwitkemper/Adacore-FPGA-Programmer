with Main;
with Utils;
procedure Utils is

   protected body State is

   procedure Set_State (V : in ProgState) is
   begin
      pState := V;
   end Set_State;

   function Get_State return ProgState is
   begin
      return pState;
   end Get_State;
   end State;

   procedure Pin_Low (Pin : Natural) is
   begin
      GPIOA_Periph.BSRR.BR.Arr (Pin) := 1;
   end Pin_Low;

   procedure Pin_High (Pin : Natural) is
   begin
      GPIOA_Periph.BSRR.BS.Arr (Pin) := 1;
   end Pin_High;

   procedure Pulse_TCK is
   begin
      Pin_Low (TCK_Pin);
      Asm ("nop", Volatile => True);
      Asm ("nop", Volatile => True);
      Pin_High (TCK_Pin);
   end Pulse_TCK;

    procedure SPI_Enable is
   begin
      RCC_Periph.APB2ENR.SPI1EN := 1;

      --  CR1: Master mode, Baud rate 12MHz, Software Slave Mgmt, Internal Slave Select
      SPI1_Periph.CR1 :=
        (MSTR     => 1,
         BR       => 1,
         CPOL     => 1,
         CPHA     => 1,
         LSBFIRST => 0,
         SSM      => 1,
         SSI      => 1,
         SPE      => 1,
         others   => <>);

      --  CR2: 8-bit Data Size (7 is 8-bit), FRXTH must be 1 for 8-bit/Byte access
      SPI1_Periph.CR2 := (DS => 7, FRXTH => 1, others => <>);

      GPIOA_Periph.AFRL.Arr (5) := 0; --  AF0 for SPI1
      GPIOA_Periph.AFRL.Arr (6) := 0; --  AF0 for SPI1
      GPIOA_Periph.AFRL.Arr (7) := 0; --  AF0 for SPI1

      GPIOA_Periph.MODER.Arr (5) := 2;
      GPIOA_Periph.MODER.Arr (6) := 2;
      GPIOA_Periph.MODER.Arr (7) := 2;

   end SPI_Enable;

   procedure SPI_Disable is
   begin
      while SPI1_Periph.SR.BSY /= 0 loop
         null;
      end loop;

      Pin_High (TCK_Pin);
      Pin_HIGH (TDI_Pin);
      Pin_Low (tms_pin);

      GPIOA_Periph.MODER.Arr (5) := 1;
      GPIOA_Periph.MODER.Arr (6) := 0;
      GPIOA_Periph.MODER.Arr (7) := 1;
      RCC_Periph.APB2ENR.SPI1EN := 0;
   end SPI_Disable;

begin

end Utils;