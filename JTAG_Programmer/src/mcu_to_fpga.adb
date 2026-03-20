procedure mcu_to_fpga is

     procedure Send_Command (c : Bit_Array) is
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pulse_TCK; -- SELECT-IR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-IR
      Pulse_TCK;
      for I in 0 .. 7 loop
         if c (I) = 1 then
            Pin_High (TDI_Pin);
         else
            Pin_Low (TDI_Pin);
         end if;
         if (I = 7) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit Shift-IR

         end if;
         Pulse_TCK;
         delay 0.0001;
      end loop;
      Pulse_TCK; -- UPDATE-IR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command

   end Send_Command;

   --  CHANGE TO FUNCTION LATER: SHOULD RETURN THE VALUE OF TDO
   procedure Read_TDO is
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-DR
      for I in 0 .. 32 loop
         if (I = 32) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit Shift-DR
         end if;
         Pulse_TCK;
      end loop;
      Pin_High (TMS_PIN);
      Pulse_TCK; -- UPDATE-DR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
   end Read_TDO;

   procedure Init_Configuration is
      cmd : Bit_Array (0 .. 7);
   begin
      
      delay 0.001; -- Delay to get to CONFIGURATION state

      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command to read Status Register (IR=0x41)
      Send_Command (cmd); -- Send a command to the FPGA (0x41 in this case)

      Pin_Low (TMS_PIN);
      for I in 1 .. 10 loop
         Pulse_TCK; -- RUN-TEST/IDLE
      end loop;
      Read_TDO; -- Read the TDO output after sending the command

      cmd := (1, 0, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x15)
      Send_Command (cmd); -- Send the command

      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);

      --  Small Delay
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command

      Read_TDO; -- Read TDO for staus register
      cmd := (1, 0, 1, 0, 0, 0, 0, 0); -- Example command (IR=0x05)
      Send_Command (cmd); -- Send the command
      cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- Example command (IR=0x02)
      Send_Command (cmd);
      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);
      Read_TDO; -- Read TDO for staus register
      cmd := (1, 0, 0, 1, 0, 0, 0, 0); -- Example command (IR=0x09)
      Send_Command (cmd); -- Send the command
      cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- Example command (IR=0x02)
      Send_Command (cmd);
      cmd := (0, 1, 0, 1, 1, 1, 0, 0); -- Example command (IR=0x3A)
      Send_Command (cmd);
      cmd := (0, 1, 0, 0, 0, 0, 0, 0); -- Example command (IR=0x02)
      Send_Command (cmd);

      --  cmd := (0, 0, 1, 1, 1, 1, 0, 0); -- Example command (IR=0x3C)
      --  Send_Command (cmd);
      --  delay 0.015;

      cmd := (1, 0, 0, 0, 0, 0, 1, 0); -- Example command (IR=0x41)
      Send_Command (cmd);
      Read_TDO; -- Read TDO for staus register
      cmd := (1, 0, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x15)
      Send_Command (cmd); -- Send the command
      cmd := (0, 1, 0, 0, 1, 0, 0, 0); -- Example command (IR=0x12)
      Send_Command (cmd);
      cmd := (1, 1, 1, 0, 1, 0, 0, 0); -- Example command (IR=0x17)
      Send_Command (cmd);
   end Init_Configuration;

   function Read_IDCODE return Bit_Array is
      IDCODE : Bit_Array (0 .. 31);
   begin
      Pin_High (TMS_PIN);
      Pulse_TCK; -- SELECT-DR-SCAN
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- CAPTURE-DR
      for I in 0 .. 31 loop
         if (I = 31) then
            Pin_High (TMS_PIN); -- Pull TMS high on the last bit to exit
         end if;
         IDCODE (I) := Get_TDO;
         Pulse_TCK;
      end loop;
      Pin_High (TMS_PIN);
      Pulse_TCK; -- UPDATE-DR
      Pin_Low (TMS_PIN);
      Pulse_TCK; -- RUN-TEST/IDLE
      Pulse_TCK; -- Extra pulse to ensure the FPGA has time to process the command
      return IDCODE;
   end Read_IDCODE;

   procedure Reset_TAP is
   begin
      Pin_High (TMS_PIN);
      for I in 1 .. 6 loop
         Pulse_TCK;
      end loop;
   end Reset_TAP;

   

begin
   null;
end mcu_to_fpga;