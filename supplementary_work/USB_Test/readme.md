This is for testing the USB connection.  
You chould receive the ID Code back from the microcontroller  

To Build the code  
alr build  

To Program the STM32F0x  
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/usb_example  verify reset exit"  

To check USB devices available  
udevadm info -a -n /dev/ttyACM0 | grep -E 'idVendor|idProduct|manufacturer|product'  
