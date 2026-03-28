# This is how to run the JTAG Programmer.  
This does both the bitstream and the firmware.

## Hardware connections STM32F070 -> GW1NR-9C
| STM32F070rb Pin | GW1NR-9C Pin |
|---------------------|-----------------|
| PA4 | JTAG_TMS |
| PA5 | JTAG_TCK |
| PA6 | JTAG_TDO |
| PA7 | JTAG_TDI |
| PA9 UART1_RX | FPGA_TX |
| PA10 UART1_TX | FPGA_RX |

## Terminal Commands to run the code.
### To Build the code  
alr build  

### To Program the STM32F0x  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/jtag_test  verify reset exit"  

### Port  
You must first check your port using the following command.   
ls /dev/ttyACM*  
For the folowing commands replace * with the result (The following example uses 0)  

### To Send Bitstream
sudo stty -F /dev/ttyACM0 2000000 raw -echo  
sudo cat output1.bin > /dev/ttyACM0  

### To Send Firmware
sudo stty -F /dev/ttyACM0 19200 raw -echo  
sudo cat hello.exe > /dev/ttyACM0  
