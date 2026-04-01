with STM32.Device;         
with STM32.USB_Device;     use STM32.USB_Device;
with USB.HAL.Device;       use USB.HAL.Device;
with USB;                  use USB;
with USB_Descriptors;      use USB_Descriptors;
with HAL;                  use HAL; 
with System;

procedure Usb_Example is
   Event : UDC_Event;
   
   --  Buffer for receiving the actual file data
   File_Chunk_Buffer : array (0 .. 63) of UInt8 with Alignment => 4;
   
   --  This variable will hold the address returned by the HAL
   --  For this library, we must use the address the HAL gives us
   Actual_Rx_Addr : System.Address;

   procedure Send_Descriptor (Data : System.Address; Len : USB.Packet_Size) is
      --  We use Request_Buffer to tell the HAL where our Descriptor is
      Unused_Addr : System.Address;
   begin
      --  For EP0 In (Sending to PC)
      Unused_Addr := STM32.Device.UDC.Request_Buffer((0, EP_In), Len);
      --  The library requires us to copy data to the buffer it allocated
      --  but for static descriptors, we can often just point to them if the HAL supports it.
      --  To be safe, we use the HAL's Send_Packet logic:
      STM32.Device.UDC.EP_Send_Packet(0, Len);
   end Send_Descriptor;

begin
   --  1. Initialize Peripheral and GPIOs
   STM32.Device.UDC.Initialize;
   
   --  2. Allocate and Setup Endpoints
   --  EP 0: Control (The HAL handles its own internal buffers for EP0 usually)
   Actual_Rx_Addr := STM32.Device.UDC.Request_Buffer((0, EP_In), 64);
   Actual_Rx_Addr := STM32.Device.UDC.Request_Buffer((0, EP_Out), 64);
   STM32.Device.UDC.EP_Setup((0, EP_In), Control);
   STM32.Device.UDC.EP_Setup((0, EP_Out), Control);

   --  EP 1: Bulk OUT (File Receiving)
   --  We call Request_Buffer and the library stores the address internally
   Actual_Rx_Addr := STM32.Device.UDC.Request_Buffer((1, EP_Out), 64);
   --  Note: If your library requires the data to land in YOUR array, 
   --  you would perform a copy inside the Transfer_Complete event.
   
   STM32.Device.UDC.EP_Setup((1, EP_Out), Bulk);

   --  3. Connect to the USB Bus
   STM32.Device.UDC.Start;

   loop
      Event := STM32.Device.UDC.Poll;

      case Event.Kind is
         when Reset =>
            STM32.Device.UDC.EP_Ready_For_Data(0, 64);
            STM32.Device.UDC.EP_Ready_For_Data(1, 64);

         when Setup_Request =>
            if Event.Req.Request = 6 then --  GET_DESCRIPTOR
               declare
                  Desc_Type : constant UInt16 := Event.Req.Value / 256;
               begin
                  if Desc_Type = 1 then 
                     Send_Descriptor(Device_Desc'Address, 18);
                  elsif Desc_Type = 2 then 
                     Send_Descriptor(Config_Desc'Address, Config_Desc'Length);
                  end if;
               end;
            elsif Event.Req.Request = 5 then --  SET_ADDRESS
               STM32.Device.UDC.Set_Address(UInt7(Event.Req.Value and 16#7F#));
               STM32.Device.UDC.EP_Send_Packet(0, 0);
            elsif Event.Req.Request = 11 then --  SET_INTERFACE
               STM32.Device.UDC.EP_Send_Packet(0, 0);
            end if;

         when Transfer_Complete =>
            if Event.EP.Num = 1 and then Event.EP.Dir = EP_Out then
               --  Data is now available at Actual_Rx_Addr.
               --  You can copy it to your File_Chunk_Buffer here:
               --  System.Storage_Elements.To_Pointer(Actual_Rx_Addr)...
               
               --  Re-arm for next chunk
               STM32.Device.UDC.EP_Ready_For_Data(1, 64);
            end if;

         when others =>
            null;
      end case;
   end loop;
end Usb_Example;