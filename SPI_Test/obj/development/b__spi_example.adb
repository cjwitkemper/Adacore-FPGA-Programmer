pragma Warnings (Off);
pragma Ada_95;
pragma Source_File_Name (ada_main, Spec_File_Name => "b__spi_example.ads");
pragma Source_File_Name (ada_main, Body_File_Name => "b__spi_example.adb");
pragma Suppress (Overflow_Check);

package body ada_main is



   procedure adainit is
   begin
      null;

   end adainit;

   procedure Ada_Main_Program;
   pragma Import (Ada, Ada_Main_Program, "_ada_spi_master_example");

   procedure main is
      Ensure_Reference : aliased System.Address := Ada_Main_Program_Name'Address;
      pragma Volatile (Ensure_Reference);

   begin
      adainit;
      Ada_Main_Program;
   end;

--  BEGIN Object file/option list
   --   /home/cwitkemper/Adacore-FPGA-Programmer/SPI_Test/obj/development/spi_example.o
   --   -L/home/cwitkemper/Adacore-FPGA-Programmer/SPI_Test/obj/development/
   --   -L/home/cwitkemper/Adacore-FPGA-Programmer/SPI_Test/obj/development/
   --   -L/home/cwitkemper/snap/code/209/.local/share/alire/builds/light_tasking_stm32f0xx_15.0.0_d14cebc3/6017b4eeb699983dff649c9da62ebbb03009e74f5cc58a09b5b4efad1435cf46/adalib/
   --   -static
   --   -lgnat
--  END Object file/option list   

end ada_main;
