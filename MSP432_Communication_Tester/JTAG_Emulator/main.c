/*
 * MSP432 Gowin JTAG Emulator (The Final Masterpiece V2)
 * - Fixed sticky LED bug (changed = to |= on TAP Reset)
 * - Added CMD_USER_MODE (0x0A) to whitelist
 */

#include "msp.h"
#include <stdint.h>
#include <stdio.h>

// --- PINS ---
#define PIN_TCK  BIT0
#define PIN_TMS  BIT1
#define PIN_TDI  BIT2
#define PIN_TDO_OUT BIT4

// --- LED PROGRESS BAR (Port 4) ---
#define LED_PROG_1 BIT0  // White: Reset
#define LED_PROG_2 BIT1  // White: ID Checked
#define LED_PROG_3 BIT2  // White: Erase Started
#define LED_PROG_4 BIT3  // White: Erase Done
#define LED_PROG_5 BIT4  // White: Write & Bitstream Complete (PASS)
#define LED_FAIL   BIT5  // Red:   Error Detected

// --- GOWIN COMMANDS ---
#define CMD_IDCODE      0x11
#define CMD_ERASE       0x05
#define CMD_ERASE_DONE  0x09
#define CMD_WRITE       0x17
#define CMD_NOOP        0x02
#define CMD_ENABLE      0x15
#define CMD_INIT_ADDR   0x12
#define CMD_DISABLE     0x3A
#define CMD_REPROGRAM   0x3C
#define CMD_READ_STATUS 0x41
#define CMD_BYPASS      0x08
#define CMD_USER_MODE   0x0A  // New: Boot to User Mode

#define MIN_STREAM_BITS 100000
#define GOWIN_ID_VAL    0x1100481B //0x1100581B

// --- 16-STATE TAP MACHINE ---
typedef enum {
    TAP_RESET=0, TAP_IDLE=1, TAP_SELECT_DR=2, TAP_CAPTURE_DR=3,
    TAP_SHIFT_DR=4, TAP_EXIT1_DR=5, TAP_PAUSE_DR=6, TAP_EXIT2_DR=7,
    TAP_UPDATE_DR=8, TAP_SELECT_IR=9, TAP_CAPTURE_IR=10, TAP_SHIFT_IR=11,
    TAP_EXIT1_IR=12, TAP_PAUSE_IR=13, TAP_EXIT2_IR=14, TAP_UPDATE_IR=15
} TapState;

// --- PROTOCOL TRACKER ---
typedef enum { PROTO_IDLE=0, PROTO_ERASING, PROTO_ERASE_WAIT_09, PROTO_ERASED, PROTO_WRITING } ProtocolState;

// --- EVENT QUEUE (FIFO) ---
#define QUEUE_SIZE 64
typedef enum {
    EVT_NONE=0, EVT_RESET_TAP, EVT_CMD_IDCODE, EVT_CMD_ENABLE, EVT_CMD_ERASE,
    EVT_CMD_ERASE_DONE, EVT_CMD_INIT, EVT_CMD_WRITE, EVT_CMD_DISABLE,
    EVT_CMD_STATUS, EVT_CMD_UNKNOWN, EVT_DATA_ID_READ, EVT_DATA_BITSTREAM_DONE,
    EVT_ERR_BITSTREAM_TINY, EVT_ERR_PROTOCOL
} EventType;

volatile EventType eventQueue[QUEUE_SIZE];
volatile uint8_t head = 0, tail = 0;

void Enqueue(EventType e) {
    uint8_t next = (head + 1) % QUEUE_SIZE;
    if (next != tail) { eventQueue[head] = e; head = next; }
}
EventType Dequeue(void) {
    if (head == tail) return EVT_NONE;
    EventType e = eventQueue[tail]; tail = (tail + 1) % QUEUE_SIZE; return e;
}

// --- DIAGNOSTIC VARIABLES ---
volatile uint8_t  diag_UnknownCmd = 0;
volatile uint32_t diag_StreamBits = 0;

// --- SYSTEM CLOCK & UART ---
void System_Clock_Init_48MHz(void) {
    PCM->CTL0 = PCM_CTL0_KEY_VAL | PCM_CTL0_AMR_1;
    while ((PCM->CTL1 & PCM_CTL1_PMR_BUSY));
    FLCTL_A->BANK0_RDCTL = (FLCTL_A->BANK0_RDCTL & ~(FLCTL_A_BANK0_RDCTL_WAIT_MASK)) | FLCTL_A_BANK0_RDCTL_WAIT_1;
    FLCTL_A->BANK1_RDCTL = (FLCTL_A->BANK1_RDCTL & ~(FLCTL_A_BANK1_RDCTL_WAIT_MASK)) | FLCTL_A_BANK1_RDCTL_WAIT_1;
    CS->KEY = CS_KEY_VAL; CS->CTL0 = CS_CTL0_DCORSEL_5;
    CS->CTL1 = CS_CTL1_SELM__DCOCLK | CS_CTL1_DIVM__1 | CS_CTL1_SELS__DCOCLK | CS_CTL1_DIVS__16 | CS_CTL1_DIVHS__16;
    CS->KEY = 0;
}

void UART_Init(void) {
    P1->SEL0 |= (BIT2|BIT3); P1->SEL1 &= ~(BIT2|BIT3);
    EUSCI_A0->CTLW0 |= EUSCI_A_CTLW0_SWRST;
    EUSCI_A0->CTLW0 = EUSCI_A_CTLW0_SWRST | EUSCI_A_CTLW0_SSEL__SMCLK;
    EUSCI_A0->BRW = 19; EUSCI_A0->MCTLW = (0x55 << 8) | (8 << 4) | EUSCI_A_MCTLW_OS16;
    EUSCI_A0->CTLW0 &= ~EUSCI_A_CTLW0_SWRST;
}
void UART_Print(char *str) { while (*str) { while (!(EUSCI_A0->IFG & EUSCI_A_IFG_TXIFG)); EUSCI_A0->TXBUF = *str++; }}
void Print_Hex(uint8_t n) { char b[10]; sprintf(b, "0x%02X", n); UART_Print(b); }
void Print_Int(uint32_t n) { char b[16]; sprintf(b, "%lu", n); UART_Print(b); }

// --- MAIN LOOP ---
void main(void) {
    WDT_A->CTL = WDT_A_CTL_PW | WDT_A_CTL_HOLD;
    System_Clock_Init_48MHz(); UART_Init();

    P4->DIR |= 0x3F; P4->OUT &= ~0x3F; // LEDs
    P5->DIR &= ~(PIN_TCK|PIN_TMS|PIN_TDI); P5->REN |= (PIN_TCK|PIN_TMS|PIN_TDI); P5->OUT &= ~(PIN_TCK|PIN_TMS|PIN_TDI);
    P5->DIR |= PIN_TDO_OUT; P5->OUT &= ~PIN_TDO_OUT;

    P5->IES &= ~PIN_TCK; P5->IFG &= ~PIN_TCK; P5->IE |= PIN_TCK;
    NVIC->ISER[1] = 1 << ((PORT5_IRQn) & 31);
    __enable_irq();

    UART_Print("\r\n==================================================\r\n");
    UART_Print("--- GOWIN JTAG REFEREE STARTED (PERFECT CLONE) ---\r\n");
    UART_Print("==================================================\r\n");

    while (1) {
        EventType e = Dequeue();
        if (e != EVT_NONE) {
            switch(e) {
                case EVT_RESET_TAP: UART_Print("\n[STATE] JTAG TAP Reset.\r\n"); break;
                case EVT_CMD_IDCODE: UART_Print("[CMD]   0x11 (READ IDCODE) Latched.\r\n"); break;
                case EVT_CMD_ENABLE: UART_Print("[CMD]   0x15 (ENABLE CONFIG) Latched.\r\n"); break;
                case EVT_CMD_STATUS: UART_Print("[CMD]   0x41 (READ STATUS) Master is Polling...\r\n"); break;
                case EVT_CMD_ERASE: UART_Print("[CMD]   0x05 (ERASE SRAM) Latched. Simulating erase...\r\n"); break;
                case EVT_CMD_ERASE_DONE: UART_Print("[CMD]   0x09 (ERASE DONE) Latched.\r\n"); break;
                case EVT_CMD_INIT: UART_Print("[CMD]   0x12 (INIT ADDRESS) Latched.\r\n"); break;
                case EVT_CMD_WRITE: UART_Print("[CMD]   0x17 (WRITE SRAM) Latched. Waiting for bitstream...\r\n"); break;
                case EVT_CMD_DISABLE: UART_Print("[CMD]   0x3A (DISABLE CONFIG) Latched.\r\n"); break;
                case EVT_CMD_UNKNOWN: UART_Print("[WARN]  Unknown Instruction: "); Print_Hex(diag_UnknownCmd); UART_Print("\r\n"); break;
                case EVT_DATA_ID_READ: UART_Print("[DATA]  Target Read 32 bits from TDO (IDCODE Sent).\r\n"); break;
                case EVT_DATA_BITSTREAM_DONE:
                    UART_Print("[PASS]  Bitstream Transmitted! Bits counted: "); Print_Int(diag_StreamBits); UART_Print("\r\n");
                    UART_Print("        --> Sequence Completed Successfully.\r\n");
                    break;
                case EVT_ERR_BITSTREAM_TINY: UART_Print("[FAIL]  Stream too small: "); Print_Int(diag_StreamBits); UART_Print(" bits.\r\n"); break;
                case EVT_ERR_PROTOCOL: UART_Print("[FAIL]  Protocol violation detected.\r\n"); break;
                default: break;
            }
        }
    }
}

// --- JTAG ISR VARIABLES ---
volatile TapState tapState = TAP_RESET;
volatile ProtocolState protoState = PROTO_IDLE;
volatile uint8_t  irShiftBuf = 0;
volatile uint32_t drShiftBuf = 0;
volatile uint8_t  lastCmd = CMD_IDCODE;
volatile uint32_t streamCount = 0;
volatile int tmsHighCount = 0;

// Hardware Flags
volatile uint8_t isEditMode = 0;
volatile uint8_t isDone = 0;
volatile uint8_t erasePollCount = 0;

void PORT5_IRQHandler(void) {
    if (P5->IFG & PIN_TCK) {
        uint8_t tms = (P5->IN & PIN_TMS) ? 1 : 0;
        uint8_t tdi = (P5->IN & PIN_TDI) ? 1 : 0;

        if (tms) {
            tmsHighCount++;
            if (tmsHighCount == 5) {
                tapState = TAP_RESET; protoState = PROTO_IDLE; streamCount = 0;
                lastCmd = CMD_IDCODE; isEditMode = 0; isDone = 0; erasePollCount = 0;
                P4->OUT |= LED_PROG_1; // FIXED: Bitwise OR preserves the other LEDs!
                Enqueue(EVT_RESET_TAP);
            }
            if (tmsHighCount >= 5) { P5->IFG &= ~PIN_TCK; return; }
        } else { tmsHighCount = 0; }

        switch (tapState) {
            case TAP_RESET:      tapState = (tms ? TAP_RESET : TAP_IDLE); break;
            case TAP_IDLE:       tapState = (tms ? TAP_SELECT_DR : TAP_IDLE); break;
            case TAP_SELECT_DR:  tapState = (tms ? TAP_SELECT_IR : TAP_CAPTURE_DR); break;

            case TAP_CAPTURE_DR:
                tapState = (tms ? TAP_EXIT1_DR : TAP_SHIFT_DR);
                streamCount = 0;

                if (lastCmd == CMD_IDCODE) {
                    drShiftBuf = GOWIN_ID_VAL;
                } else if (lastCmd == CMD_READ_STATUS) {
                    drShiftBuf = 0x00019000; // Base Status
                    if (isEditMode) drShiftBuf |= 0x00000080;
                    if (protoState == PROTO_ERASING) {
                        drShiftBuf |= 0x00000020;
                        if (++erasePollCount > 3) protoState = PROTO_ERASE_WAIT_09;
                    }
                    if (isDone) drShiftBuf |= 0x00002000;
                } else {
                    drShiftBuf = 0;
                }

                if (drShiftBuf & 0x01) P5->OUT |= PIN_TDO_OUT; else P5->OUT &= ~PIN_TDO_OUT;
                break;

            case TAP_SHIFT_DR:
                if (tms) tapState = TAP_EXIT1_DR;
                else tapState = TAP_SHIFT_DR;

                if (lastCmd == CMD_IDCODE || lastCmd == CMD_READ_STATUS) {
                    drShiftBuf = (drShiftBuf >> 1) | ((uint32_t)tdi << 31);
                } else { drShiftBuf = tdi; }

                if (lastCmd == CMD_WRITE) streamCount++;

                if (drShiftBuf & 0x01) P5->OUT |= PIN_TDO_OUT; else P5->OUT &= ~PIN_TDO_OUT;
                break;

            case TAP_EXIT1_DR:   tapState = (tms ? TAP_UPDATE_DR : TAP_PAUSE_DR); break;
            case TAP_PAUSE_DR:   tapState = (tms ? TAP_EXIT2_DR  : TAP_PAUSE_DR); break;
            case TAP_EXIT2_DR:   tapState = (tms ? TAP_UPDATE_DR : TAP_SHIFT_DR); break;

            case TAP_UPDATE_DR:
                tapState = (tms ? TAP_SELECT_DR : TAP_IDLE);
                if (lastCmd == CMD_WRITE) {
                    diag_StreamBits = streamCount;
                    if (streamCount > MIN_STREAM_BITS) {
                        isDone = 1;
                        if (protoState == PROTO_ERASED) {
                            P4->OUT |= LED_PROG_5; Enqueue(EVT_DATA_BITSTREAM_DONE);
                        } else {
                            P4->OUT |= LED_FAIL; Enqueue(EVT_ERR_PROTOCOL);
                        }
                    } else { P4->OUT |= LED_FAIL; Enqueue(EVT_ERR_BITSTREAM_TINY); }
                } else if (lastCmd == CMD_IDCODE) {
                    P4->OUT |= LED_PROG_2;
                    Enqueue(EVT_DATA_ID_READ);
                }
                break;

            case TAP_SELECT_IR:  tapState = (tms ? TAP_RESET : TAP_CAPTURE_IR); break;
            case TAP_CAPTURE_IR:
                tapState = (tms ? TAP_EXIT1_IR : TAP_SHIFT_IR);
                irShiftBuf = 0x01;
                if (irShiftBuf & 0x01) P5->OUT |= PIN_TDO_OUT; else P5->OUT &= ~PIN_TDO_OUT;
                break;

            case TAP_SHIFT_IR:
                irShiftBuf = (irShiftBuf >> 1) | (tdi << 7);

                if (tms) tapState = TAP_EXIT1_IR;
                else tapState = TAP_SHIFT_IR;

                if (irShiftBuf & 0x01) P5->OUT |= PIN_TDO_OUT; else P5->OUT &= ~PIN_TDO_OUT;
                break;

            case TAP_EXIT1_IR:   tapState = (tms ? TAP_UPDATE_IR : TAP_PAUSE_IR); break;
            case TAP_PAUSE_IR:   tapState = (tms ? TAP_EXIT2_IR  : TAP_PAUSE_IR); break;
            case TAP_EXIT2_IR:   tapState = (tms ? TAP_UPDATE_IR : TAP_SHIFT_IR); break;

            case TAP_UPDATE_IR:
                tapState = (tms ? TAP_SELECT_DR : TAP_IDLE);
                if (irShiftBuf != CMD_NOOP) {

                    if (irShiftBuf == CMD_ENABLE) { isEditMode = 1; Enqueue(EVT_CMD_ENABLE); }
                    else if (irShiftBuf == CMD_DISABLE) { isEditMode = 0; Enqueue(EVT_CMD_DISABLE); }
                    else if (irShiftBuf == CMD_IDCODE) { P4->OUT |= LED_PROG_2; Enqueue(EVT_CMD_IDCODE); }
                    else if (irShiftBuf == CMD_ERASE) {
                        protoState = PROTO_ERASING; erasePollCount = 0; isDone = 0;
                        P4->OUT |= LED_PROG_3; Enqueue(EVT_CMD_ERASE);
                    }
                    else if (irShiftBuf == CMD_ERASE_DONE) {
                        if (protoState == PROTO_ERASING || protoState == PROTO_ERASE_WAIT_09) protoState = PROTO_ERASED;
                        P4->OUT |= LED_PROG_4; Enqueue(EVT_CMD_ERASE_DONE);
                    }
                    else if (irShiftBuf == CMD_WRITE) { streamCount = 0; Enqueue(EVT_CMD_WRITE); }
                    else if (irShiftBuf == CMD_INIT_ADDR) Enqueue(EVT_CMD_INIT);
                    else if (irShiftBuf == CMD_READ_STATUS) {
                        static int pollCount = 0; pollCount++;
                        if (pollCount % 500 == 1) Enqueue(EVT_CMD_STATUS);
                    }
                    else if (irShiftBuf == CMD_BYPASS || irShiftBuf == CMD_USER_MODE){} // Silent whitelist
                    else if (irShiftBuf == CMD_REPROGRAM){}
                    else { diag_UnknownCmd = irShiftBuf; Enqueue(EVT_CMD_UNKNOWN); }

                    lastCmd = irShiftBuf;
                }
                break;
        }
        P5->IFG &= ~PIN_TCK;
    }
}
