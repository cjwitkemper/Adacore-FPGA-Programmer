with utils; use utils;
package mcu_to_fpga is
   procedure Init_Configuration;
   procedure Read_IDCODE;
   procedure Reset_TAP;
   procedure Send_Command (c : Bit_Array);
   procedure Read_TDO;
   procedure Send_Configuration_Bitstream;
   procedure Send_Firmware;
end mcu_to_fpga;
