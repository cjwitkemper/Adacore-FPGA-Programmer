# Adacore-FPGA-Programmer
## Introduction
The basis of this project is to create a microcontroller that will program a GW1NR-9C FPGA.
STM32F7070RB Nucleo: This is the microcontroller picked for this project  
Tang Nano 9k: This is the FPGA picked for this project  
Neorve32: This is the softcore we will be uploading  

## Top level folders
[Blinky](Blinky): This is a test project in order to check if Alire is installed correctly along with uploading to the STM32F070RB Nucleo works  
[JTAG_Programmer](JTAG_Test): Sends programming commands, receives file over USART then sends bitstream and final commands  
[MSP432_Communication_Tester](MSP432_Communication_Tester): Tester for SPI and JTAG programming sequences  
[relevant_demos](relevant_demos): This folder has demos for learning how to code in Ada  
[SPI_Programmer](SPI_Programmer): Sends programming commands, receives file over USART then sends bitstream and final commands  
[USB_Test](USB_Test): Testing USB communication to STM32 *Not working*  

### Done
SPI Programmer has been finished, tested with logic analyzer but not tested with GW1NR-9C
JTAG Programmer Programming sequence made, file transfer added, not tested

### To Do
Drivers for USB
