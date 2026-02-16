/*
 * MSP432 Gowin SSPI Silicon Emulator (Level 3 - with LED Progress Bar)
 */

#include "msp.h"
#include <stdint.h>
#include <stdio.h>

// --- PIN MAPPING (PORT 5) ---
// STM32 SCK  -> P5.0 (Input)
// STM32 CS   -> P5.1 (Input)
// STM32 MOSI -> P5.2 (Input)
// STM32 MISO <- P5.4 (Output)
// STM32 WAIT <- P5.5 (Output - READY Signal)
// STM32 DONE <- P5.6 (Output - DONE Signal)
// STM32 RST  -> P5.7 (Input  - RECONFIG_N)

#define PIN_SCK   BIT0
#define PIN_CS    BIT1
#define PIN_MOSI  BIT2
#define PIN_MISO  BIT4
#define PIN_READY BIT5
#define PIN_DONE  BIT6
#define PIN_RESET BIT7

// --- LED INDICATORS (PORT 4) ---
// Visual Progress Bar
#define LED_PWR   BIT0  // (P4.0) 1. Power/Reset
#define LED_RDY   BIT1  // (P4.1) 2. FPGA Ready
#define LED_ERS   BIT2  // (P4.2) 3. Erase Command & Timing Check Passed
#define LED_WRT   BIT3  // (P4.3) 4. Write Bitstream (Burst)
#define LED_DONE  BIT4  // (P4.4) 5. Success (DONE High)
#define LED_FAIL  BIT5  // (P4.5) X. Protocol Failure (Red)

// --- TIMING CONSTANTS ---
#define TICKS_PER_MS  3000
#define MIN_ERASE_WAIT_TICKS (4 * TICKS_PER_MS)

// --- COMMANDS ---
#define CMD_IDCODE     0x11
#define CMD_ENABLE     0x15
#define CMD_ERASE      0x05
#define CMD_INIT_ADDR  0x12
#define CMD_WRITE_REQ  0x3B
#define CMD_DISABLE    0x3A
#define CMD_NOOP       0x02

// --- STATE MACHINE ---
typedef enum { SPI_IDLE=0, SPI_CMD, SPI_DUMMY, SPI_BURST, SPI_READ_RSP } SpiState;
volatile SpiState currentState = SPI_IDLE;

// --- DIAGNOSTICS ---
volatile enum {
    SYS_OK = 0,
    ERR_TIMING_ERASE,
    EVT_RESET_ACTIVE,
    MSG_DONE
} sysStatus = SYS_OK;

// --- GLOBAL VARS ---
volatile uint32_t eraseTimestamp = 0;
volatile uint8_t  shiftReg = 0;
volatile int      bitIdx = 0;
volatile uint8_t  lastCmd = 0;
volatile uint32_t byteCount = 0;
volatile uint32_t outShiftReg = 0;
volatile uint8_t  isReady = 0;

// --- UART & SYSTICK ---
void UART_Init(void) {
    P1->SEL0 |= (BIT2|BIT3); P1->SEL1 &= ~(BIT2|BIT3);
    CS->KEY = CS_KEY_VAL; CS->CTL0 = CS_CTL0_DCORSEL_3;
    CS->CTL1 = CS_CTL1_SELM__DCOCLK | CS_CTL1_DIVM__4 | CS_CTL1_SELS__DCOCLK | CS_CTL1_DIVS__4;
    CS->KEY = 0;
    EUSCI_A0->CTLW0 |= EUSCI_A_CTLW0_SWRST;
    EUSCI_A0->CTLW0 = EUSCI_A_CTLW0_SWRST | EUSCI_A_CTLW0_SSEL__SMCLK;
    EUSCI_A0->BRW = 19; EUSCI_A0->MCTLW = (0x55 << 8) | (8 << 4) | EUSCI_A_MCTLW_OS16;
    EUSCI_A0->CTLW0 &= ~EUSCI_A_CTLW0_SWRST;
}

void UART_Print(char *str) {
    while (*str) {
        while (!(EUSCI_A0->IFG & EUSCI_A_IFG_TXIFG));
        EUSCI_A0->TXBUF = *str++;
    }
}

void SysTick_Init(void) {
    SysTick->LOAD = 0xFFFFFF; SysTick->VAL = 0;
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk;
}

uint32_t GetTickDelta(uint32_t start) {
    uint32_t now = SysTick->VAL;
    return (start >= now) ? (start - now) : (start + (0xFFFFFF - now));
}

// --- MAIN ---
void main(void) {
    volatile int i;

    WDT_A->CTL = WDT_A_CTL_PW | WDT_A_CTL_HOLD;

    // 1. PIN INIT (PORT 5 - SIGNALS)
    P5->DIR &= ~(PIN_SCK | PIN_CS | PIN_MOSI | PIN_RESET);
    P5->REN |= (PIN_SCK | PIN_CS | PIN_MOSI | PIN_RESET);
    P5->OUT &= ~(PIN_SCK | PIN_CS | PIN_MOSI);
    P5->OUT |= PIN_RESET; // Pull-up

    P5->DIR |= (PIN_MISO | PIN_READY | PIN_DONE);

    // 2. LED INIT (PORT 4 - VISUALS)
    // Configure P4.0 to P4.5 as Outputs
    P4->DIR |= (LED_PWR | LED_RDY | LED_ERS | LED_WRT | LED_DONE | LED_FAIL);
    P4->OUT &= ~(LED_PWR | LED_RDY | LED_ERS | LED_WRT | LED_DONE | LED_FAIL); // All Off

    // 3. POWER-ON RESET SIMULATION
    P5->OUT &= ~PIN_READY; // Ready Low
    P5->OUT &= ~PIN_DONE;  // Done Low
    P5->OUT &= ~PIN_MISO;

    // LED 1: Power is On, but stuck in Reset
    P4->OUT |= LED_PWR;

    UART_Init();
    SysTick_Init();

    UART_Print("\r\n--- GOWIN SILICON EMULATOR (v3 + LEDs) ---\r\n");

    // Simulate T_init
    for(i=0; i<200000; i++);

    P5->OUT |= PIN_READY;
    isReady = 1;
    P4->OUT |= LED_RDY; // LED 2: Ready

    UART_Print("[INFO] FPGA Ready. (LED 1+2 ON)\r\n");

    // 4. INTERRUPTS
    P5->IES &= ~PIN_SCK;
    P5->IES |= PIN_CS;
    P5->IFG = 0;
    P5->IE |= (PIN_SCK | PIN_CS | PIN_RESET);
    NVIC->ISER[1] = 1 << ((PORT5_IRQn) & 31);
    __enable_irq();

    while (1) {
        if (sysStatus != SYS_OK) {

            // --- ERROR: TIMING VIOLATION ---
            if (sysStatus == ERR_TIMING_ERASE) {
                UART_Print("[FAIL] Timing: Master sent INIT_ADDR before 4ms!\r\n");
                P4->OUT |= LED_FAIL; // Turn on Fail LED
                sysStatus = SYS_OK;
            }

            // --- EVENT: RESET DETECTED ---
            else if (sysStatus == EVT_RESET_ACTIVE) {
                UART_Print("[INFO] Reset Active.\r\n");

                // Clear Progress LEDs (Keep Power On)
                P4->OUT &= LED_PWR;

                while (!(P5->IN & PIN_RESET));

                UART_Print("[INFO] Re-Initializing...\r\n");
                for(i=0; i<150000; i++);

                P5->OUT |= PIN_READY;
                isReady = 1;
                P4->OUT |= LED_RDY; // LED 2 Back On

                sysStatus = SYS_OK;
            }

            // --- EVENT: SUCCESS ---
            else if (sysStatus == MSG_DONE) {
                UART_Print("[PASS] Success! DONE High.\r\n");
                P4->OUT |= LED_DONE; // LED 5: Success!
                while(1);
            }
        }
    }
}

// --- ISR ---
void PORT5_IRQHandler(void) {
    uint32_t flags = P5->IFG;

    // RESET
    if (flags & PIN_RESET) {
        if (!(P5->IN & PIN_RESET)) {
            P5->OUT &= ~PIN_READY;
            P5->OUT &= ~PIN_DONE;
            isReady = 0;
            currentState = SPI_IDLE;
            sysStatus = EVT_RESET_ACTIVE;
        }
        P5->IFG &= ~PIN_RESET;
        return;
    }

    // CHIP SELECT
    if (flags & PIN_CS) {
        if (P5->IN & PIN_CS) {
            currentState = SPI_IDLE;
            P5->IES |= PIN_CS;
        } else {
            currentState = SPI_CMD;
            bitIdx = 0; shiftReg = 0;
            P5->IES &= ~PIN_CS;
        }
        P5->IFG &= ~PIN_CS;
    }

    // CLOCK
    if (flags & PIN_SCK) {
        uint8_t mosi = (P5->IN & PIN_MOSI) ? 1 : 0;
        shiftReg = (shiftReg << 1) | mosi;

        if (currentState == SPI_READ_RSP) {
            if (outShiftReg & 0x80000000) P5->OUT |= PIN_MISO; else P5->OUT &= ~PIN_MISO;
            outShiftReg <<= 1;
        }

        bitIdx++;

        if (bitIdx == 8) {
            bitIdx = 0;

            if (currentState == SPI_CMD) {
                lastCmd = shiftReg;

                if (lastCmd == CMD_ENABLE) {
                    currentState = SPI_DUMMY;
                }
                else if (lastCmd == CMD_ERASE) {
                    eraseTimestamp = SysTick->VAL;
                    currentState = SPI_DUMMY;
                }
                else if (lastCmd == CMD_INIT_ADDR) {
                    // Check Logic: Did 4ms pass since CMD_ERASE?
                    if (GetTickDelta(eraseTimestamp) < MIN_ERASE_WAIT_TICKS) {
                        sysStatus = ERR_TIMING_ERASE;
                    } else {
                        // Pass! Turn on LED 3
                        P4->OUT |= LED_ERS;
                    }
                    currentState = SPI_DUMMY;
                }
                else if (lastCmd == CMD_IDCODE) {
                    outShiftReg = 0x1100581B;
                    currentState = SPI_READ_RSP;
                }
                else if (lastCmd == CMD_WRITE_REQ) {
                    byteCount = 0;
                    P4->OUT |= LED_WRT; // LED 4: Burst Mode Start
                    currentState = SPI_BURST;
                }
                else if (lastCmd == CMD_DISABLE) {
                    if (byteCount > 100) {
                        P5->OUT |= PIN_DONE;
                        sysStatus = MSG_DONE;
                    }
                    currentState = SPI_DUMMY;
                }
                else { currentState = SPI_DUMMY; }
            }
            else if (currentState == SPI_BURST) {
                byteCount++;
            }
        }
        P5->IFG &= ~PIN_SCK;
    }
}
