This is for testing the JTAG connection.  
You chould receive the ID Code back from the FPGA  

To Build the code  
alr build  

To Program the STM32F0x  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/jtag_test  verify reset exit"  

To send a file through terminal  
ls /dev/ttyACM*  
sudo stty -F /dev/ttyACM0 230404 raw -echo  
sudo cat output1.bin > /dev/ttyACM0  

To update a bin file with bits  
printf "\x01\x00\x01\x01" > bitstream.bin  

To check the contents of a bin file
hexdump -C bitstream.bin  