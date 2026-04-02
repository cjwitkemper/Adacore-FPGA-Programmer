# Adacore-FPGA-Programmer
## Introduction
The basis of this project is to create a microcontroller that will program a GW1NR-9C FPGA.
STM32F7070RB Nucleo: This is the microcontroller picked for this project  
Tang Nano 9k: This is the FPGA picked for this project  
Neorve32: This is the softcore we will be uploading  

## Top level folders
[JTAG_Programmer_Cmd_Call]: Receives commands from USART, interprets them, and then executes functions based on state
[JTAG_Programmer_Serial]: Sends programming commands, receives file over USART then sends bitstream and final commands  
[MSP432_Communication_Tester](MSP432_Communication_Tester): Tester for SPI and JTAG programming sequences  
[relevant_demos](relevant_demos): This folder has demos for learning how to code in Ada
[supplementary_work]: This folder has all the additional work we did before arriving at our final desing   

### Done
SPI Programmer has been finished, tested with logic analyzer but not tested with GW1NR-9C
JTAG Programmer Serial has been finished and tested.
JTAG Programmer Cmd Calling is nearly finished, but needs changes made to UART terminal to allow data transfer

### To Do
Serial over USB
