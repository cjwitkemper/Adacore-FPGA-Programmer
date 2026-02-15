# MSP432 Gowin FPGA Programming Emulators

## Overview

This directory contains two separate MSP432-based emulation projects designed to validate and certify FPGA programming drivers for the **Gowin GW1NR-9 (Tang Nano 9K)**.

Instead of debugging against real hardware, these emulators act as strict “referees” that enforce the official Gowin programming specifications and protocol timing requirements.

Each folder contains an independent project targeting the **MSP432P4111 LaunchPad** using **Code Composer Studio (CCS) v12.5.0**.

---

## 📁 Folder Structure

### 1️⃣ `JTAG_Emulator/`

**Purpose:**  
Emulates a Gowin GW1NR-9 FPGA over **JTAG (IEEE 1149.1)**.

**What it does:**
- Acts as a JTAG slave device
- Enforces correct 16-state TAP controller transitions
- Validates command sequence:
  - Reset
  - IDCODE read
  - Erase
  - Init
  - Write
- Verifies a valid bitstream length
- Returns the expected Gowin ID (`0x1100581B`)
- Provides:
  - LED-based pass/fail indicators
  - UART diagnostic output

**Use this folder if you are testing a JTAG-based FPGA programming driver.**

---

### 2️⃣ `SSPI_Emulator/`

**Purpose:**  
Emulates a Gowin GW1NR-9 FPGA over **SSPI (Slave SPI)**.

**What it does:**
- Acts as an SPI Mode 0 slave
- Enforces strict Gowin programming flow:
  - Enable
  - Erase
  - 4ms mandatory timing delay
  - Init
  - Write (burst mode)
- Validates:
  - Proper READY handshake behavior
  - CS staying low during burst writes
  - Correct timing between ERASE and INIT
- Returns the expected Gowin ID (`0x1100581B`)
- Provides:
  - Progress-bar style LED diagnostics
  - Detailed UART failure reporting

**Use this folder if you are testing an SPI-based FPGA programming driver.**

---

## 🎯 When to Use Which Project

| If Your Master Uses | Use This Folder |
|---------------------|-----------------|
| JTAG (TCK/TMS/TDI/TDO) | `JTAG__Emulator` |
| SPI (SCK/CS/MOSI/MISO) | `SSPI_Emulator` |

---

## 🛠 Requirements (Both Projects)

- **Board:** MSP-EXP432P4111 LaunchPad  
- **IDE:** Code Composer Studio (CCS) v12.5.0  
- **Terminal:** 9600 baud, 8N1 (for UART diagnostics)  

---

## 🧪 Purpose of These Emulators

These projects allow you to:

- Validate FPGA programming drivers **before connecting real hardware**
- Catch protocol violations early
- Verify timing compliance
- Confirm proper command sequencing
- Debug using deterministic, repeatable behavior

If your driver passes these emulators, it is highly likely to work reliably on real Tang Nano 9K hardware.

---

## 📌 Note

Each folder contains its own detailed README with:
- Wiring diagrams
- Pin mappings
- LED behavior
- UART configuration
- Build instructions

Refer to the README inside each folder for full implementation details.

