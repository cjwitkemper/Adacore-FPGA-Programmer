pragma Style_Checks (Off);

--  This spec has been automatically generated from STM32F0x0.svd

pragma Restrictions (No_Elaboration_Code);

with System;

package STM32F0x0.DBGMCU is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype IDCODE_DEV_ID_Field is STM32F0x0.UInt12;
   subtype IDCODE_DIV_ID_Field is STM32F0x0.UInt4;
   subtype IDCODE_REV_ID_Field is STM32F0x0.UInt16;

   --  MCU Device ID Code Register
   type IDCODE_Register is record
      --  Read-only. Device Identifier
      DEV_ID : IDCODE_DEV_ID_Field;
      --  Read-only. Division Identifier
      DIV_ID : IDCODE_DIV_ID_Field;
      --  Read-only. Revision Identifier
      REV_ID : IDCODE_REV_ID_Field;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for IDCODE_Register use record
      DEV_ID at 0 range 0 .. 11;
      DIV_ID at 0 range 12 .. 15;
      REV_ID at 0 range 16 .. 31;
   end record;

   subtype CR_DBG_STOP_Field is STM32F0x0.Bit;
   subtype CR_DBG_STANDBY_Field is STM32F0x0.Bit;

   --  Debug MCU Configuration Register
   type CR_Register is record
      --  unspecified
      Reserved_0_0  : STM32F0x0.Bit := 16#0#;
      --  Debug Stop Mode
      DBG_STOP      : CR_DBG_STOP_Field := 16#0#;
      --  Debug Standby Mode
      DBG_STANDBY   : CR_DBG_STANDBY_Field := 16#0#;
      --  unspecified
      Reserved_3_31 : STM32F0x0.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CR_Register use record
      Reserved_0_0  at 0 range 0 .. 0;
      DBG_STOP      at 0 range 1 .. 1;
      DBG_STANDBY   at 0 range 2 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   subtype APB1_FZ_DBG_TIM3_STOP_Field is STM32F0x0.Bit;
   subtype APB1_FZ_DBG_TIM6_STOP_Field is STM32F0x0.Bit;
   subtype APB1_FZ_DBG_TIM7_STOP_Field is STM32F0x0.Bit;
   subtype APB1_FZ_DBG_TIM14_STOP_Field is STM32F0x0.Bit;
   subtype APB1_FZ_DBG_WWDG_STOP_Field is STM32F0x0.Bit;
   subtype APB1_FZ_DBG_IWDG_STOP_Field is STM32F0x0.Bit;
   subtype APB1_FZ_DBG_I2C1_SMBUS_TIMEOUT_Field is STM32F0x0.Bit;

   --  Debug MCU APB1 freeze register
   type APB1_FZ_Register is record
      --  unspecified
      Reserved_0_0           : STM32F0x0.Bit := 16#0#;
      --  TIM3 counter stopped when core is halted
      DBG_TIM3_STOP          : APB1_FZ_DBG_TIM3_STOP_Field := 16#0#;
      --  unspecified
      Reserved_2_3           : STM32F0x0.UInt2 := 16#0#;
      --  TIM6 counter stopped when core is halted
      DBG_TIM6_STOP          : APB1_FZ_DBG_TIM6_STOP_Field := 16#0#;
      --  TIM7 counter stopped when core is halted
      DBG_TIM7_STOP          : APB1_FZ_DBG_TIM7_STOP_Field := 16#0#;
      --  unspecified
      Reserved_6_7           : STM32F0x0.UInt2 := 16#0#;
      --  TIM14 counter stopped when core is halted
      DBG_TIM14_STOP         : APB1_FZ_DBG_TIM14_STOP_Field := 16#0#;
      --  unspecified
      Reserved_9_10          : STM32F0x0.UInt2 := 16#0#;
      --  Debug window watchdog stopped when core is halted
      DBG_WWDG_STOP          : APB1_FZ_DBG_WWDG_STOP_Field := 16#0#;
      --  Debug independent watchdog stopped when core is halted
      DBG_IWDG_STOP          : APB1_FZ_DBG_IWDG_STOP_Field := 16#0#;
      --  unspecified
      Reserved_13_20         : STM32F0x0.Byte := 16#0#;
      --  SMBUS timeout mode stopped when core is halted
      DBG_I2C1_SMBUS_TIMEOUT : APB1_FZ_DBG_I2C1_SMBUS_TIMEOUT_Field := 16#0#;
      --  unspecified
      Reserved_22_31         : STM32F0x0.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for APB1_FZ_Register use record
      Reserved_0_0           at 0 range 0 .. 0;
      DBG_TIM3_STOP          at 0 range 1 .. 1;
      Reserved_2_3           at 0 range 2 .. 3;
      DBG_TIM6_STOP          at 0 range 4 .. 4;
      DBG_TIM7_STOP          at 0 range 5 .. 5;
      Reserved_6_7           at 0 range 6 .. 7;
      DBG_TIM14_STOP         at 0 range 8 .. 8;
      Reserved_9_10          at 0 range 9 .. 10;
      DBG_WWDG_STOP          at 0 range 11 .. 11;
      DBG_IWDG_STOP          at 0 range 12 .. 12;
      Reserved_13_20         at 0 range 13 .. 20;
      DBG_I2C1_SMBUS_TIMEOUT at 0 range 21 .. 21;
      Reserved_22_31         at 0 range 22 .. 31;
   end record;

   subtype APB2_FZ_DBG_TIM1_STOP_Field is STM32F0x0.Bit;
   subtype APB2_FZ_DBG_TIM15_STOP_Field is STM32F0x0.Bit;
   subtype APB2_FZ_DBG_TIM16_STOP_Field is STM32F0x0.Bit;
   subtype APB2_FZ_DBG_TIM17_STOP_Field is STM32F0x0.Bit;

   --  Debug MCU APB2 freeze register
   type APB2_FZ_Register is record
      --  unspecified
      Reserved_0_10  : STM32F0x0.UInt11 := 16#0#;
      --  TIM1 counter stopped when core is halted
      DBG_TIM1_STOP  : APB2_FZ_DBG_TIM1_STOP_Field := 16#0#;
      --  unspecified
      Reserved_12_15 : STM32F0x0.UInt4 := 16#0#;
      --  TIM15 counter stopped when core is halted
      DBG_TIM15_STOP : APB2_FZ_DBG_TIM15_STOP_Field := 16#0#;
      --  TIM16 counter stopped when core is halted
      DBG_TIM16_STOP : APB2_FZ_DBG_TIM16_STOP_Field := 16#0#;
      --  TIM17 counter stopped when core is halted
      DBG_TIM17_STOP : APB2_FZ_DBG_TIM17_STOP_Field := 16#0#;
      --  unspecified
      Reserved_19_31 : STM32F0x0.UInt13 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for APB2_FZ_Register use record
      Reserved_0_10  at 0 range 0 .. 10;
      DBG_TIM1_STOP  at 0 range 11 .. 11;
      Reserved_12_15 at 0 range 12 .. 15;
      DBG_TIM15_STOP at 0 range 16 .. 16;
      DBG_TIM16_STOP at 0 range 17 .. 17;
      DBG_TIM17_STOP at 0 range 18 .. 18;
      Reserved_19_31 at 0 range 19 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Debug support
   type DBGMCU_Peripheral is record
      --  MCU Device ID Code Register
      IDCODE  : aliased IDCODE_Register;
      --  Debug MCU Configuration Register
      CR      : aliased CR_Register;
      --  Debug MCU APB1 freeze register
      APB1_FZ : aliased APB1_FZ_Register;
      --  Debug MCU APB2 freeze register
      APB2_FZ : aliased APB2_FZ_Register;
   end record
     with Volatile;

   for DBGMCU_Peripheral use record
      IDCODE  at 16#0# range 0 .. 31;
      CR      at 16#4# range 0 .. 31;
      APB1_FZ at 16#8# range 0 .. 31;
      APB2_FZ at 16#C# range 0 .. 31;
   end record;

   --  Debug support
   DBGMCU_Periph : aliased DBGMCU_Peripheral
     with Import, Address => DBGMCU_Base;

end STM32F0x0.DBGMCU;
