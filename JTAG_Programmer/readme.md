This is for testing the JTAG connection.  
You chould receive the ID Code back from the FPGA  

To Build the code  
alr build  

To Program the STM32F0x  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/jtag_test  verify reset exit"  

To send a file through terminal  
ls /dev/ttyACM*  
sudo stty -F /dev/ttyACM0 2000000 raw -echo  
sudo cat output1.bin > /dev/ttyACM0  

To Send Firmware
sudo stty -F /dev/ttyACM0 19200 raw -echo  
sudo cat hello.exe > /dev/ttyACM0  