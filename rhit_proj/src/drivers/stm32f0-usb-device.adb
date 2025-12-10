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

package body Stm32f0x0.USB_Device is

   function Create return STM32F0_UDC is
      UDC : STM32F0_UDC;
   begin
      return UDC;
   end Create;

   overriding --Initialize
   -------------------------------------------------------------------------------
--  Initialize
--
--  Initializes the STM32F0 USB Device Controller (UDC). This procedure:
--
--    * Enables the GPIO clocks for the USB DM/DP pins (PA11/PA12)
--    * Configures the USB pins as floating inputs
--    * Performs a USB peripheral reset through APB1
--    * Powers up the USB transceiver block
--    * Clears the entire USB Packet Memory (1 KB PMA)
--    * Resets all USB interrupt status registers
--    * Enables USB reset, suspend, wakeup, and transfer interrupts
--    * Sets the BTABLE pointer to the start of packet memory
--    * Enables the D+ pull-up to signal Full-Speed device connection
--
--  Parameters:
--    This : in out UDC
--       The USB Device Controller instance being initialized. Internal hardware
--       registers and packet memory associated with this instance are reset and
--       prepared for subsequent endpoint configuration and USB enumeration.
--
--  This procedure must be called before configuring endpoints or enabling USB
--  classes. It prepares the hardware but does not configure individual
--  endpoints.
-------------------------------------------------------------------------------

   procedure Initialize (This : in out UDC) is
      DM_Pin : constant GPIO_Point := PA11;
      DP_Pin : constant GPIO_Point := PA12;
      use System.Storage_Elements;
   begin
      Init_Serialtrace; -- DEBUG

      --  StartLog ("> Initialize");

      Enable_Clock (DM_Pin & DP_Pin);

      Configure_IO (DM_Pin & DP_Pin, (Mode => Mode_In, Resistors => Floating));

      --  Should be UBSEN but SVD is wrong. Should fix it.
      RCC_Periph.APB1ENR.USBRST := True;

      RCC_Periph.APB1RSTR.USBRST := True;
      RCC_Periph.APB1RSTR.USBRST := False;

      Delay_Cycles (72);
      -- wait a bit

      USB_Periph.CNTR.PDWN := False;
      Delay_Cycles (72);

      for M in 0 .. 1023 loop
         declare
            Packet_Memory : UInt8
            with Address => Packet_Buffer_Base + Packet_Buffer_Offset (M);
         begin
            Packet_Memory := 0;
         end;
      end loop;

      Reset_ISTR;

      USB_Periph.CNTR :=
        (RESETM         => True,
         SUSPM          => True,
         WKUPM          => True,
         CTRM           => True,
         Reserved_6_6   => 0,
         Reserved_16_31 => 0,
         others         => False);

      --  Clear FRES. When set, RESET is forced and EP*R registers will be
      --  mostly forced to their reset state.
      -- USB_Periph.CNTR := (USB_Periph.CNTR with delta
      --                     FRES => False);

      --  Btable points to start of Packet Memory.

      --  First 64 bytes of PM are used for storing 4*16-bits * 8 EP descriptors
      --  (BTABLE)
      USB_Periph.BTABLE.BTABLE := 0;

      --  Enable Pull Up for Full Speed
      USB_Periph.BCDR.DPPU := True;

   --      EndLog ("< Initialize");
   end Initialize;

   overriding --Request_Buffer
   -------------------------------------------------------------------------------
--  Request_Buffer
--
--  Allocates and returns a CPU-accessible buffer for the specified USB
--  endpoint direction (IN or OUT). This procedure:
--
--    * Allocates the endpoint's hardware-facing PMA buffer within the USB
--      Packet Memory (via Allocate_Endpoint_Buffer)
--    * Allocates a corresponding MCU-facing RAM buffer used by the USB class
--      or application to read/write packet data
--    * Records the allocated buffer address and size in the endpoint status
--      structure, storing Tx_* fields for EP_In or Rx_* fields for EP_Out
--
--  Parameters:
--    This : in out UDC
--       The USB Device Controller instance managing PMA and RAM buffer
--       allocations.
--
--    Ep : EP_Addr
--       The endpoint address (number and direction) for which the buffer is
--       being allocated.
--
--    Len : USB.Packet_Size
--       Size in bytes of both the MCU-facing buffer and the PMA hardware
--       buffer.
--
--  Returns:
--    System.Address
--       The address of the allocated MCU-facing RAM buffer that the caller may
--       use for reading or writing endpoint data.
--
--  Notes:
--    This routine allocates both sides of the endpoint buffer pairing:
--    hardware (PMA) and software (RAM). It must be called before endpoint
--    transfers occur.
-------------------------------------------------------------------------------

   function Request_Buffer
     (This : in out UDC; Ep : EP_Addr; Len : USB.Packet_Size)
      return System.Address
   is
      Mcu_Facing_Mem : System.Address;
   begin
      --      StartLog ("> Request buffer "
      --                & Ep.Num'Image & ", Dir " & Ep.Dir'Image & " Len: " & Len'Image);

      --  Init hw & allocate in packet memory
      This.Allocate_Endpoint_Buffer (Ep, Len);

      Mcu_Facing_Mem :=
        Standard.USB.Utils.Allocate (This.Alloc, Alignment => 4, Len => Len);

      case Ep.Dir is
         when EP_In  =>
            This.EP_Status (Ep.Num).Tx_User_Buffer_Address := Mcu_Facing_Mem;
            This.EP_Status (Ep.Num).Tx_User_Buffer_Len := Len;

         when EP_Out =>
            This.EP_Status (Ep.Num).Rx_User_Buffer_Address := Mcu_Facing_Mem;
            This.EP_Status (Ep.Num).Rx_User_Buffer_Len := Len;
      end case;

      --      EndLog ("< Request buffer");

      return Mcu_Facing_Mem;
   end Request_Buffer;

   overriding --Valid_EP_Id
   -------------------------------------------------------------------------------
--  Valid_EP_Id
--
--  Returns True if the provided endpoint identifier is within the valid range
--  supported by this USB Device Controller instance. Endpoint IDs are expected
--  to be indexed from 0 up to Num_Endpoints - 1.
--
--  Parameters:
--    This : in out UDC
--       The USB Device Controller instance whose endpoint configuration limits
--       are being checked.
--
--    EP : EP_Id
--       The endpoint identifier to validate.
--
--  Returns:
--    Boolean
--       True if EP falls within the valid endpoint index range, False otherwise.
--
--  Notes:
--    This performs a simple bounds check; it does not verify that the
--    endpoint is configured or enabled, only that its numeric ID is legal.
-------------------------------------------------------------------------------

   function Valid_EP_Id (This : in out UDC; EP : EP_Id) return Boolean is
   begin
      return Positive (EP) in 0 .. Num_Endpoints - 1;
   end Valid_EP_Id;

   overriding --Start
   -------------------------------------------------------------------------------
--  Start
--
--  Transitions the USB Device Controller into the operational state after it
--  has been initialized. This procedure:
--
--    * Clears the USB reset condition (FRES)
--    * Enables key USB interrupts (RESETM, SUSPM, WKUPM, CTRM)
--    * Clears any pending interrupt status flags
--    * Resets the BTABLE pointer to the beginning of Packet Memory
--    * Enables the D+ pull-up resistor to signal Full-Speed presence to the host
--
--  Parameters:
--    This : in out UDC
--       The USB Device Controller instance being started.
--
--  Notes:
--    This routine must be called after Initialize and after endpoint
--    descriptors have been prepared. It effectively makes the device visible
--    to the USB host and allows enumeration to begin.
-------------------------------------------------------------------------------

   procedure Start (This : in out UDC) is
   begin
      --      StartLog ("> Start");

      USB_Periph.CNTR :=
        (USB_Periph.CNTR
         with delta
           FRES   => False,
           RESETM => True,
           SUSPM  => True,
           WKUPM  => True,
           CTRM   => True);
      Reset_ISTR;

      --  Btable points to start of Packet Memory.
      --  First 64 bytes of PM are used for storing 4*16-bits * 8 EP
      --  descriptors.
      USB_Periph.BTABLE.BTABLE := 0;

      --  Enable Pull Up for Full Speed
      USB_Periph.BCDR.DPPU := True;

   --      EndLog ("< Start");
   end Start;

   overriding --Reset
   -------------------------------------------------------------------------------
--  Reset
--
--  Resets the USB Device Controller state after a USB bus reset event. This
--  procedure:
--
--    * Clears and reinitializes all endpoint registers except endpoint 0
--      (the control endpoint, which the hardware configures automatically
--       during reset)
--    * Forces all non-control endpoints into a disabled state by resetting
--      their TX/RX status fields
--    * Resets the internal buffer allocator state, preserving only the control
--      endpoint's reserved buffers (BTABLE + EP0 RX/TX areas)
--
--  Parameters:
--    This : in out UDC
--       The USB Device Controller instance whose endpoints and buffer allocator
--       are being reset.
--
--  Notes:
--    This should be called when a USB reset interrupt occurs. It does not
--    configure endpoint 0; hardware does that as part of the USB reset
--    sequence. All other endpoints must be reconfigured by higher-level
--    class or device code after this procedure runs.
-------------------------------------------------------------------------------

   procedure Reset (This : in out UDC) is
   begin
      --      StartLog ("> Reset");
      ----      Log ("Disabling RX/TX for all EP > 0 (1..8)");

      --  Reset ALL Endpoint except for 0 (control)
      --  EP 0 should be setup by controller when doing reset.
      for Ep in EPR_Registers'First + 1 .. EPR_Registers'Last loop
         declare
            UPR : EPR_Register renames EPRS (Ep);
            Cur : constant EPR_Register := UPR;
         begin
            EPRS (Ep) :=
              (Get_EPR_With_Invariant (Cur)
               with delta
                 STAT_RX => Cur.STAT_RX xor 0,
                 STAT_TX => Cur.STAT_TX xor 0);
         end;
      end loop;

      --      Log ("Reseting allocator state");
      --  Deallocate all buffer except for Control
      --  HACK: should be done elsewhere. 64 bytes for Btable, 64 bytes for RX,
      --  64 bytes for TX.

      This.Next_Buffer :=
        System.Storage_Elements.Storage_Offset (Num_Endpoints * 8 + 128);

   --      EndLog ("< Reset");
   end Reset;

   overriding --Poll
   -------------------------------------------------------------------------------
--  Poll
--
--  Processes pending USB interrupt events and returns a UDC_Event describing
--  what occurred. This procedure inspects the USB ISTR register and handles:
--
--    * RESET events — clears the flag and reports a Device.Reset event
--    * WAKEUP events — clears the flag and resumes from suspend
--    * SUSPEND events — clears the flag
--    * CTR (Correct Transfer) events:
--        - SETUP packets on EP0
--        - OUT (RX) transfers, copying data from PMA to user buffer
--        - IN  (TX) transfers, acknowledging completion
--
--  Parameters:
--    This : in out UDC
--       The USB Device Controller instance to poll.
--
--  Returns:
--    UDC_Event
--       A description of the USB event that occurred, or No_Event if none.
--
--  Notes:
--    Must be called regularly by the USB device driver task. This routine
--    fully acknowledges IRQ flags in hardware.
-------------------------------------------------------------------------------

   function Poll (This : in out UDC) return UDC_Event is
      --  Neutral ISTR register values
      Neutral_Istr : constant ISTR_Register :=
        (EP_ID => 0, Reserved_5_6 => 0, Reserved_16_31 => 0, others => True);
      Istr         : ISTR_Register renames USB_Periph.ISTR;
      Cur_Istr     : constant ISTR_Register := Istr;
   begin
      if Cur_Istr.RESET then
         --  Clear RESET by writing 0. Writing 1 in other fields leave them unchanged.
         Startlog ("## Reset");
         --         Log ("!! Reset RECEIVED");
         --         Log ("ISTR: " & Istr_Image (Cur_Istr));

         -- This.Reset_EP_Status;

         Istr :=
           (Neutral_Istr with delta RESET => False --  Clear
           );

         --         EndLog("## return RESET to controller");
         --  This.Reset;
         return (Kind => USB.HAL.Device.Reset);

      elsif Cur_Istr.WKUP then
         --  See rm0091 p871

         --  Clear WKUP by writing 0. Writing 1 in other fields leave them unchanged.
         Istr :=
           (Neutral_Istr with delta WKUP => False --  Clear
           );
         USB_Periph.CNTR.FSUSP := False;

      elsif Cur_Istr.SUSP then
         --  Clear SUSP by writing 0. Writing 1 in other fields leave them unchanged.
         Istr :=
           (Neutral_Istr with delta SUSP => False  -- Clear
           );

      elsif Cur_Istr.CTR then
         declare
            EP_Id        : constant UInt4 := Istr.EP_ID;
            EP_Data_Size : UInt10;
         begin
            Startlog ("## CTR", 2);
            --            Log ("Poll " & Istr_Image (Cur_Istr), 2);
            --            Log ("EPR: " & EPR_Image (EPRS(EP_Id)), 2);

            if EPRS (EP_Id).CTR_RX then
               if EPRS (EP_Id).SETUP then
                  --                  Log ("EPR (clr): " & EPR_Image (EPRS(EP_Id)), 2);
                  declare
                     Req : Setup_Data;
                  begin
                     HalfWord_Copy
                       (Req'Address,
                        This.Endpoint_Buffer_Address ((EP_Id, EP_Out)),
                        Natural (Req'Size));
                     --                     Log (" --> SETUP " & Setup_Data_Image (Req), 2, -1);
                     ----                     Endlog("## return Setup_Request");

                     Clear_Ctr_Rx (EP_Id);  --  ACK the reception

                     return
                       (Kind   => Setup_Request,
                        Req    => Req,
                        Req_Ep => Ep_Id); --  Always EP 0
                  end;
               else

                  -- OUT transaction, RX from device PoV
                  -- Need to copy DATA from EP buffer to app buffer.
                  EP_Data_Size := Btable (Ep_Id).COUNT_RX.COUNTN_RX;
                  Copy_Endpoint_Rx_Buffer (This, EP_Id);

                  Clear_Ctr_Rx (EP_Id);  --  ACK the reception

                  ----                  Log (" --> TRANSFER OUT/RX OK", 2);
                  --                  Endlog("## return Transfer_Complete");
                  return
                    (Kind => Transfer_Complete,
                     EP   => (EP_Id, EP_Out),
                     BCNT => USB.Packet_Size (EP_Data_Size));
               end if;
            end if;

            if not EPRS (EP_Id).CTR_TX then
               raise Program_Error with "CTR_TX should be set";
            end if;

            --  If we are here, then CTR_TX must be set.

            --  IN transaction, TX from device PoV
            --  Only need to ACK and report back the number of bytes sent.

            EP_Data_Size := Btable (Ep_Id).COUNT_TX.COUNTN_TX;

            Clear_Ctr_Tx (EP_Id);  -- ACK the transmission
            --            Log (" --> TRANSFER IN/TX OK (" & EP_Data_Size'Image & ")");
            --            Endlog ("## return Transfer_Complete");
            return
              (Kind => Transfer_Complete,
               EP   => (EP_Id, EP_In),
               BCNT => USB.Packet_Size (EP_Data_Size));
         end;
      end if;
      return No_Event;
   end Poll;

   overriding --EP_Send_Packet
   -------------------------------------------------------------------------------
--  EP_Send_Packet
--
--  Sends data on an IN endpoint. This routine:
--
--    * Copies a user-provided buffer into the endpoint’s PMA TX buffer
--    * Writes the packet length into the BTABLE entry
--    * Sets STAT_TX to VALID, signaling hardware to send the data
--
--  Parameters:
--    This : in out UDC
--       USB Device Controller instance managing endpoint PMA buffers.
--
--    Ep : EP_Id
--       The endpoint number to transmit on (must be an IN endpoint).
--
--    Len : USB.Packet_Size
--       Size in bytes of the packet to transmit.
--
--  Notes:
--    Raises Program_Error if the endpoint is already in VALID TX state,
--    indicating a blocked/non-completed previous transmission.
-------------------------------------------------------------------------------

   procedure EP_Send_Packet
     (This : in out UDC; Ep : EP_Id; Len : USB.Packet_Size)
   is
      Src_User_Buffer : constant System.Address :=
        This.EP_Status (Ep).Tx_User_Buffer_Address;

      UPR : EPR_Register renames EPRS (Ep);
      Cur : constant EPR_Register := UPR;
   begin
      --      StartLog ("> EP_Send_Packet " & Ep'Image, 3);

      --  If VALID (3), there must be a pending write...
      --  Better panic than do garbage
      if Cur.STAT_TX = 3 then
         raise Program_Error with "Would block";
      end if;

      HalfWord_Copy
        (This.Endpoint_Buffer_Address ((Ep, USB.EP_In)),
         Src_User_Buffer,
         Natural (Len));

      Btable (Ep).COUNT_TX.COUNTN_TX := UInt10 (Len);

      --  Set STAT_TX to VALID
      UPR :=
        (Get_EPR_With_Invariant (Cur) with delta STAT_TX => Cur.STAT_TX xor 3);

   --      EndLog ("< EP_Send_Packet", 3);
   end EP_Send_Packet;

   overriding --EP_Setup
   -------------------------------------------------------------------------------
--  EP_Setup
--
--  Configures the hardware registers and PMA buffer descriptors for a USB
--  endpoint. This includes:
--
--    * Writing the BTABLE RX/TX addresses and buffer layout
--    * Setting endpoint type (Control, Bulk, Interrupt, Isochronous)
--    * Initializing DTOG bits, NAK state, and clearing CTR flags
--    * Storing endpoint type and validity in EP_Status
--
--  Parameters:
--    This : in out UDC
--       The controller instance managing endpoint configuration.
--
--    EP : EP_Addr
--       Endpoint number + direction (IN or OUT).
--
--    Typ : EP_Type
--       USB endpoint transfer type.
--
--  Notes:
--    Must be called after Request_Buffer and before enabling traffic.
-------------------------------------------------------------------------------

   procedure EP_Setup (This : in out UDC; EP : EP_Addr; Typ : EP_Type) is
      UPR : EPR_Register renames EPRS (Ep.Num);

      type EP_Type_Mapping_T is array (EP_Type) of UInt2;
      EPM : constant EP_Type_Mapping_T :=
        [Bulk => 0, Control => 1, Isochronous => 2, Interrupt => 3];

      type EP_Type_Mapping_T2 is array (EP_Type) of String (1 .. 4);
      EPM2 : constant EP_Type_Mapping_T2 :=
        [Bulk        => "BULK",
         Control     => "CTRL",
         Isochronous => "ISO ",
         Interrupt   => "INT "];

      Cur : constant EPR_Register := UPR;
      Tmp : EPR_Register;
   begin
      --      StartLog ("> EP_Setup " & EP.Num'Image & ", "
      --  & (if EP.Dir = EP_In then "IN" else "OUT")
      --  & " Typ: " & EPM2(Typ));

      if Ep.Num > Num_Endpoints then
         raise Program_Error with "Invalid endpoint number";
      end if;

      --  Write BTABLE entry
      case Ep.Dir is
         when EP_In  =>
            Btable (Ep.Num).ADDR_TX :=
              ((ADDRN_TX =>
                  UInt16 (This.EP_Status (Ep.Num).Tx_Buffer_Offset)));
            Btable (Ep.Num).COUNT_TX.COUNTN_TX := 0;

         when EP_Out =>
            Btable (Ep.Num).ADDR_RX :=
              (ADDRN_RX => UInt16 (This.EP_Status (Ep.Num).Rx_Buffer_Offset));

            Btable (Ep.Num).COUNT_RX :=
              (BL_SIZE   =>
                 Bit (if This.EP_Status (Ep.Num).Rx_Use_32b then 1 else 0),
               NUM_BLOCK => UInt5 (This.EP_Status (Ep.Num).Rx_Num_Blocks),
               others    => 0);
      end case;

      This.EP_Status (EP.Num).Typ := Typ;
      This.EP_Status (EP.Num).Valid := True;

      --      Log("EPR      : " & EPR_Image(UPR));
      Tmp :=
        (Get_EPR_With_Invariant (Cur)
         with delta

           DTOG_TX =>
             (if EP.Dir = EP_In then False xor Cur.DTOG_TX else False),
           DTOG_RX =>
             (if EP.Dir = EP_Out then False xor Cur.DTOG_RX else False),
           CTR_RX  => False,
           CTR_TX  => False,
           EP_KIND => False,
           EA      => EP.Num,
           EP_TYPE => EPM (Typ),

           -- NAK RX/TX for corresponding Direction
           STAT_TX => (if EP.Dir = EP_In then Cur.STAT_TX xor 2 else 0),
           STAT_RX => (if EP.Dir = EP_Out then Cur.STAT_RX xor 2 else 0));
      --      Log("Tmp      : " & EPR_Image(Tmp));
      UPR := Tmp;

   --      Log("EPR (set): " & EPR_Image(UPR));

   --      Log("btable: addr_rx" & Btable(Ep.Num).ADDR_RX.ADDRN_RX'Image &
   --  " count_rx: " & Btable(Ep.Num).COUNT_RX.COUNTN_RX'Image &
   --  " bl: " & Btable(Ep.Num).COUNT_RX.BL_SIZE'Image &
   --  " nb: " & Btable(Ep.Num).COUNT_RX.NUM_BLOCK'Image &
   --  " addr_tx: " & Btable(Ep.Num).ADDR_TX.ADDRN_TX'Image &
   --  " count_tx: " & Btable(Ep.Num).COUNT_TX.COUNTN_TX'Image);

   --      EndLog ("< EP_Setup");
   end EP_Setup;

   overriding --EP_Ready_For_Data
   -------------------------------------------------------------------------------
--  EP_Ready_For_Data
--
--  Marks an OUT endpoint as ready (or not ready) to receive data. This sets:
--
--    * STAT_RX = VALID (0b11) when Ready = True
--    * STAT_RX = NAK   (0b10) when Ready = False
--
--  Parameters:
--    This  : in out UDC
--       USB Device Controller instance.
--
--    EP    : EP_Id
--       OUT endpoint number to modify.
--
--    Size  : USB.Packet_Size
--       Unused here; kept for compatibility with generic HAL interface.
--
--    Ready : Boolean := True
--       Whether to accept incoming packets or temporarily NAK them.
--
--  Notes:
--    If the endpoint is already VALID, no changes occur.
-------------------------------------------------------------------------------

   procedure EP_Ready_For_Data
     (This  : in out UDC;
      EP    : EP_Id;
      Size  : USB.Packet_Size;
      Ready : Boolean := True)
   is
      UPR : EPR_Register renames EPRS (Ep);
      Cur : constant EPR_Register := UPR;
   begin
      --      StartLog ("> EP_Ready_For_Data " & EP'Image
      --                  & " len: " & Size'Image & " ready: " & Ready'Image, 2);

      --      Log ("EPR      : " & EPR_Image(UPR));

      --  nothing ready, still waiting
      if Cur.STAT_RX = 3 then
         --         EndLog ("< EP_Ready_For_Data (EP already ready to receive data)", 2);
         return;
      end if;

      if Ready then
         --  Set STAT_RX to VALID (0b11) to enable data reception.
         UPR :=
           (Get_EPR_With_Invariant (Cur)
            with delta STAT_RX => Cur.STAT_RX xor 3);
      else
         --  Set to NAK if not ready (why is it needed??)
         UPR :=
           (Get_EPR_With_Invariant (Cur)
            with delta STAT_RX => Cur.STAT_RX xor 2);
      end if;

   --      Log ("EPR (set): " & EPR_Image(UPR));
   --      EndLog ("< EP_Ready_For_Data", 2);
   end EP_Ready_For_Data;

   overriding --EP_Stall
   -------------------------------------------------------------------------------
--  EP_Stall
--
--  Asserts or clears a STALL condition on an endpoint. This procedure:
--
--    * Sets STAT_TX or STAT_RX to STALL (1) depending on direction
--    * When clearing a stall, resets DTOG bits for data toggle resynchronization
--
--  Parameters:
--    This : in out UDC
--       USB Device Controller instance.
--
--    EP : EP_Addr
--       Endpoint number + direction.
--
--    Set : Boolean := True
--       True to enter STALL, False to exit STALL.
--
--  Notes:
--    Required for handling control request errors and class-specific stalls.
-------------------------------------------------------------------------------

   procedure EP_Stall (This : in out UDC; EP : EP_Addr; Set : Boolean := True)
   is
      UPR : EPR_Register renames EPRS (Ep.Num);
      Cur : constant EPR_Register := UPR;
      V   : constant UInt2 := (if Set then 1 else 2);
   begin
      --      StartLog ("> EP_Stall " & EP.Num'Image & " set: " & Set'Image);

      case Ep.Dir is
         when USB.EP_In  =>
            UPR :=
              (Get_EPR_With_Invariant (Cur)
               with delta STAT_TX => Cur.STAT_TX xor V);

            if not Set then
               UPR :=
                 (Get_EPR_With_Invariant (Cur)
                  with delta DTOG_TX => False xor Cur.DTOG_TX);
            end if;

         when USB.EP_Out =>
            UPR :=
              (Get_EPR_With_Invariant (Cur)
               with delta STAT_RX => Cur.STAT_RX xor V);
            if not Set then
               UPR :=
                 (Get_EPR_With_Invariant (Cur)
                  with delta DTOG_RX => False xor Cur.DTOG_RX);
            end if;
      end case;
   --      EndLog ("< EP_Stall");
   end EP_Stall;

   overriding --Set_Address
   -------------------------------------------------------------------------------
--  Set_Address
--
--  Writes the USB device address to the DADDR register and enables it.
--
--  Parameters:
--    This : in out UDC
--       Controller instance.
--
--    Addr : HAL.UInt7
--       7-bit USB device address assigned by the host.
--
--  Notes:
--    Executed at the correct stage of a SET_ADDRESS control request. Hardware
--    takes effect only after the status stage completes.
-------------------------------------------------------------------------------

   procedure Set_Address (This : in out UDC; Addr : HAL.UInt7) is
   begin
      --      StartLog ("> Set_Address " & Addr'Image);

      USB_Periph.DADDR.ADD := Addr;
      USB_Periph.DADDR.EF := True;
   --      EndLog ("< Set_Address");
   end Set_Address;

   overriding --Early_Address
   -------------------------------------------------------------------------------
--  Early_Address
--
--  Indicates whether the device applies the newly assigned address before the
--  status stage of SET_ADDRESS. STM32F0 USB requires late address commit,
--  so this always returns False.
--
--  Parameters:
--    This : UDC
--       The controller instance (not modified).
--
--  Returns:
--    Boolean
--       Always False.
-------------------------------------------------------------------------------

   function Early_Address (This : UDC) return Boolean is
   begin
      return False;
   end Early_Address;
 
   -------------------------------------------------------------------------------
--  Send_Would_Block
--
--  Determines whether an IN endpoint is currently busy sending data. This
--  returns True if STAT_TX = VALID (0b11), indicating the PMA buffer has not
--  yet been consumed by hardware.
--
--  Parameters:
--    This : UDC
--       Controller instance.
--
--    Ep : EP_Id
--       Endpoint number to check.
--
--  Returns:
--    Boolean
--       True if sending would block; False if a new packet may be queued.
-------------------------------------------------------------------------------
   function Send_Would_Block (This : UDC; Ep : EP_Id) return Boolean is
      UPR : EPR_Register renames EPRS (Ep);
      Cur : constant EPR_Register := UPR;
   begin
      return Cur.STAT_TX = 3;
   end Send_Would_Block;

------------------------------------------------------------------------------
--  Allocate_Buffer
--
--  Allocates a region of Packet Memory (PMA) with 16-byte alignment, returning
--  the offset from the base PMA address. This is used for endpoint RX/TX buffer
--  assignment.
--
--  Parameters:
--    This : in out UDC
--       Controller instance tracking the next free PMA offset.
--
--    Size : Natural
--       Requested PMA buffer size in bytes.
--
--  Returns:
--    Packet_Buffer_Offset
--       The aligned PMA offset allocated for this endpoint buffer.
--
--  Notes:
--    This updates Next_Buffer and ensures 16-byte alignment required by ST’s PMA.
-------------------------------------------------------------------------------

   function Allocate_Buffer
     (This : in out UDC; Size : Natural) return Packet_Buffer_Offset
   is
      use System.Storage_Elements;
      Addr  : Packet_Buffer_Offset := This.Next_Buffer;
      A     : constant Natural := Natural (Addr) mod 16;
      Extra : constant Natural := 16 - A;
   begin
      if A /= 0 then
         Addr := Addr + Storage_Offset (Extra);
      end if;

      This.Next_Buffer :=
        This.Next_Buffer + Storage_Offset (Extra) + Storage_Offset (Size);
      return Addr;
   end Allocate_Buffer;
end Stm32f0x0.USB_Device;
