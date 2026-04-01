pragma Style_Checks (Off);
with STM32F0x0; use STM32F0x0;
with STM32F0x0.RCC; use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;
with STM32F0x0.USART; use STM32F0x0.USART;
with host_to_mcu; use host_to_mcu;
with mcu_to_fpga; use mcu_to_fpga;
with utils; use utils;
------------------------------------------------------------------------------
--  File:        main.adb
--  Description: Application entry point for the MCU firmware. Performs all
--               hardware initialization before the Ada runtime starts the
--               H2M and M2F tasks defined in host_to_mcu and mcu_to_fpga
--               respectively. Once Initialize_Hardware returns, the two tasks
--               take over all program activity.
--
--  Hardware Initialization (Initialize_Hardware):
--               GPIOA       -- Enables IOPAEN clock; configures pin modes:
--                                PA0        : Alternate function (USART2)
--                                PA2, PA3   : Alternate function AF1 (USART2
--                                             TX / RX)
--                                PA4        : Output (SPI CS, initially low)
--                                PA5        : Output (TCK,  initially low)
--                                PA6        : Input  (TDO)
--                                PA7        : Output (TDI/TMS, initially low)
--               USART2      -- Enables APB1 clock; configures 115200 baud
--                             at 48 MHz with CTS flow control; enables
--                             UART, TX, and RX
--
--  Tasks Started Implicitly by Ada Runtime:
--               H2M (host_to_mcu) -- Serial command interpreter; drives
--                                    shared state machine in response to
--                                    host commands received over USART2
--               M2F (mcu_to_fpga) -- JTAG/SPI/USART worker; executes FPGA
--                                    configuration and firmware upload
--                                    sequences as directed by H2M
--
--  Target:      STM32F0x0
--  Language:    Ada 2012
------------------------------------------------------------------------------
procedure Main is

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
      Initialize_Hardware;
end Main;