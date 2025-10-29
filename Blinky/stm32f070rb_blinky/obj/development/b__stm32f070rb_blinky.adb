pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__stm32f070rb_blinky.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__stm32f070rb_blinky.adb");
pragma Suppress (Overflow_Check);

package body ada_main is

   E12 : Short_Integer; pragma Import (Ada, E12, "ada__real_time_E");


   procedure adainit is
   begin
      null;

      Ada.Real_Time'Elab_Body;
      E12 := E12 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_stm32f070rb_blinky");

   procedure main is
      Ensure_Reference : aliased System.Address := Ada_Main_Program_Name'Address;
      pragma Volatile (Ensure_Reference);

   begin
      adainit;
      Ada_Main_Program;
   end;

--  BEGIN Object file/option list
   --   /home/kaden-nutter/light_tasking_stm32f0xx_15.0.0_d14cebc3/stm32f070rb_blinky/obj/development/stm32f0x0.o
   --   /home/kaden-nutter/light_tasking_stm32f0xx_15.0.0_d14cebc3/stm32f070rb_blinky/obj/development/stm32f0x0-gpio.o
   --   /home/kaden-nutter/light_tasking_stm32f0xx_15.0.0_d14cebc3/stm32f070rb_blinky/obj/development/stm32f0x0-rcc.o
   --   /home/kaden-nutter/light_tasking_stm32f0xx_15.0.0_d14cebc3/stm32f070rb_blinky/obj/development/stm32f070rb_blinky.o
   --   -L/home/kaden-nutter/light_tasking_stm32f0xx_15.0.0_d14cebc3/stm32f070rb_blinky/obj/development/
   --   -L/home/kaden-nutter/light_tasking_stm32f0xx_15.0.0_d14cebc3/stm32f070rb_blinky/obj/development/
   --   -L/home/kaden-nutter/snap/code/209/.local/share/alire/builds/light_tasking_stm32f0xx_15.0.0_d14cebc3/6017b4eeb699983dff649c9da62ebbb03009e74f5cc58a09b5b4efad1435cf46/adalib/
   --   -static
   --   -lgnarl
   --   -lgnat
--  END Object file/option list   

end ada_main;
