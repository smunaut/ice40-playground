#include <errno.h>
#include <stdint.h>
#include <stdlib.h>

#include <libusb.h>

#include "idt82v2081.h"
#include "idt82v2081_usb.h"

/* Adaption layer between idt82 driver and libusb */

struct idt82_libusb_infos {
	struct libusb_device_handle *devh;
	uint8_t ep;
};

/* backend function for core idt82 driver */
int idt82_reg_read(struct idt82 *idt, uint8_t reg)
{
	struct idt82_libusb_infos *pi = idt->priv;
	int rv;
	uint8_t val;

	rv = libusb_control_transfer(pi->devh, 0xc2, 0x02, reg, pi->ep, &val, 1, 1000);
	if (rv != 1)
		return -EPIPE;

	return val;
}

/* backend function for core idt82 driver */
int idt82_reg_write(struct idt82 *idt, uint8_t reg, uint8_t val)
{
	struct idt82_libusb_infos *pi = idt->priv;
	int rv;

	rv = libusb_control_transfer(pi->devh, 0x42, 0x01, reg, pi->ep, &val, 1, 1000);
	if (rv != 1)
		return -EPIPE;

	return 0;
}

int idt82_usb_init(struct idt82 *idt, struct libusb_device_handle *devh, uint8_t ep)
{
	struct idt82_libusb_infos *pi;

	idt->priv = pi = malloc(sizeof(struct idt82_libusb_infos));

	pi->devh = devh;
	pi->ep = ep;

	return 0;
}
