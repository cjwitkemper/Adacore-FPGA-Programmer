package mcu_to_fpga is
   

   task M2F;

   procedure Init_Configuration;
   procedure Read_IDCODE;
   procedure Reset_TAP;
   procedure Send_Command (c : Bit_Array);
   procedure Read_TDO;
   function Get_TDO;
   procedure Send_Configuration_Bitstream;
end mcu_to_fpga;