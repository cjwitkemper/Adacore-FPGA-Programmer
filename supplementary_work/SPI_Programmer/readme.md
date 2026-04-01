This is for testing the full USART->SPI Process  
This should program the FPGA with your Bin file  
How to make a bin file for testing is also below  

To Build the code  
alr build  

To Program the STM32F0x  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/uart_example  verify reset exit"  


To send a file through terminal  
ls /dev/ttyACM*  
sudo stty -F /dev/ttyACM0 115200 raw -echo  
sudo cat bitstream.bin > /dev/ttyACM0  

To update a bin file with bits  
printf "\x01\x00\x01\x01" > bitstream.bin  

To check the contents of a bin file
hexdump -C bitstream.bin  

To Test if STLink is there  
udevadm info -a -n /dev/ttyACM0 | grep -E 'idVendor|idProduct|manufacturer|product'  