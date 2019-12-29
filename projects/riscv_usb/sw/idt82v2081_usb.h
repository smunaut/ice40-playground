#pragma once

#include <stdint.h>

struct idt82;
struct libusb_device_handle;

int idt82_usb_init(struct idt82 *idt, struct libusb_device_handle *devh, uint8_t ep);
