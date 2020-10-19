#Installation
sudo apt install  pkg-config  libusb-dev libusb-1.0-0-dev
sudo apt-install linux-headers-4.19.0-11-common



#Notes
As normal user 'martin' to reset the USB.



>lsusb  -d 04d8:0014 
Bus 002 Device 064: ID 04d8:0014 Microchip Technology, Inc. 


Update below command with the device id

./usbreset /dev/bus/usb/002/064Resetting USB device /dev/bus/usb/002/064



