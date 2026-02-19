# MSP432 Gowin SSPI Emulator

## Introduction
This project transforms an **MSP432P4111** LaunchPad into a **SPI Slave Emulator** for the Gowin GW1NR-9 FPGA (Tang Nano 9k).

It is designed to act as a "Referee" to validate an external Master (e.g., STM32, ESP32) that is attempting to program an FPGA via the **SSPI (Slave SPI)** protocol. Instead of programming a real FPGA and guessing why it fails, you connect your Master to this MSP432. 

The Emulator validates the Master against the official **Gowin Programming and Configuration Guide Documentation**, enforcing:
1.  **Handshake:** Proper use of the `READY` signal (Wait for High before talking).
2.  **Timing Physics:** Strict enforcement of the **4ms Erase Wait** time required by the GW1N-9.
3.  **Protocol Sequence:** Verifies the Enable -> Erase -> Init -> Write command flow.
4.  **Bi-Directional Data:** Shifts out the correct Gowin ID Code (`0x1100581B`) on MISO.

If your Master driver passes this Emulator, it is certified to work on the real Tang Nano 9k hardware.

## Hardware & Software Used
* **Board:** MSP-EXP432P4111 LaunchPad.
* **IDE:** Texas Instruments Code Composer Studio (CCS) **v12.5.0**.Silicon
* **Compiler:** TI ARM Cl (v20.2.7.LTS or compatible).
* **Protocol:** SPI Mode 0 (CPOL=0, CPHA=0), MSB First.

## Wiring Connections
Connect your Master device (STM32, etc.) to the MSP432 **Port 5** header.

**⚠️ IMPORTANT:** Ensure both boards share a common **Ground (GND)**.

| Signal | MSP432 Pin | Direction | Description |
| :--- | :--- | :--- | :--- |
| **SCK** | **P5.0** | Input | SPI Clock |
| **CS** | **P5.1** | Input | Chip Select (Active Low) |
| **MOSI** | **P5.2** | Input | Data In |
| **MISO** | **P5.4** | Output | Data Out (ID Code Readback) |
| **READY** | **P5.5** | Output | **Handshake:** High = Ready for Commands. |
| **DONE** | **P5.6** | Output | **Success:** High = Configuration Complete. |
| **RESET** | **P5.7** | Input | **Reconfig:** Pull Low to Hard Reset Emulator. |

## Visual Diagnostics (Port 4 LEDs)
Connect 6 LEDs to Port 4 (P4.0 - P4.5) to view the "Progress Bar."

| LED Pin | Name | Meaning | Progress State |
| :--- | :--- | :--- | :--- |
| **P4.0** | **PWR** | **Power/Reset** | **[ON]** Emulator is alive. |
| **P4.1** | **RDY** | **FPGA Ready** | **[ON]** Initialization complete. Master may begin. |
| **P4.2** | **ERS** | **Erase Pass** | **[ON]** Erase Command received **AND** 4ms Timing Check passed. |
| **P4.3** | **WRT** | **Writing** | **[ON]** Burst Mode active. Bitstream is loading. |
| **P4.4** | **DONE** | **Success** | **[ON]** Configuration Finished. DONE pin is High. |
| **P4.5** | **FAIL** | **Error** | **[BLINK/ON]** Timing violation or Protocol Error. |

### The "Progress Bar"
A successful programming sequence will light up the LEDs in order:
1.  `[X] [ ] [ ] [ ] [ ]` (Boot)
2.  `[X] [X] [ ] [ ] [ ]` (Ready)
3.  `[X] [X] [X] [ ] [ ]` (Erase & Timing Validated)
4.  `[X] [X] [X] [X] [ ]` (Writing Data)
5.  `[X] [X] [X] [X] [X]` (Success!)

## Indicators & UART
This project uses the **UART Backchannel** (USB to PC) for detailed status reporting. The onboard LEDs are not used for diagnostics to keep the GPIO ports dedicated to fast signal emulation.

### UART Setup
* **Baud Rate:** 9600
* **Data Bits:** 8
* **Parity:** None
* **Stop Bits:** 1
* **Terminal:** Use the built-in CCS Terminal, PuTTY, or TeraTerm connected to the LaunchPad's Application/User UART COM port.

### Terminal Output Examples
* `[INFO] Power On. READY is Low.` -> Emulator started.
* `[INFO] Initialization Complete. READY is High.` -> Emulator is ready for Master.
* `[FAIL] Timing: Master sent INIT_ADDR before 4ms elapsed!` -> **Error:** Master violated the 4ms Erase specification.
* `[PASS] Success! DONE High.` -> Configuration successful.

## Critical Operational Notes
1.  **Strict Timing:** This emulator enforces a **4ms delay** between the `ERASE (0x05)` and `INIT_ADDR (0x12)` commands. If your driver uses a simple execution loop without `HAL_Delay(4)` (or equivalent), it **will fail** here.
2.  **Reset Behavior:** The `READY` pin behavior is chemically accurate. It will not go High until **after** the `RESET` pin is released (High) plus a simulated 200µs internal initialization time.
3.  **Burst Mode:** When sending the bitstream (`0x3B` command), the Master must keep **CS Low** for the entire duration of the transfer. Toggling CS High will abort the write and reset the state machine.

## Building the Project
1.  Import `main.c` into your CCS Workspace.
2.  Ensure the Target is set to your specific MSP432 variant.
3.  Build (Hammer Icon). 
    * *Note:* Warnings about "Software Delay Loops" (ULP 2.1) are expected and safe for this specific emulation context.
4.  Flash and Run. Open the Terminal to view the emulator status.
