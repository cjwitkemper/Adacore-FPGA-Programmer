# MSP432 Gowin JTAG Emulator

## Introduction
This project transforms an **MSP432P4111** LaunchPad into a **JTAG Slave Emulator** for the Gowin GW1NR-9 FPGA (Tang Nano 9k).

It is designed to act as a "Referee" to validate an external Master (e.g., custom STM32 hardware bridge, Raspberry Pi Pico) that is attempting to program an FPGA via the **JTAG** protocol. Instead of programming a real FPGA and guessing why it fails, you connect your Master to this MSP432. 

The Emulator validates the Master against both the **IEEE 1149.1 JTAG Standard** and the official **Gowin Programming and Configuration Guide Documentation**, enforcing:
1. **TAP State Compliance:** Strict tracking of the 16-state TAP Controller (Capture, Shift, Update, Exit).
2. **Dynamic Status Polling:** Emulates the Gowin Status Register (`0x41`), forcing the Master to properly poll for "Edit Mode" and "Erase Done" flags before proceeding.
3. **Protocol Sequence:** Verifies the strict `ENABLE` -> `ERASE` -> `ERASE_DONE` -> `INIT` -> `WRITE` command flow.
4. **Bi-Directional Data:** Correctly shifts out the Gowin ID Code (`0x1100481B`) and real-time status matrices on the TDO line.

If your Master driver lights up all 5 progress LEDs on this Emulator, it is certified to work on the real Tang Nano 9k hardware.

## Hardware & Software Used
* **Board:** MSP-EXP432P4111 LaunchPad
* **IDE:** Texas Instruments Code Composer Studio (CCS) **v12.5.0**
* **Protocol:** IEEE 1149.1 JTAG, LSB First shifting for both IR and DR paths.

## Wiring Connections
Connect your JTAG Master (STM32, Pico, etc.) to the MSP432 **Port 5** header.

**⚠️ IMPORTANT:** Ensure both boards share a common **Ground (GND)**.

| Signal | MSP432 Pin | Direction | Description |
| :--- | :--- | :--- | :--- |
| **TCK** | **P5.0** | Input | JTAG Test Clock |
| **TMS** | **P5.1** | Input | Test Mode Select (Drives TAP State Machine) |
| **TDI** | **P5.2** | Input | Test Data In (Commands/Bitstream from Master) |
| **TDO** | **P5.4** | Output | Test Data Out (ID/Status Readback to Master) |

## Visual Diagnostics (Port 4 LEDs)
Connect 6 LEDs to Port 4 (P4.0 - P4.5) to view the "Progress Bar" of the configuration sequence. The logic is sticky; once a milestone is reached, the LED remains on until a TAP Reset.

| LED Pin | Name | Meaning | Progress State |
| :--- | :--- | :--- | :--- |
| **P4.0** | **PROG_1** | **TAP Reset** | **[ON]** Master sent 5+ TMS High clocks. TAP is reset. |
| **P4.1** | **PROG_2** | **ID Checked** | **[ON]** Master successfully read the 32-bit IDCODE from TDO. |
| **P4.2** | **PROG_3** | **Erase Start** | **[ON]** Master sent the `0x05` Erase SRAM command. |
| **P4.3** | **PROG_4** | **Erase Done** | **[ON]** Master sent the `0x09` Erase Done command. |
| **P4.4** | **PROG_5** | **Success** | **[ON]** Bitstream loaded successfully (>100k bits). |
| **P4.5** | **FAIL** | **Error** | **[ON]** Protocol violation (e.g., Write without Erase). |

### The "Progress Bar"
A successful programming sequence will light up the LEDs in order:
1. `[X] [ ] [ ] [ ] [ ]` (Reset)
2. `[X] [X] [ ] [ ] [ ]` (ID Verified)
3. `[X] [X] [X] [ ] [ ]` (Erasing Memory)
4. `[X] [X] [X] [X] [ ]` (Erase Confirmed)
5. `[X] [X] [X] [X] [X]` (Configuration Complete!)

## Indicators & UART
This project uses the **UART Backchannel** (USB to PC) to provide a highly detailed, real-time diagnostic log of the JTAG TAP states and latched commands. 

### UART Setup
* **Baud Rate:** 9600
* **Data Bits:** 8
* **Parity:** None
* **Stop Bits:** 1
* **Terminal:** Use the built-in CCS Terminal, PuTTY, or TeraTerm connected to the LaunchPad's Application/User UART COM port.

### Terminal Output Examples
* `[STATE] JTAG TAP Reset.` -> Master reset the TAP controller.
* `[CMD]   0x41 (READ STATUS) Master is Polling...` -> Master is checking the dynamic hardware flags.
* `[CMD]   0x05 (ERASE SRAM) Latched. Simulating erase...` -> Erase sequence began.
* `[FAIL]  Protocol violation detected.` -> **Error:** Master broke the configuration flow.
* `[PASS]  Bitstream Transmitted! Bits counted: 3555440` -> Configuration successful.

## Critical Operational Notes
1. **IEEE 1149.1 Defaults:** The emulator enforces the standard that the Instruction Register (IR) must automatically default to `IDCODE (0x11)` immediately following a TAP Reset.
2. **Strict Erase Sequence:** Sending the Erase command (`0x05`) is not enough. The Master **must** follow up with the Erase Done command (`0x09`) before attempting to write. If `0x09` is skipped, the emulator will reject the bitstream.
3. **Dynamic Status Polling:** The emulator actively toggles bits in the `0x41` Status Register (like Edit Mode and Erase Active). A compliant Master should implement polling loops rather than blind delays to ensure these bits settle before proceeding.

## Building the Project
1. Import `main.c` into your CCS Workspace.
2. Ensure the Target is set to your specific MSP432 variant.
3. Build (Hammer Icon). 
   * *Note:* Warnings about "Software Delay Loops" (ULP 2.1) are expected and safe for this specific emulation context.
4. Flash and Run. Open the Terminal to view the emulator status.
