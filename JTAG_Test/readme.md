This is for testing the JTAG connection.  
You chould receive the ID Code back from the FPGA  

To Build the code  
alr build  

To Program the STM32F0x  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/jtag_test  verify reset exit"  