-------------------------------------------------------------------------------
--                                                                           --
--                              STM32F0 USB                                  --
--                                                                           --
--                  Copyright (C) 2022      Marc PoulhiÃ¨s                    --
--                                                                           --
--    STM32F0 USB is free software: you can redistribute it and/or           --
--    modify it under the terms of the GNU General Public License as         --
--    published by the Free Software Foundation, either version 3 of the     --
--    License, or (at your option) any later version.                        --
--                                                                           --
--    STM32F0 USB is distributed in the hope that it will be useful,         --
--    but WITHOUT ANY WARRANTY; without even the implied warranty of         --
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU       --
--    General Public License for more details.                               --
--                                                                           --
--    You should have received a copy of the GNU General Public License      --
--    along with STM32F0 USB. If not, see <http://www.gnu.org/licenses/>.    --
--                                                                           --
-------------------------------------------------------------------------------
--
--  SPDX-License-Identifier: GPL-3.0-or-later

-------------------------------------------------------------------------------
with USB.HAL.Device;
with USB;
with HAL;
with System;

package STM32F0_USB_Device is

   type STM32F0_UDC is new USB.HAL.Device.USB_Device_Controller with private;

   -- Create a UDC instance
   function Create return STM32F0_UDC;

private

   -- Import your existing USB types and state
   type EP_Status is record
      Tx_Buffer_Offset        : System.Storage_Elements.Storage_Offset := 0;
      Rx_Buffer_Offset        : System.Storage_Elements.Storage_Offset := 0;
      Tx_User_Buffer_Address  : System.Address := System.Null_Address;
      Rx_User_Buffer_Address  : System.Address := System.Null_Address;
      Tx_User_Buffer_Len      : USB.Packet_Size := 0;
      Rx_User_Buffer_Len      : USB.Packet_Size := 0;
      Rx_Use_32b              : Boolean := False;
      Rx_Num_Blocks           : Natural := 0;
      Typ                     : USB.EP_Type := USB.Control;
      Valid                   : Boolean := False;
   end record;

   type EP_Status_Array is array (USB.EP_Id range 0 .. 7) of EP_Status;

   type STM32F0_UDC is new USB.HAL.Device.USB_Device_Controller with record
      EP_Status       : EP_Status_Array;
      Next_Buffer     : System.Storage_Elements.Storage_Offset := 0;
      Pending_Address : HAL.UInt7 := 0;
      Address_Pending : Boolean := False;
   end record;

   -- Implement all interface procedures
   overriding
   procedure Initialize (This : in out STM32F0_UDC);

   overriding
   procedure Start (This : in out STM32F0_UDC);

   overriding
   procedure Reset (This : in out STM32F0_UDC);

   overriding
   function Poll (This : in out STM32F0_UDC) return USB.HAL.Device.UDC_Event;

   overriding
   procedure EP_Setup
     (This : in out STM32F0_UDC;
      EP   : USB.EP_Addr;
      Typ  : USB.EP_Type);

   overriding
   procedure EP_Write_Packet
     (This : in out STM32F0_UDC;
      EP   : USB.EP_Addr;
      Len  : USB.Packet_Size);

   overriding
   procedure EP_Ready_For_Data
     (This  : in out STM32F0_UDC;
      EP    : USB.EP_Addr;
      Size  : USB.Packet_Size;
      Ready : Boolean := True);

   overriding
   procedure EP_Stall
     (This : in out STM32F0_UDC;
      EP   : USB.EP_Addr;
      Set  : Boolean := True);

   overriding
   procedure Set_Address
     (This : in out STM32F0_UDC;
      Addr : HAL.UInt7);

   overriding
   function Early_Address (This : STM32F0_UDC) return Boolean;

   overriding
   function Request_Buffer
     (This : in out STM32F0_UDC;
      EP   : USB.EP_Addr;
      Len  : USB.Packet_Size) return System.Address;

   overriding
   function Valid_EP_Id
     (This : in out STM32F0_UDC;
      EP   : USB.EP_Id) return Boolean;

end STM32F0_USB_Device;