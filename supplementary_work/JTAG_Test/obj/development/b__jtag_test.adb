pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__jtag_test.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__jtag_test.adb");
pragma Suppress (Overflow_Check);

package body ada_main is

   E05 : Short_Integer; pragma Import (Ada, E05, "ada__real_time_E");


   procedure adainit is
   begin
      null;

      Ada.Real_Time'Elab_Body;
      E05 := E05 + 1;
   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_jtag_test");

   procedure main is
      Ensure_Reference : aliased System.Address := Ada_Main_Program_Name'Address;
      pragma Volatile (Ensure_Reference);

   begin
      adainit;
      Ada_Main_Program;
   end;

--  BEGIN Object file/option list
   --   /home/cwitkemper/Adacore-FPGA-Programmer/JTAG_Test/obj/development/stm32f0x0.o
   --   /home/cwitkemper/Adacore-FPGA-Programmer/JTAG_Test/obj/development/stm32f0x0-gpio.o
   --   /home/cwitkemper/Adacore-FPGA-Programmer/JTAG_Test/obj/development/stm32f0x0-rcc.o
   --   /home/cwitkemper/Adacore-FPGA-Programmer/JTAG_Test/obj/development/jtag_test.o
   --   -L/home/cwitkemper/Adacore-FPGA-Programmer/JTAG_Test/obj/development/
   --   -L/home/cwitkemper/Adacore-FPGA-Programmer/JTAG_Test/obj/development/
   --   -L/home/cwitkemper/snap/code/220/.local/share/alire/builds/light_tasking_stm32f0xx_15.0.0_d14cebc3/6017b4eeb699983dff649c9da62ebbb03009e74f5cc58a09b5b4efad1435cf46/adalib/
   --   -static
   --   -lgnarl
   --   -lgnat
--  END Object file/option list   

end ada_main;
