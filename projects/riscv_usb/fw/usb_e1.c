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
#include "e1.h"
#include "misc.h"
#include "usb_hw.h"
#include "usb_priv.h"

struct {
	bool running;
	int in_bdi[2];
} g_usb_e1;


/* Hack */
unsigned int e1_rx_need_data(int chan, unsigned int usb_addr, unsigned int max_len, unsigned int *pos);
unsigned int e1_rx_level(int chan);
uint8_t e1_get_pending_flags(int chan);
/* ---- */

bool
usb_ep_boot(const struct usb_intf_desc *intf, uint8_t ep_addr, bool dual_bd);


void
usb_e1_run(void)
{
	int chan;
	int bdi;

	if (!g_usb_e1.running)
		return;

	/* EP[1-2] IN */
	for (chan=0; chan<2; chan++)
	{
		bdi = g_usb_e1.in_bdi[chan];

		while ((usb_ep_regs[1+chan].in.bd[bdi].csr & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA)
		{
			uint32_t ptr = usb_ep_regs[1+chan].in.bd[bdi].ptr;
			uint32_t hdr;
			unsigned int pos;

			/* Error check */
			if ((usb_ep_regs[1+chan].in.bd[bdi].csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR)
				printf("Err EP%d IN\n", 1+chan);

			/* Get some data from E1 */
			int n = e1_rx_level(chan);

			if (n > 64)
				n = 12;
			else if (n > 32)
				n = 10;
			else if (n > 8)
				n = 8;
			else if (!n)
				break;

			n = e1_rx_need_data(chan, (ptr >> 2) + 1, n, &pos);

			/* Write header */
				/* [31:12] (reserved) */
				/* [11:10] CRC results (first new multiframe present in packet)  */
				/* [ 9: 8] CRC results (second new multiframe present in packet) */
				/* [ 7: 5] Multiframe sequence number (first frame of packet)    */
				/* [ 4: 0] Position in multi-frame    (first frame of packet)    */
			hdr = (pos & 0xff) | (e1_get_pending_flags(chan) << 24);
			usb_data_write(ptr, &hdr, 4);
			usb_ep_regs[1+chan].in.bd[bdi].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN((n * 32) + 4);

			/* Next BDI */
			bdi ^= 1;
			g_usb_e1.in_bdi[chan] = bdi;
		}
	}
}

static const struct usb_intf_desc *
_find_intf(const struct usb_conf_desc *conf, uint8_t idx)
{
	const struct usb_intf_desc *intf = NULL;
	const void *sod, *eod;

	if (!conf)
		return NULL;

	sod = conf;
	eod = sod + conf->wTotalLength;

	while (1) {
		sod = usb_desc_find(sod, eod, USB_DT_INTF);
		if (!sod)
			break;

		intf = (void*)sod;
		if (intf->bInterfaceNumber == idx)
			return intf;

		sod = usb_desc_next(sod);
	}

	return NULL;
}
enum usb_fnd_resp
_e1_set_conf(const struct usb_conf_desc *conf)
{
	const struct usb_intf_desc *intf;

	printf("e1 set_conf %08x\n", conf);
	if (!conf)
		return USB_FND_SUCCESS;

	intf = _find_intf(conf, 0);
	if (!intf)
		return USB_FND_ERROR;

	printf("e1 set_conf %08x\n", intf);

	usb_ep_boot(intf, 0x81, true);
	usb_ep_boot(intf, 0x82, true);
	
	return USB_FND_SUCCESS;
}

enum usb_fnd_resp
_e1_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	if (base->bInterfaceNumber != 0)
		return USB_FND_CONTINUE;

	if (sel->bAlternateSetting == 0)
	{
		/* Already stopped ? */
		if (!g_usb_e1.running)
			return USB_FND_SUCCESS;
	
		/* Update state */
		g_usb_e1.running = false;

		/* Stop E1 */
		e1_stop();

		/* Disable end-points */
		usb_ep_regs[1].in.status = 0;
		usb_ep_regs[2].in.status = 0;
	}
	else if (sel->bAlternateSetting == 1)
	{
		/* Already running ? */
		if (g_usb_e1.running)
			return USB_FND_SUCCESS;

		/* Update state */
		g_usb_e1.running = true;

		/* Configure EP1 IN / EP2 IN */
		usb_ep_regs[1].in.status = USB_EP_TYPE_ISOC | USB_EP_BD_DUAL;	/* Type=Isochronous, dual buffered */
		usb_ep_regs[2].in.status = USB_EP_TYPE_ISOC | USB_EP_BD_DUAL;	/* Type=Isochronous, dual buffered */

		/* EP1 IN: Prepare two buffers */
		usb_ep_regs[1].in.bd[0].ptr = 256 + 0 * 388;
		usb_ep_regs[1].in.bd[0].csr = 0;

		usb_ep_regs[1].in.bd[1].ptr = 256 + 1 * 388;
		usb_ep_regs[1].in.bd[1].csr = 0;

		/* EP2 IN: Prepare two buffers */
		usb_ep_regs[2].in.bd[0].ptr = 256 + 2 * 388;
		usb_ep_regs[2].in.bd[0].csr = 0;

		usb_ep_regs[2].in.bd[1].ptr = 256 + 3 * 388;
		usb_ep_regs[2].in.bd[1].csr = 0;

		/* Start E1 */
		e1_start();
	}
	else
	{
		/* Unknown */
		return USB_FND_ERROR;
	}


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
	/* Clear state */
	memset(&g_usb_e1, 0x00, sizeof(g_usb_e1));

	/* Install driver */
	usb_register_function_driver(&_e1_drv);
}
