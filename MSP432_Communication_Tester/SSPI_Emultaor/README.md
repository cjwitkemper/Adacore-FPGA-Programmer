# MSP432 Gowin SSPI Emulator

## Introduction
This project transforms an **MSP432P4111** LaunchPad into a **SPI Slave Emulator** for the Gowin GW1NR-9 FPGA (Tang Nano 9k).

It is designed to act as a "Referee" to validate an external Master (e.g., STM32, ESP32) that is attempting to program an FPGA via the **SSPI (Slave SPI)** protocol. Instead of programming a real FPGA and guessing why it fails, you connect your Master to this MSP432. 

The Emulator validates the Master against the official **Gowin Programming and Configuration Guide (UG290E)**, strictly enforcing:
1.  **Handshake:** Proper use of the `READY` and Mode signals.
2.  **Timing Physics:** Strict enforcement of the **4ms Erase Wait** time required by the GW1N-9.
3.  **Protocol Sequence:** Verifies the exact flowchart sequence: `Erase (0x05)` -> `Init (0x12)` -> `Enable (0x15)` -> `Write (0x3B)`.
4.  **Smart Diagnostics:** Uses a FIFO queue to guarantee chronological UART logging and provides "Expected vs. Received" feedback on sequence errors while auto-recovering to allow continued testing.
5.  **Bi-Directional Data:** Shifts out the correct Gowin ID Code (`0x11`) and Status checks on MISO.

If your Master driver passes this Emulator, it is certified to work on the real Tang Nano 9k hardware.

## Hardware & Software Used
* **Board:** MSP-EXP432P4111 LaunchPad (Running at 48 MHz Max Speed).
* **IDE:** Texas Instruments Code Composer Studio (CCS) **v12.5.0**.
* **Compiler:** TI ARM Cl (v20.2.7.LTS or compatible).
* **Protocol:** SPI Mode 0 (CPOL=0, CPHA=0), MSB First.

## Wiring Connections
Connect your Master device (STM32, etc.) to the MSP432 **Port 5** and **Port 2** headers.

**⚠️ IMPORTANT:** Ensure both boards share a common **Ground (GND)**.

| Signal | MSP432 Pin | Direction | Description |
| :--- | :--- | :--- | :--- |
| **SCK** | **P5.0** | Input | SPI Clock |
| **CS** | **P5.1** | Input | Chip Select (Active Low) |
| **MOSI** | **P5.2** | Input | Data In |
| **MISO** | **P5.4** | Output | Data Out (ID Code / Status Readback) |
| **READY** | **P5.5** | Output | **Handshake:** High = Ready for Commands. |
| **DONE** | **P5.6** | Output | **Success:** High = Configuration Complete. |
| **RESET** | **P5.7** | Input | **Reconfig_N:** Pull Low to Hard Reset Emulator. |
| **MODE2**| **P2.5** | Input | **Mode Select:** Must be driven LOW. |
| **MODE0**| **P2.6** | Input | **Mode Select:** Must be driven HIGH. |
| **MODE1**| **P2.7** | Input | **Mode Select:** Must be driven LOW. |

## Visual Diagnostics (Port 4 LEDs)
Connect 6 LEDs to Port 4 (P4.0 - P4.5) to view the hardware "Progress Bar."

| LED Pin | Name | Meaning | Progress State |
| :--- | :--- | :--- | :--- |
| **P4.0** | **PWR** | **Power/Reset** | **[ON]** Emulator is alive. |
| **P4.1** | **RDY** | **FPGA Ready** | **[ON]** Initialization & Mode Pins verified. |
| **P4.2** | **ERS** | **Erase Pass** | **[ON]** Erase Command received **AND** >4ms Timing Check passed via INIT_ADDR. |
| **P4.3** | **WRT** | **Writing** | **[ON]** Burst Mode active. Bitstream is loading. |
| **P4.4** | **DONE** | **Success** | **[ON]** Configuration Finished. DONE pin is High. |
| **P4.5** | **FAIL** | **Error** | **[BLINK/ON]** Timing violation or Sequence Order Error. |

### The "Progress Bar"
A successful programming sequence will light up the LEDs in order:
1.  `[X] [ ] [ ] [ ] [ ]` (Boot)
2.  `[X] [X] [ ] [ ] [ ]` (Ready & Mode Pins OK)
3.  `[X] [X] [X] [ ] [ ]` (Erase & Timing Validated)
4.  `[X] [X] [X] [X] [ ]` (Writing Data)
5.  `[X] [X] [X] [X] [X]` (Success!)

## Terminal & UART Diagnostics
This project uses the **UART Backchannel** (USB to PC) for highly detailed, chronological status reporting using an internal FIFO queue. 

### UART Setup
* **Baud Rate:** 9600 (Derived from 24 MHz SMCLK)
* **Data Bits:** 8
* **Parity:** None
* **Stop Bits:** 1
* **Terminal:** Use the built-in CCS Terminal, PuTTY, or TeraTerm connected to the LaunchPad's Application/User UART COM port.

### Terminal Output Examples

**Successful Run:**
```text
--- GOWIN EMULATOR (Level 10: Flowchart Compliant) ---
[INFO] Mode Pins OK. Asserting READY.
[CMD] ERASE (0x05) - Timer Started
[CMD] INIT ADDR (0x12)
[CMD] ENABLE (0x15)
[CMD] WRITE START (0x3B)
[CMD] WRITE DISABLE (0x3A)
[PASS] Configuration Loaded. Done Flag Set.
```

**Smart Diagnostics (Sequence Error Example):**
```text
[FAIL] SEQUENCE ERROR!
       Received: 0x12
       Expected: ERASE (0x05)
       Action: Forcing State to Continue...
```

### Critical Operational Notes
1. **Strict Sequence:** This emulator strictly enforces the UG290E Flowchart. The Master must send: ERASE (0x05) -> INIT_ADDR (0x12) -> WRITE_ENABLE (0x15) -> WRITE_DATA (0x3B). Sending these out of order triggers a Sequence Error, though the emulator will auto-recover to allow testing the rest of your code.

2. **Strict Timing:** This emulator enforces a 4ms minimum delay between the ERASE (0x05) and INIT_ADDR (0x12) commands. If your driver executes too fast, it will trigger a Timing Error.

3. **Stateless Reads:** Commands like READ_STATUS (0x41) and READ_ID (0x11) can be sent at any time and do not affect the internal state machine.

4. **Burst Mode:** When sending the bitstream (0x3B command), the Master must keep CS Low for the entire duration of the transfer. Toggling CS High will abort the write and reset the state machine.

### Building the Project
1. Import main.c into your CCS Workspace.

2. Ensure the Target is set to your specific MSP432 variant (e.g., MSP432P4111).

3. Build (Hammer Icon).
  - Note: Warnings about "Software Delay Loops" (ULP 2.1) are expected and safe for this specific high-speed emulation context.

4. Flash and Run. Open the Terminal to view the emulator status.
