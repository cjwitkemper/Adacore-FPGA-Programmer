with STM32F0_USB_Device;
with USB.Device.Serial;
with USB;
with Ada.Real_Time; use Ada.Real_Time;

procedure Rhit_Proj is

   --  Create UDC instance
   UDC : aliased STM32F0_USB_Device.STM32F0_UDC := STM32F0_USB_Device.Create;

   --  Create CDC Serial class
   Serial :
     aliased USB.Device.Serial.Default_Serial_Class
               (TX_Buffer_Size => 128, RX_Buffer_Size => 128);

   --  Create USB stack
   Stack : USB.Device.USB_Device_Stack := ; -- ??????? TODO ???????????????

   --  Initialization result
   Init_Result : USB.Device.Init_Result;

begin
   --  Initialize the UDC hardware
   UDC.Initialize;

   --  Register the Serial class with the stack
   Stack.Register_Class (Serial'Access);

   --  Initialize the USB stack              !!!!!! TODO VERIFY STACK
   Init_Result :=
     Stack.Initialize
       (Controller   => UDC'Access,
        Manufacturer => USB.To_USB_String ("YourCompany"),
        Product      => USB.To_USB_String ("STM32F0 CDC Device"),
        Serial       => USB.To_USB_String ("123456"),
        Max_Packet   => 64);

   if Init_Result /= USB.Device.Ok then
      --  Handle initialization error
      --  Maybe blink an LED or something
      loopdevice
         null;
      end loop;
   end if;

   --  Start the USB stack
   Stack.Start;

   --  Main loop
   loop
      --  Poll the USB stack (this calls your UDC.Poll internally)
      Stack.Poll;

      --  Check if we have data available to read
      if Serial.Available > 0 then
         declare
            Data : USB.Byte_Array (1 .. Serial.Available);
            Last : Natural;
         begin
            --  Read data from host
            Serial.Read (Data, Last);

            if Last > 0 then
               --  Echo it back
               Serial.Write (Data (1 .. Last));
            end if;
         end;
      end if;

      --  Small delay (1ms) Could mess with timing
      delay 0.001;
   end loop;
end Rhit_Proj;
