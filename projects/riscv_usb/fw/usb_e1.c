/*
 * usb_e1.c
 *
 * Copyright (C) 2019 Sylvain Munaut
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "console.h"
#include "misc.h"
#include "usb_hw.h"
#include "usb_priv.h"

struct {
	bool running;
	int out_bdi;
	int in_bdi;
} g_usb_e1;


/* Hack */
unsigned int e1_rx_need_data(unsigned int usb_addr, unsigned int max_len);
unsigned int e1_tx_feed_data(unsigned int usb_addr, unsigned int len);
unsigned int e1_tx_level(void);
unsigned int e1_rx_level(void);
/* ---- */

bool
usb_ep_boot(const struct usb_intf_desc *intf, uint8_t ep_addr, bool dual_bd);

static void
_usb_fill_feedback_ep(void)
{
	static uint16_t ticks_prev = 0;
	uint16_t ticks;
	uint32_t val = 8192;
	unsigned int level;

	/* Compute real E1 tick count (with safety agains bad values) */
	ticks = e1_tick_read();
	val = (ticks - ticks_prev) & 0xffff;
	ticks_prev = ticks;
	if ((val < 7168) | (val > 9216))
		val = 8192;

	/* Bias depending on TX fifo level */
	level = e1_tx_level();
	if (level < (3 * 16))
		val += 256;
	else if (level > (8 * 16))
		val -= 256;

	/* Prepare buffer */
	usb_data_write(64, &val, 4);
	usb_ep_regs[1].in.bd[0].ptr = 64;
	usb_ep_regs[1].in.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(3);
}


void
usb_e1_run(void)
{
	int bdi;

	if (!g_usb_e1.running)
		return;

	/* EP2 IN */
	bdi = g_usb_e1.in_bdi;

	while ((usb_ep_regs[2].in.bd[bdi].csr & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA)
	{
		uint32_t ptr = usb_ep_regs[2].in.bd[bdi].ptr;
		uint32_t hdr;

		/* Error check */
		if ((usb_ep_regs[2].in.bd[bdi].csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR)
			puts("Err EP2 IN\n");

		/* Get some data from E1 */
		int n = e1_rx_level();

		if (n > 64)
			n = 12;
		else if (n > 32)
			n = 10;
		else if (n > 8)
			n = 8;
		else if (!n)
			break;

		n = e1_rx_need_data((ptr >> 2) + 1, n);

		/* Write header */
		hdr = 0x616b00b5;
		usb_data_write(ptr, &hdr, 4);

		/* Resubmit */
		usb_ep_regs[2].in.bd[bdi].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN((n * 32) + 4);

		/* Next BDI */
		bdi ^= 1;
		g_usb_e1.in_bdi = bdi;
	}

	/* EP1 OUT */
	bdi = g_usb_e1.out_bdi;

	while ((usb_ep_regs[1].out.bd[bdi].csr & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA)
	{
		uint32_t ptr = usb_ep_regs[1].out.bd[bdi].ptr;
		uint32_t csr = usb_ep_regs[1].out.bd[bdi].csr;
		uint32_t hdr;

		/* Error check */
		if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR) {
			puts("Err EP1 OUT\n");
			goto refill;
		}

		/* Grab header */
		usb_data_read(&hdr, ptr, 4);

		/* Empty data into the FIFO */
		int n = ((csr & USB_BD_LEN_MSK) - 4) / 32;
		n = e1_tx_feed_data((ptr >> 2) + 1, n);

refill:
		/* Refill it */
		usb_ep_regs[1].out.bd[bdi].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(388);

		/* Next BDI */
		bdi ^= 1;
		g_usb_e1.out_bdi = bdi;

		static int x = 0;
		if ((x++ & 0xff) == 0xff)
			puts(".");
	}

	/* EP1 IN */
	if ((usb_ep_regs[1].in.bd[0].csr & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA)
	{
		_usb_fill_feedback_ep();
	}
}

enum usb_fnd_resp
_e1_set_conf(const struct usb_conf_desc *conf)
{
	const struct usb_intf_desc *intf;

	printf("e1 set_conf %08x\n", conf);
	if (!conf)
		return USB_FND_SUCCESS;

	intf = usb_desc_find_intf(conf, 0, 0, NULL);
	if (!intf)
		return USB_FND_ERROR;

	printf("e1 set_conf %08x\n", intf);

	usb_ep_boot(intf, 0x01, true);
	usb_ep_boot(intf, 0x81, true);
	usb_ep_boot(intf, 0x82, true);
	
	return USB_FND_SUCCESS;
}

enum usb_fnd_resp
_e1_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	if (base->bInterfaceNumber != 0)
		return USB_FND_CONTINUE;

	if (sel->bAlternateSetting != 1)
		return USB_FND_SUCCESS;

	/* Hack to avoid re-setting while running ... avoid BD desync */
	if (g_usb_e1.running)
		return USB_FND_SUCCESS;
	
	g_usb_e1.running = true;

	/* Configure EP1 OUT / EP2 IN */
	usb_ep_regs[1].out.status = USB_EP_TYPE_ISOC | USB_EP_BD_DUAL;	/* Type=Isochronous, dual buffered */
	usb_ep_regs[2].in.status  = USB_EP_TYPE_ISOC | USB_EP_BD_DUAL;	/* Type=Isochronous, dual buffered */

	/* Configure EP1 IN (feedback) */
	usb_ep_regs[1].in.status  = USB_EP_TYPE_ISOC; /* Type=Isochronous, single buffered */

	/* EP2 IN: Prepare two buffers */
	usb_ep_regs[2].in.bd[0].ptr = 1024;
	usb_ep_regs[2].in.bd[0].csr = 0;

	usb_ep_regs[2].in.bd[1].ptr = 1536;
	usb_ep_regs[2].in.bd[1].csr = 0;

	/* EP1 OUT: Queue two buffers */
	usb_ep_regs[1].out.bd[0].ptr = 1024;
	usb_ep_regs[1].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(388);

	usb_ep_regs[1].out.bd[1].ptr = 1536;
	usb_ep_regs[1].out.bd[1].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(388);

	/* EP1 IN: Queue buffer */
	_usb_fill_feedback_ep();

	return USB_FND_SUCCESS;
}

enum usb_fnd_resp
_e1_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	if (base->bInterfaceNumber != 0)
		return USB_FND_CONTINUE;

	*alt = g_usb_e1.running ? 1 : 0;

	return USB_FND_SUCCESS;
}

static struct usb_fn_drv _e1_drv = {
	.set_conf	= _e1_set_conf,
        .set_intf       = _e1_set_intf,
        .get_intf       = _e1_get_intf,
};

void
usb_e1_init(void)
{
	memset(&g_usb_e1, 0x00, sizeof(g_usb_e1));
	usb_register_function_driver(&_e1_drv);
}
