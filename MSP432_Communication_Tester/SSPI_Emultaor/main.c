/*
 * MSP432 Gowin Emulator (Level 10 - Flowchart Compliant)
 * * LOGIC: Follows UG290E Figure 7-44 exactly.
 * * FLOW: Erase(05) -> Init(12) -> Enable(15) -> Write(3B)
 * * FIX: Removed incorrect requirement for initial Enable.
 */

#include "msp.h"
#include <stdint.h>
#include <stdio.h>

// --- PINS ---
#define PIN_SCK   BIT0
#define PIN_CS    BIT1
#define PIN_MOSI  BIT2
#define PIN_MISO  BIT4
#define PIN_READY BIT5
#define PIN_DONE  BIT6
#define PIN_RESET BIT7

#define PIN_MODE2 BIT5
#define PIN_MODE0 BIT6
#define PIN_MODE1 BIT7

#define LED_PWR   BIT0
#define LED_RDY   BIT1
#define LED_ERS   BIT2
#define LED_WRT   BIT3
#define LED_DONE  BIT4
#define LED_FAIL  BIT5

// --- COMMANDS ---
#define CMD_READ_STATUS 0x41
#define CMD_IDCODE      0x11
#define CMD_ENABLE      0x15
#define CMD_ERASE       0x05
#define CMD_INIT_ADDR   0x12
#define CMD_WRITE_REQ   0x3B
#define CMD_DISABLE     0x3A

// --- TIMING ---
#define TICKS_PER_MS  48000
#define MIN_ERASE_WAIT_TICKS (4 * TICKS_PER_MS)

// --- PROTOCOL STATES (Updated) ---
typedef enum {
    PROTO_IDLE=0,     // Waiting for ERASE (or Init if skipped)
    PROTO_ERASED,     // Waiting for INIT ADDR
    PROTO_INIT,       // Waiting for WRITE ENABLE (0x15)
    PROTO_WRITE_WAIT, // Waiting for WRITE REQ (0x3B)
    PROTO_WRITING     // Writing Data
} ProtocolState;

// --- EVENT QUEUE ---
#define QUEUE_SIZE 32
typedef enum {
    EVT_NONE=0,
    EVT_ENABLE,
    EVT_ERASE,
    EVT_INIT_ADDR,
    EVT_IDCODE,
    EVT_STATUS,
    EVT_WRITE_START,
    EVT_DISABLE,
    EVT_UNKNOWN,
    EVT_ERR_SEQ,
    EVT_ERR_TIMING,
    EVT_RESET,
    EVT_DONE
} EventType;

volatile EventType eventQueue[QUEUE_SIZE];
volatile uint8_t head = 0;
volatile uint8_t tail = 0;

// --- DIAGNOSTIC DATA ---
volatile uint8_t  diag_ReceivedCmd = 0;
volatile ProtocolState diag_ExpectedState = PROTO_IDLE;
volatile uint8_t  diag_UnknownByte = 0;

void Enqueue(EventType e) {
    uint8_t next = (head + 1) % QUEUE_SIZE;
    if (next != tail) {
        eventQueue[head] = e;
        head = next;
    }
}

EventType Dequeue(void) {
    if (head == tail) return EVT_NONE;
    EventType e = eventQueue[tail];
    tail = (tail + 1) % QUEUE_SIZE;
    return e;
}

// --- STATE VARIABLES ---
typedef enum { SPI_IDLE=0, SPI_CMD, SPI_DUMMY, SPI_BURST, SPI_READ_RSP, SPI_STATUS_RSP } SpiState;
volatile SpiState currentState = SPI_IDLE;
volatile ProtocolState protoState = PROTO_IDLE;

volatile uint32_t eraseTimestamp = 0;
volatile uint8_t  shiftReg = 0;
volatile int      bitIdx = 0;
volatile uint8_t  lastCmd = 0;
volatile uint32_t byteCount = 0;
volatile uint32_t outShiftReg = 0;
volatile uint8_t  internalDoneFlag = 0;

// --- SYSTEM INIT ---
void System_Clock_Init_48MHz(void) {
    PCM->CTL0 = PCM_CTL0_KEY_VAL | PCM_CTL0_AMR_1;
    while ((PCM->CTL1 & PCM_CTL1_PMR_BUSY));
    FLCTL_A->BANK0_RDCTL = (FLCTL_A->BANK0_RDCTL & ~(FLCTL_A_BANK0_RDCTL_WAIT_MASK)) | FLCTL_A_BANK0_RDCTL_WAIT_1;
    FLCTL_A->BANK1_RDCTL = (FLCTL_A->BANK1_RDCTL & ~(FLCTL_A_BANK1_RDCTL_WAIT_MASK)) | FLCTL_A_BANK1_RDCTL_WAIT_1;
    CS->KEY = CS_KEY_VAL;
    CS->CTL0 = CS_CTL0_DCORSEL_5;
    CS->CTL1 = CS_CTL1_SELM__DCOCLK | CS_CTL1_DIVM__1 | CS_CTL1_SELS__DCOCLK | CS_CTL1_DIVS__2 | CS_CTL1_DIVHS__2;
    CS->KEY = 0;
}

void UART_Init(void) {
    P1->SEL0 |= (BIT2|BIT3); P1->SEL1 &= ~(BIT2|BIT3);
    EUSCI_A0->CTLW0 |= EUSCI_A_CTLW0_SWRST;
    EUSCI_A0->CTLW0 = EUSCI_A_CTLW0_SWRST | EUSCI_A_CTLW0_SSEL__SMCLK;
    EUSCI_A0->BRW = 156;
    EUSCI_A0->MCTLW = (0 << 8) | (4 << 4) | EUSCI_A_MCTLW_OS16;
    EUSCI_A0->CTLW0 &= ~EUSCI_A_CTLW0_SWRST;
}

void UART_Print(char *str) { while (*str) { while (!(EUSCI_A0->IFG & EUSCI_A_IFG_TXIFG)); EUSCI_A0->TXBUF = *str++; }}
void Print_Hex(uint8_t n) { char b[10]; sprintf(b, "0x%02X", n); UART_Print(b); }
void SysTick_Init(void) { SysTick->LOAD = 0xFFFFFF; SysTick->VAL = 0; SysTick->CTRL = 5; }
uint32_t GetTickDelta(uint32_t start) { uint32_t now = SysTick->VAL; return (start >= now) ? (start - now) : (start + (0xFFFFFF - now)); }
uint8_t CheckModePins(void) {
    if (((P2->IN & PIN_MODE2)==0) && ((P2->IN & PIN_MODE1)==0) && ((P2->IN & PIN_MODE0))) return 1;
    return 0;
}

// --- MAIN LOOP ---
void main(void) {
    volatile int i;
    WDT_A->CTL = WDT_A_CTL_PW | WDT_A_CTL_HOLD;
    System_Clock_Init_48MHz();

    P5->DIR &= ~(PIN_SCK | PIN_CS | PIN_MOSI | PIN_RESET);
    P5->REN |= (PIN_SCK | PIN_CS | PIN_MOSI | PIN_RESET);
    P5->OUT &= ~(PIN_SCK | PIN_CS | PIN_MOSI);
    P5->OUT |= PIN_RESET;
    P5->DIR |= (PIN_MISO | PIN_READY | PIN_DONE);

    P2->DIR &= ~(PIN_MODE0 | PIN_MODE1 | PIN_MODE2);
    P2->REN |= (PIN_MODE0 | PIN_MODE1 | PIN_MODE2);
    P2->OUT &= ~(PIN_MODE0 | PIN_MODE1 | PIN_MODE2);

    P4->DIR |= (LED_PWR | LED_RDY | LED_ERS | LED_WRT | LED_DONE | LED_FAIL);
    P4->OUT &= ~0xFF; P4->OUT |= LED_PWR;

    P5->OUT &= ~PIN_READY;
    P5->OUT &= ~PIN_DONE;
    P5->OUT &= ~PIN_MISO;
    internalDoneFlag = 0;
    protoState = PROTO_IDLE;

    UART_Init();
    SysTick_Init();

    UART_Print("\r\n--- GOWIN EMULATOR (Level 10: Flowchart Compliant) ---\r\n");

    for(i=0; i<1500000; i++);

    if (!CheckModePins()) {
        UART_Print("[WARN] Waiting for Mode Pins (001)...\r\n");
        while (!CheckModePins()) { P4->OUT ^= LED_FAIL; for(i=0; i<800000; i++); }
        P4->OUT &= ~LED_FAIL;
    }

    UART_Print("[INFO] Mode Pins OK. Asserting READY.\r\n");
    P5->OUT |= PIN_READY;
    P4->OUT |= LED_RDY;

    P5->IES &= ~PIN_SCK; P5->IES |= PIN_CS; P5->IFG = 0;
    P5->IE |= (PIN_SCK | PIN_CS | PIN_RESET);
    NVIC->ISER[1] = 1 << ((PORT5_IRQn) & 31);
    __enable_irq();

    while (1) {
        EventType e = Dequeue();

        if (e != EVT_NONE) {
            switch(e) {
                case EVT_ENABLE: UART_Print("[CMD] ENABLE (0x15)\r\n"); break;
                case EVT_ERASE: UART_Print("[CMD] ERASE (0x05) - Timer Started\r\n"); break;
                case EVT_INIT_ADDR: UART_Print("[CMD] INIT ADDR (0x12)\r\n"); break;
                case EVT_IDCODE: UART_Print("[CMD] READ ID (0x11)\r\n"); break;
                case EVT_STATUS: UART_Print("[CMD] READ STATUS (0x41)\r\n"); break;
                case EVT_WRITE_START: UART_Print("[CMD] WRITE START (0x3B)\r\n"); break;
                case EVT_DISABLE: UART_Print("[CMD] WRITE DISABLE (0x3A)\r\n"); break;

                case EVT_UNKNOWN:
                    UART_Print("[???] Unknown Command: "); Print_Hex(diag_UnknownByte); UART_Print("\r\n");
                    break;

                case EVT_ERR_SEQ:
                     P4->OUT |= LED_FAIL;
                     UART_Print("[FAIL] SEQUENCE ERROR!\r\n");
                     UART_Print("       Received: "); Print_Hex(diag_ReceivedCmd); UART_Print("\r\n");
                     UART_Print("       Expected: ");
                     switch(diag_ExpectedState) {
                         case PROTO_IDLE:       UART_Print("ERASE (0x05)"); break; // Changed from ENABLE
                         case PROTO_ERASED:     UART_Print("INIT ADDR (0x12)"); break;
                         case PROTO_INIT:       UART_Print("ENABLE (0x15)"); break;
                         case PROTO_WRITE_WAIT: UART_Print("WRITE REQ (0x3B)"); break;
                         case PROTO_WRITING:    UART_Print("DISABLE (0x3A)"); break;
                         default:               UART_Print("Unknown"); break;
                     }
                     UART_Print("\r\n       Action: Forcing State to Continue...\r\n");
                     break;

                case EVT_ERR_TIMING:
                    UART_Print("[FAIL] Timing: INIT_ADDR sent before 4ms elapsed!\r\n");
                    P4->OUT |= LED_FAIL;
                    break;
                case EVT_RESET:
                    UART_Print("[INFO] Reset Active.\r\n");
                    P4->OUT &= LED_PWR;
                    internalDoneFlag = 0;
                    protoState = PROTO_IDLE;
                    while (!(P5->IN & PIN_RESET));
                    UART_Print("[INFO] Reset Released.\r\n");
                    for(i=0; i<1200000; i++);
                    while (!CheckModePins()) { P4->OUT ^= LED_FAIL; for(i=0; i<800000; i++); }
                    P4->OUT &= ~LED_FAIL;
                    UART_Print("[INFO] Ready Again.\r\n");
                    P5->OUT |= PIN_READY;
                    P4->OUT |= LED_RDY;
                    break;
                case EVT_DONE:
                    UART_Print("[PASS] Configuration Loaded. Done Flag Set.\r\n");
                    P4->OUT |= LED_DONE;
                    break;
                default: break;
            }
        }
    }
}

// --- ISR (Flowchart State Machine) ---
void PORT5_IRQHandler(void) {
    uint32_t flags = P5->IFG;

    if (flags & PIN_SCK) {
        uint8_t mosi = (P5->IN & PIN_MOSI) ? 1 : 0;
        shiftReg = (shiftReg << 1) | mosi;

        if (currentState == SPI_READ_RSP || currentState == SPI_STATUS_RSP) {
             if (outShiftReg & 0x80) P5->OUT |= PIN_MISO;
             else P5->OUT &= ~PIN_MISO;
             outShiftReg <<= 1;
        }

        bitIdx++;

        if (bitIdx == 8) {
            bitIdx = 0;
            if (currentState == SPI_CMD) {
                lastCmd = shiftReg;

                // --- ERASE (0x05) ---
                // Valid in IDLE or ERASED
                if (lastCmd == CMD_ERASE) {
                    eraseTimestamp = SysTick->VAL; Enqueue(EVT_ERASE);
                    protoState = PROTO_ERASED;
                    currentState = SPI_DUMMY; internalDoneFlag = 0;
                }

                // --- INIT ADDR (0x12) ---
                else if (lastCmd == CMD_INIT_ADDR) {
                    // EXPECTED: State should be PROTO_ERASED
                    if (protoState != PROTO_ERASED) {
                        diag_ReceivedCmd = lastCmd;
                        diag_ExpectedState = protoState; // Will likely be IDLE (expects Erase)
                        Enqueue(EVT_ERR_SEQ);
                        // RECOVERY: Advance to INIT anyway
                        protoState = PROTO_INIT;
                    } else {
                        if (GetTickDelta(eraseTimestamp) < MIN_ERASE_WAIT_TICKS) {
                            Enqueue(EVT_ERR_TIMING);
                        } else {
                            P4->OUT |= LED_ERS; protoState = PROTO_INIT;
                        }
                    }
                    Enqueue(EVT_INIT_ADDR);
                    currentState = SPI_DUMMY;
                }

                // --- ENABLE (0x15) ---
                else if (lastCmd == CMD_ENABLE) {
                    // EXPECTED: State should be PROTO_INIT (Ready for Write Enable)
                    if (protoState == PROTO_INIT) {
                        protoState = PROTO_WRITE_WAIT;
                    } else {
                        // If sent at other times, we treat it as valid but maybe out of sequence?
                        // For now, if we are IDLE, we stay IDLE.
                        // If we are writing, we error.
                    }
                    Enqueue(EVT_ENABLE); currentState = SPI_DUMMY;
                }

                // --- WRITE REQ (0x3B) ---
                else if (lastCmd == CMD_WRITE_REQ) {
                    if (protoState != PROTO_WRITE_WAIT) {
                        diag_ReceivedCmd = lastCmd;
                        diag_ExpectedState = protoState;
                        Enqueue(EVT_ERR_SEQ);
                        protoState = PROTO_WRITING;
                    } else {
                        protoState = PROTO_WRITING;
                    }
                    byteCount = 0; P4->OUT |= LED_WRT; Enqueue(EVT_WRITE_START);
                    currentState = SPI_BURST;
                }

                // --- DISABLE (0x3A) ---
                else if (lastCmd == CMD_DISABLE) {
                    Enqueue(EVT_DISABLE);
                    if (byteCount > 100) {
                        P5->OUT |= PIN_DONE; internalDoneFlag = 1; Enqueue(EVT_DONE);
                    }
                    currentState = SPI_DUMMY;
                }

                // --- READS ---
                else if (lastCmd == CMD_IDCODE) {
                    outShiftReg = 0x11; Enqueue(EVT_IDCODE); currentState = SPI_READ_RSP;
                }
                else if (lastCmd == CMD_READ_STATUS) {
                    byteCount = 0; Enqueue(EVT_STATUS); currentState = SPI_STATUS_RSP;
                }
                else {
                    if (lastCmd != 0xFF && lastCmd != 0xFE) {
                         diag_UnknownByte = lastCmd; Enqueue(EVT_UNKNOWN);
                    }
                    currentState = SPI_DUMMY;
                }
            }
            else if (currentState == SPI_BURST) { byteCount++; }
            else if (currentState == SPI_READ_RSP) { outShiftReg = 0x00; }
            else if (currentState == SPI_STATUS_RSP) {
                byteCount++;
                if (byteCount == 6) {
                    if (internalDoneFlag) outShiftReg = 0x02;
                    else outShiftReg = 0x00;
                } else { outShiftReg = 0x00; }
            }
        }
        P5->IFG &= ~PIN_SCK;
    }

    if (flags & PIN_RESET) {
        if (!(P5->IN & PIN_RESET)) {
            P5->OUT &= ~(PIN_READY | PIN_DONE);
            internalDoneFlag = 0; protoState = PROTO_IDLE;
            currentState = SPI_IDLE; Enqueue(EVT_RESET);
        }
        P5->IFG &= ~PIN_RESET;
    }

    if (flags & PIN_CS) {
        if (P5->IN & PIN_CS) {
            currentState = SPI_IDLE; P5->IES |= PIN_CS;
        } else {
            currentState = SPI_CMD; bitIdx = 0; shiftReg = 0; P5->IES &= ~PIN_CS;
        }
        P5->IFG &= ~PIN_CS;
    }
}
