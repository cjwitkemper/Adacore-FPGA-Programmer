#include "msp.h"
#include <stdint.h>
#include <stdio.h>

// --- HARDWARE CONFIGURATION ---
// STM32 D13 (TCK) -> P5.0 (Input)
// STM32 A2  (TMS) -> P5.1 (Input)
// STM32 D11 (TDI) -> P5.2 (Input)
// STM32 D12 (TDO) <- P5.4 (OUTPUT)
#define PIN_TCK  BIT0
#define PIN_TMS  BIT1
#define PIN_TDI  BIT2
#define PIN_TDO_OUT BIT4

// --- LED INDICATORS ---
#define LED_RST  BIT0  // White
#define LED_ID   BIT1  // Yellow
#define LED_ERS  BIT3  // Blue
#define LED_OK   BIT2  // Green
#define LED_FAIL BIT4  // Red

// --- GOWIN COMMANDS (UG290E Standard) ---
#define CMD_IDCODE      0x11
#define CMD_ERASE       0x05
#define CMD_ERASE_DONE  0x09
#define CMD_WRITE       0x17
#define CMD_NOOP        0x02
#define CMD_ENABLE      0x15  // New!
#define CMD_INIT_ADDR   0x12  // New!
#define CMD_DISABLE     0x3A  // New!
#define CMD_REPROGRAM   0x3C  // New!

#define MIN_STREAM_BITS 100000
#define GOWIN_ID_VAL    0x1100581B

// --- 16-STATE TAP MACHINE ---
typedef enum {
    TAP_RESET      = 0,
    TAP_IDLE       = 1,
    TAP_SELECT_DR  = 2,
    TAP_CAPTURE_DR = 3,
    TAP_SHIFT_DR   = 4,
    TAP_EXIT1_DR   = 5,
    TAP_PAUSE_DR   = 6,
    TAP_EXIT2_DR   = 7,
    TAP_UPDATE_DR  = 8,
    TAP_SELECT_IR  = 9,
    TAP_CAPTURE_IR = 10,
    TAP_SHIFT_IR   = 11,
    TAP_EXIT1_IR   = 12,
    TAP_PAUSE_IR   = 13,
    TAP_EXIT2_IR   = 14,
    TAP_UPDATE_IR  = 15
} TapState;

volatile TapState tapState = TAP_RESET;

// --- DIAGNOSTICS ---
volatile enum {
    NO_ERROR = 0,
    ERR_RESET,
    ERR_FAIL_ID,
    ERR_FAIL_ERASE,
    ERR_FAIL_WRITE,
    MSG_UNKNOWN_CMD,
    MSG_SUCCESS
} sysStatus = NO_ERROR;

volatile uint8_t debug_byte = 0;
volatile uint32_t debug_bits = 0;

// --- UART SETUP ---
void UART_Init(void) {
    P1->SEL0 |= (BIT2|BIT3); P1->SEL1 &= ~(BIT2|BIT3);
    CS->KEY = CS_KEY_VAL; CS->CTL0 = CS_CTL0_DCORSEL_3;
    CS->CTL1 = CS_CTL1_SELM__DCOCLK | CS_CTL1_DIVM__4 | CS_CTL1_SELS__DCOCLK | CS_CTL1_DIVS__4;
    CS->KEY = 0;
    EUSCI_A0->CTLW0 |= EUSCI_A_CTLW0_SWRST;
    EUSCI_A0->CTLW0 = EUSCI_A_CTLW0_SWRST | EUSCI_A_CTLW0_SSEL__SMCLK;
    EUSCI_A0->BRW = 19;
    EUSCI_A0->MCTLW = (0x55 << 8) | (8 << 4) | EUSCI_A_MCTLW_OS16;
    EUSCI_A0->CTLW0 &= ~EUSCI_A_CTLW0_SWRST;
}
void UART_Print(char *str) { while (*str) { while (!(EUSCI_A0->IFG & EUSCI_A_IFG_TXIFG)); EUSCI_A0->TXBUF = *str++; }}
void Print_Hex(uint8_t n) { char b[10]; sprintf(b, "0x%02X", n); UART_Print(b); }
void Print_Int(uint32_t n) { char b[16]; sprintf(b, "%lu", n); UART_Print(b); }

// --- MAIN ---
void main(void) {
    WDT_A->CTL = WDT_A_CTL_PW | WDT_A_CTL_HOLD;
    P4->DIR |= 0x1F; P4->OUT &= ~0x1F;
    P5->DIR &= ~(PIN_TCK|PIN_TMS|PIN_TDI);
    P5->REN |= (PIN_TCK|PIN_TMS|PIN_TDI);
    P5->OUT &= ~(PIN_TCK|PIN_TMS|PIN_TDI);
    P5->DIR |= PIN_TDO_OUT; P5->OUT &= ~PIN_TDO_OUT;

    UART_Init();

    P5->IES &= ~PIN_TCK; P5->IFG &= ~PIN_TCK; P5->IE |= PIN_TCK;
    NVIC->ISER[1] = 1 << ((PORT5_IRQn) & 31);
    __enable_irq();

    UART_Print("\r\n--- FINAL GOWIN JTAG REFEREE ---\r\n");

    while (1) {
        if (sysStatus != NO_ERROR) {
            switch(sysStatus) {
                case ERR_RESET: UART_Print("[INFO] Reset Detected.\r\n"); break;
                case ERR_FAIL_ID: UART_Print("[FAIL] ID Sequence Failed.\r\n"); break;
                case ERR_FAIL_ERASE: UART_Print("[FAIL] Erase Sequence Missing.\r\n"); break;
                case ERR_FAIL_WRITE: UART_Print("[FAIL] Bitstream Too Small.\r\n"); break;
                case MSG_UNKNOWN_CMD: UART_Print("[DEBUG] Unknown Cmd: "); Print_Hex(debug_byte); UART_Print("\r\n"); break;
                case MSG_SUCCESS: UART_Print("[PASS] SUCCESS! Bits: "); Print_Int(debug_bits); UART_Print("\r\n"); break;
                default: break;
            }
            sysStatus = NO_ERROR;
        }
    }
}

// --- VARIABLES ---
volatile uint8_t shiftReg = 0;
volatile int bitIdx = 0;
volatile uint8_t lastCmd = 0;
volatile uint32_t streamCount = 0;
volatile int eraseStage = 0; // 0=None, 1=Started, 2=Done

void PORT5_IRQHandler(void) {
    if (P5->IFG & PIN_TCK) {
        uint8_t tms = (P5->IN & PIN_TMS) ? 1 : 0;
        uint8_t tdi = (P5->IN & PIN_TDI) ? 1 : 0;

        switch (tapState) {
            case TAP_RESET:      tapState = (tms ? TAP_RESET : TAP_IDLE);
                                 if(tapState == TAP_IDLE) {
                                     P4->OUT = LED_RST;
                                     eraseStage=0; streamCount=0; lastCmd=0;
                                     sysStatus = ERR_RESET;
                                 }
                                 break;
            case TAP_IDLE:       tapState = (tms ? TAP_SELECT_DR : TAP_IDLE); break;
            case TAP_SELECT_DR:  tapState = (tms ? TAP_SELECT_IR : TAP_CAPTURE_DR); break;

            // --- DATA PATH (Emulate ID & Count Bits) ---
            case TAP_CAPTURE_DR:
                tapState = (tms ? TAP_EXIT1_DR : TAP_SHIFT_DR);
                bitIdx = 0; streamCount = 0;
                if (lastCmd == CMD_IDCODE) {
                    if (GOWIN_ID_VAL & 0x01) P5->OUT |= PIN_TDO_OUT; else P5->OUT &= ~PIN_TDO_OUT;
                }
                break;
            case TAP_SHIFT_DR:
                if (tms) {
                    tapState = TAP_EXIT1_DR;
                } else {
                    tapState = TAP_SHIFT_DR;
                    if (lastCmd == CMD_WRITE) streamCount++;
                    if (lastCmd == CMD_IDCODE) {
                        streamCount++;
                        if (streamCount < 32) {
                            if ((GOWIN_ID_VAL >> streamCount) & 0x01) P5->OUT |= PIN_TDO_OUT;
                            else                                      P5->OUT &= ~PIN_TDO_OUT;
                        } else { P5->OUT &= ~PIN_TDO_OUT; }
                    }
                }
                break;
            case TAP_EXIT1_DR:   tapState = (tms ? TAP_UPDATE_DR : TAP_PAUSE_DR); break;
            case TAP_PAUSE_DR:   tapState = (tms ? TAP_EXIT2_DR  : TAP_PAUSE_DR); break;
            case TAP_EXIT2_DR:   tapState = (tms ? TAP_UPDATE_DR : TAP_SHIFT_DR); break;
            case TAP_UPDATE_DR:
                tapState = (tms ? TAP_SELECT_DR : TAP_IDLE);
                if (lastCmd == CMD_WRITE) {
                    debug_bits = streamCount;
                    if (streamCount > MIN_STREAM_BITS && eraseStage == 2) {
                        P4->OUT |= LED_OK; P4->OUT &= ~LED_FAIL; sysStatus = MSG_SUCCESS;
                    } else {
                        P4->OUT |= LED_FAIL; sysStatus = ERR_FAIL_WRITE;
                    }
                }
                break;

            // --- INSTRUCTION PATH (Standard) ---
            case TAP_SELECT_IR:  tapState = (tms ? TAP_RESET : TAP_CAPTURE_IR); break;
            case TAP_CAPTURE_IR: tapState = (tms ? TAP_EXIT1_IR : TAP_SHIFT_IR);
                                 bitIdx = 0; shiftReg = 0;
                                 break;
            case TAP_SHIFT_IR:
                if (tms) {
                    tapState = TAP_EXIT1_IR;
                } else {
                    tapState = TAP_SHIFT_IR;
                    if (bitIdx < 8) {
                        shiftReg = (shiftReg >> 1) | (tdi << 7); // LSB First
                        bitIdx++;
                    }
                }
                break;
            case TAP_EXIT1_IR:   tapState = (tms ? TAP_UPDATE_IR : TAP_PAUSE_IR); break;
            case TAP_PAUSE_IR:   tapState = (tms ? TAP_EXIT2_IR  : TAP_PAUSE_IR); break;
            case TAP_EXIT2_IR:   tapState = (tms ? TAP_UPDATE_IR : TAP_SHIFT_IR); break;

            // --- INSTRUCTION UPDATE (Verification Logic) ---
            case TAP_UPDATE_IR:
                tapState = (tms ? TAP_SELECT_DR : TAP_IDLE);

                if (shiftReg != CMD_NOOP) { // Ignore 0x02
                    debug_byte = shiftReg;

                    if (shiftReg == CMD_IDCODE) {
                        P4->OUT |= LED_ID;
                    }
                    else if (shiftReg == CMD_ERASE) {
                        eraseStage = 1; // Started
                    }
                    else if (shiftReg == CMD_ERASE_DONE) {
                        if (eraseStage == 1) {
                            eraseStage = 2; P4->OUT |= LED_ERS; // Success
                        } else {
                            eraseStage = 0; // Fail: Done without Start
                        }
                    }
                    else if (shiftReg == CMD_WRITE) {
                        streamCount = 0;
                    }
                    // WHITELIST CHECK - Accept these without error
                    else if (shiftReg != CMD_ENABLE &&
                             shiftReg != CMD_INIT_ADDR &&
                             shiftReg != CMD_DISABLE &&
                             shiftReg != CMD_REPROGRAM) {

                        sysStatus = MSG_UNKNOWN_CMD; // Truly unknown
                    }

                    lastCmd = shiftReg;
                }
                break;
        }

        P5->IFG &= ~PIN_TCK;
    }
}
