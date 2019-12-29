CC=gcc
CFLAGS=`pkg-config libusb-1.0 --cflags` -O2 -Wall
LDLIBS=`pkg-config libusb-1.0 --libs`

OBJS=main

main: idt82v2081.o idt82v2081_usb.o main.o

clean:
	rm -f $(OBJS) *.o
