pragma Style_Checks (Off);

with STM32F0x0;               use STM32F0x0;
with STM32F0x0.RCC;           use STM32F0x0.RCC;
with STM32F0x0.GPIO;          use STM32F0x0.GPIO;
with STM32F0x0.SPI;           use STM32F0x0.SPI;
------------------------------------------------------------------------------
--  File:        utils.adb
--  Description: Package body providing shared low-level hardware utilities
--               used by both host_to_mcu and mcu_to_fpga. Contains the
--               protected shared state object, GPIO pin control, JTAG clock
--               generation, SPI peripheral management, and the byte-level
--               SPI/JTAG data transfer routines.
--
--  Components:
--               ProgState (Protected) -- Thread-safe getter/setter for the
--                                        shared State enumeration; coordinates
--                                        the H2M and M2F task state machine
--               Pin_Low               -- Drives a GPIOA pin low via BSRR.BR
--               Pin_High              -- Drives a GPIOA pin high via BSRR.BS
--               Pulse_TCK             -- Generates a single JTAG TCK pulse
--                                        (low then high on PA5)
--               SPI_Enable            -- Enables SPI1 clock; configures
--                                        master mode, 12 MHz baud, CPOL/CPHA
--                                        mode 3, 8-bit frames, software SSM;
--                                        switches PA5/PA6/PA7 to AF0 for
--                                        SPI1 SCK/MISO/MOSI
--               SPI_Disable           -- Waits for SPI1 bus idle, restores
--                                        PA5/PA6/PA7 to GPIO output/input
--                                        mode, and gates off the SPI1 clock
--               Transceive_Byte       -- Blocking SPI byte transmit; writes
--                                        directly to the DR register via an
--                                        address overlay for 8-bit access
--               Transceive_Last_Byte_JTAG -- Bit-bangs the final bitstream
--                                        byte over JTAG, asserting TMS high
--                                        on the last bit to exit Shift-DR
--
--  Target:      STM32F0x0
--  Language:    Ada 2012
------------------------------------------------------------------------------
package body utils is

   protected body ProgState is

   procedure Set (V : in State) is
   begin
      Value := V;
   end Set;
   function Get return State is
   begin
      return Value;
   end Get;
   end ProgState;


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
      GPIOA_Periph.BSRR.BR.Arr (TCK_Pin) := 1;
      GPIOA_Periph.BSRR.BS.Arr (TCK_Pin) := 1;
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

   procedure Transceive_Byte (Data_Out : Byte) is
      DR_Byte : Byte
      with Address => SPI1_Periph.DR'Address;
   begin
      while SPI1_Periph.SR.TXE = 0 loop
         null;
      end loop;
      DR_Byte := Data_Out;
   end Transceive_Byte;

   procedure Transceive_Last_Byte_JTAG (Data_Out : Byte) is
   begin
      for Bit in reverse 0 .. 7 loop
         if Bit = 0 then
            Pin_High (tms_pin);
         end if;

         if (Data_Out and Shift_Left (1, Bit)) /= 0 then
            Pin_High (TDI_Pin);
         else
            Pin_Low (TDI_Pin);
         end if;

         Pulse_TCK;
      end loop;
   end Transceive_Last_Byte_JTAG;

end Utils;