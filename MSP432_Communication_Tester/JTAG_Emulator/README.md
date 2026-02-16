# MSP432 JTAG Compliance Tester for Gowin GW1NR-9

## Overview
This project transforms an **MSP432P4111** LaunchPad into a **JTAG Emulator** for the Gowin GW1NR-9 FPGA (Tang Nano 9k).

The Tester strictly enforces the **Gowin Programming and Configuration Guide Documentation** and the **IEEE 1149.1 Standard**, ensuring that the Master correctly navigates the 16-state TAP controller, sends the correct command sequences (Erase, Init, Write), and transmits a valid bitstream.

It provides real-time feedback via **On-board LEDs** (for visual pass/fail) and a **UART Serial Terminal** (for detailed diagnostics).

## Hardware Requirements
* **Board:** TI MSP432P4111 LaunchPad
* **Target Device:** Gowin GW1NR-9 FPGA (Tang Nano 9K)
* **IDE:** Code Composer Studio (CCS) **v12.5.0**

## Wiring Configuration
Connect the JTAG Master (e.g., STM32) to the MSP432 headers as follows. Note that the MSP432 acts as the "Device" (Slave) in this setup.

| Signal Name | Direction | MSP432 Pin | MSP Header | Description |
| :--- | :--- | :--- | :--- | :--- |
| **TCK** | Input | **P5.0** | J4.33 | JTAG Clock |
| **TMS** | Input | **P5.1** | J4.34 | Test Mode Select (State Machine Control) |
| **TDI** | Input | **P5.2** | J4.35 | Test Data In (Command/Data from Master) |
| **TDO** | **Output**| **P5.4** | J4.37 | Test Data Out (ID Response from MSP432) |
| **GND** | Common | **GND** | J4.22 | Common Ground Reference |

> **Note:** The MSP432 drives **P5.4 (TDO)** to emulate the FPGA. It will reply with the Gowin ID `0x1100581B` when queried.

## LED Status Indicators
The on-board LEDs act as a "Progress Bar" using sticky logic. Once an LED turns on, it stays on until the next Reset.

| LED Color | Checkpoint | Meaning |
| :--- | :--- | :--- |
| **White** (P4.0) | **RESET** | **JTAG Reset Detected.** The Master successfully toggled TMS High >= 5 times. |
| **Yellow** (P4.1) | **ID CHECK** | **Valid ID Read.** The Master requested `0x11` (IDCODE). The MSP432 replied with the fake ID. |
| **Blue** (P4.3) | **ERASE** | **Erase Sequence Complete.** The Master sent `0x05` (Erase), waited, and sent `0x09` (Erase Done). |
| **Green** (P4.2) | **PASS** | **Bitstream Verified.** The Master sent `0x17` (Write) followed by a valid data stream (>100k bits). |
| **Red** (P4.4) | **FAIL** | **Protocol Violation.** The Master failed to erase, sent an empty file, or broke the protocol. |

## UART Terminal Usage
For detailed error reporting, connect the MSP432 to a PC via USB.

* **Baud Rate:** 9600
* **Data Bits:** 8
* **Parity:** None
* **Stop Bits:** 1
* **Flow Control:** None

## Building the Project
1.  Import `main.c` into your CCS Workspace.
2.  Ensure the Target is set to your specific MSP432 variant.
3.  Build (Hammer Icon). 
    * *Note:* Warnings about "Software Delay Loops" (ULP 2.1) are expected and safe for this specific emulation context.
4.  Flash and Run. Open the Terminal to view the emulator status.
