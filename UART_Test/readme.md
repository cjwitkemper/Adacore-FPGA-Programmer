To run the code  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/uart_example  verify reset exit"

To send a file through terminal  
ls /dev/ttyACM*  
sudo stty -F /dev/ttyACM0 115200 raw -echo  
sudo cat bitstream.fs > /dev/ttyACM0  

To check the contents of a bin file
hexdump -C bitstream.bin  

To update a bin file with bits  
printf "\x01\x00\x01\x01" > bitstream.bin  