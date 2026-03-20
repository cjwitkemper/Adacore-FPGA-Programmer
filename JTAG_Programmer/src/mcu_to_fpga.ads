package mcu_to_fpga is
   procedure Init_Configuration;
   procedure Read_IDCODE;
   procedure Reset_TAP;
   procedure Send_Command (c : Bit_Array);
   procedure Read_TDO;
end mcu_to_fpga;