
example: main.cpp
	g++ `pkg-config --cflags --libs libusb-1.0` main.cpp  -o basic.exe
	gcc `pkg-config --cflags --libs libusb-1.0` -lpthread advanced.c  -o advanced.exe

clean: 
	rm *.exe
