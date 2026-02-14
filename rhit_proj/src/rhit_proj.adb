with Interfaces; use Interfaces;
with STM32F0x0; use STM32F0x0;
with STM32F0x0.RCC; use STM32F0x0.RCC;
with STM32F0x0.GPIO; use STM32F0x0.GPIO;

procedure Rhit_Proj is

   --  Initializes Hardware
   procedure Initialize_Hardware is
   begin
      null;
   end Initialize_Hardware;

   --  Sequence before sending bitstream to FPGA
   procedure Initialize_FPGA is
   begin
      null;
   end Initialize_FPGA;

   procedure Receive_File is
   begin
      null;
   end Receive_File;

--  Main
begin
   Initialize_Hardware;
   Initialize_FPGA;
   Receive_File;
   loop
      null;
   end loop;
end Rhit_Proj;
