/*
 * firmware.c
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

#include "io.h"
#include "usb_desc.h"



/* USB specs structures / values */

struct usb_ctrl_req_hdr {
	uint8_t  bmRequestType;
	uint8_t  bRequest;
	uint16_t wValue;
	uint16_t wIndex;
	uint16_t wLength;
}  __attribute__((packed));

#define USB_REQ_IS_READ(req)		(  req->bmRequestType & 0x80 )
#define USB_REQ_IS_WRITE(req)		(!(req->bmRequestType & 0x80))

#define USB_REQ_GET_STATUS		0
#define USB_REQ_CLEAR_FEATURE		1
#define USB_REQ_SET_FEATURE		3
#define USB_REQ_SET_ADDRESS		5
#define USB_REQ_GET_DESCRIPTOR		6
#define USB_REQ_SET_DESCRIPTOR		7
#define USB_REQ_GET_CONFIGURATION	8
#define USB_REQ_SET_CONFIGURATION	9
#define USB_REQ_GET_INTERFACE		10
#define USB_REQ_SET_INTERFACE		11
#define USB_REQ_SYNCHFRAME		12



/* Registers / Control addresses */

#define usb_csr			(*(volatile uint32_t*)(0x84000000))
#define usb_ep_status(ep,dir)	(*(volatile uint32_t*)(0x84002000 + ((ep)<<6) + ((dir) << 5)))
#define usb_ep_bd(ep,dir,i,w)	(*(volatile uint32_t*)(0x84002010 + ((ep)<<6) + ((dir) << 5) + ((i) << 3) + ((w) << 2)))
#define usb_data(o)		(*(volatile uint32_t*)(0x85000000 + ((o) << 2)))

#define USB_SR_IS_SETUP		(1 <<  2)
#define USB_SR_IRQ_PENDING	(1 <<  0)

#define USB_CR_PU_ENA		(1 << 15)
#define USB_CR_CEL_ENA		(1 << 14)
#define USB_CR_CEL_RELEASE	(1 <<  1)
#define USB_CR_IRQ_ACK		(1 <<  0)

#define USB_EP_TYPE_NONE	0x0000
#define USB_EP_TYPE_ISOC	0x0001
#define USB_EP_TYPE_INT		0x0002
#define USB_EP_TYPE_BULK	0x0004
#define USB_EP_TYPE_CTRL	0x0006
#define USB_EP_TYPE_HALTED	0x0001

#define USB_EP_DT_BIT		0x0080
#define USB_EP_BD_IDX		0x0040
#define USB_EP_BD_CTRL		0x0020
#define USB_EP_BD_DUAL		0x0010

#define USB_BD_STATE_MSK	0xe000
#define USB_BD_STATE_NONE	0x0000
#define USB_BD_STATE_RDY_DATA	0x4000
#define USB_BD_STATE_RDY_STALL	0x6000
#define USB_BD_STATE_DONE_OK	0x8000
#define USB_BD_STATE_DONE_ERR	0xa000
#define USB_BD_IS_SETUP		0x1000


/* Helpers to copy data to/from EP memory */

static void
usb_data_write(volatile uint32_t *dst_u32, const void *src, int len)
{
	uint32_t *src_u32 = (uint32_t *)src;
	int i, j;

	for (i=0, j=0; i<len; i+=4, j++)
		dst_u32[j] = src_u32[j];
}

static void
usb_data_read(void *dst, const volatile uint32_t *src_u32, int len)
{
	uint32_t *dst_u32 = (uint32_t *)dst;
	uint8_t  *dst_u8  = (uint8_t  *)dst;
	uint32_t x;
	int i, j;

	for (i=0, j=0; i<(len-3); i+=4, j++)
		dst_u32[j] = src_u32[j];

	if (len & 3) {
		x = src_u32[j];
		for (;i<len; i++) {
			dst_u8[i] = (x & 0xff);
			x >>= 8;
		}
	}
}


/* Main USB functions */
static void
usb_short_debug_print(void)
{
	printf("BD0.0  %04x\n", usb_ep_bd(0,0,0,0));
	printf("BD1.0  %04x\n", usb_ep_bd(0,0,1,0));
}

static void
usb_debug_print(void)
{
	puts("\nCSR\n");
	printf("SR    %04x\n", usb_csr);

	puts("\nEP0 OUT\n");
	printf("S      %04x\n", usb_ep_status(0,0));
	printf("BD0.0  %04x\n", usb_ep_bd(0,0,0,0));
	printf("BD0.1  %04x\n", usb_ep_bd(0,0,0,1));
	printf("BD1.0  %04x\n", usb_ep_bd(0,0,1,0));
	printf("BD1.1  %04x\n", usb_ep_bd(0,0,1,1));

	puts("\nEP0 IN\n");
	printf("S      %04x\n", usb_ep_status(0,1));
	printf("BD0.0  %04x\n", usb_ep_bd(0,1,0,0));
	printf("BD0.1  %04x\n", usb_ep_bd(0,1,0,1));
	printf("BD1.0  %04x\n", usb_ep_bd(0,1,1,0));
	printf("BD1.1  %04x\n", usb_ep_bd(0,1,1,1));

	puts("\nEP1 OUT\n");
	printf("S      %04x\n", usb_ep_status(1,0));
	printf("BD0.0  %04x\n", usb_ep_bd(1,0,0,0));
	printf("BD0.1  %04x\n", usb_ep_bd(1,0,0,1));
	printf("BD1.0  %04x\n", usb_ep_bd(1,0,1,0));
	printf("BD1.1  %04x\n", usb_ep_bd(1,0,1,1));

	puts("\nData\n");
	printf("%08x\n", usb_data(0));
	printf("%08x\n", usb_data(1));
	printf("%08x\n", usb_data(2));
	printf("%08x\n", usb_data(3));
}


struct {
	uint32_t csr;

	struct {
		enum {
			IDLE,
			DATA_IN,		/* Data stage via 'IN'  */
			DATA_OUT,		/* Data stage via 'OUT' */
			STATUS_DONE_OUT,	/* Status sent via 'OUT' EP */
			STATUS_DONE_IN,		/* Status sent via 'IN' EP */
		} state;

		struct usb_ctrl_req_hdr req;

		union {
			const uint8_t *out;
			uint8_t *in;
		} data;

		int len;
		int ofs;
	} ctrl;
} g_usb;


static inline void
usb_ep0_out_queue_bd(bool setup, int ofs, int len, bool stall)
{
	int bdi = setup ? 1 : 0;
	usb_ep_bd(0,0,bdi,1) = ofs;
	usb_ep_bd(0,0,bdi,0) = stall ? 0x6000 : (0x4000 | len);
}

static inline void
usb_ep0_in_queue_bd(int ofs, int len, bool stall)
{
	usb_ep_bd(0,1,0,1) = ofs;
	usb_ep_bd(0,1,0,0) = stall ? 0x6000 : (0x4000 | len);
}

static inline uint32_t
usb_ep0_out_peek_bd(bool setup)
{
	int bdi = setup ? 1 : 0;
	return usb_ep_bd(0,0,bdi,0);
}

static inline uint32_t
usb_ep0_in_peek_bd(void)
{
	return usb_ep_bd(0,1,0,0);
}

static inline void
usb_ep0_out_done_bd(bool setup)
{
	int bdi = setup ? 1 : 0;
	usb_ep_bd(0,0,bdi,0) = 0;
}

static inline void
usb_ep0_in_done_bd(void)
{
	usb_ep_bd(0,1,0,0) = 0;
}


static void
usb_init(void)
{
	memset(&g_usb, 0x00, sizeof(g_usb));

	g_usb.csr = USB_CR_PU_ENA | USB_CR_CEL_ENA;

	/* Configure EP0 */
	usb_ep_status(0,0) = 0x0026;	/* Type=Control, control mode buffered */
	usb_ep_status(0,1) = 0x0086;	/* Type=Control, single buffered, DT=1 */

	/* Queue one buffer for SETUP */
	usb_ep0_out_queue_bd(true, 0, 64, false);

	/* Configure EP1 IN/OUT */
	usb_ep_status(1,0) = 0x0011;	/* Type=Isochronous, dual buffered */
	usb_ep_status(1,1) = 0x0011;	/* Type=Isochronous, dual buffered */

	usb_ep_bd(1,0,0,1) = 1184;
	usb_ep_bd(1,0,0,0) = 0x4000 | 432;

	usb_ep_bd(1,0,1,1) = 1616;
	usb_ep_bd(1,0,1,0) = 0x4000 | 432;

	g_usb.ctrl.state = IDLE;
}



static void
usb_handle_control_data()
{
	/* Handle read requests */
	if (g_usb.ctrl.state == DATA_IN) {
		/* How much left to do ? */
		int xflen = g_usb.ctrl.len - g_usb.ctrl.ofs;
		if (xflen > 64)
			xflen = 64;

		/* Setup descriptor for output */
		if (xflen)
			usb_data_write(&usb_data(0), &g_usb.ctrl.data.in[g_usb.ctrl.ofs], xflen);
		usb_ep0_in_queue_bd(0, xflen, false);

		/* Move on */
		g_usb.ctrl.ofs += xflen;

		/* If we're done, setup the OUT ack */
		if (xflen < 64) {
			usb_ep0_out_queue_bd(false, 0, 0, false);
			g_usb.ctrl.state = STATUS_DONE_OUT;
		}
	}

	/* Handle write requests */
	if (g_usb.ctrl.state == DATA_OUT) {
		if (g_usb.ctrl.ofs == g_usb.ctrl.len)
		{
			/* Done, ACK with a ZLP */
			usb_ep0_in_queue_bd(0, 0, false);
			g_usb.ctrl.state = STATUS_DONE_IN;
		}
		else
		{
			/* Fill a BD with as much as we can */

		}
	}
}

static void
usb_handle_control_request(struct usb_ctrl_req_hdr *req)
{
	bool handled = false;

	/* Defaults */
	g_usb.ctrl.data.in  = NULL;
	g_usb.ctrl.data.out = NULL;
	g_usb.ctrl.len  = req->wLength;
	g_usb.ctrl.ofs  = 0;

	/* Process request */
	switch (req->bRequest)
	{
	case USB_REQ_GET_STATUS:
	case USB_REQ_CLEAR_FEATURE:
	case USB_REQ_SET_FEATURE:
		break;

	case USB_REQ_SET_ADDRESS:
		handled = true;
		break;

	case USB_REQ_GET_DESCRIPTOR:
	{
		int idx = req->wValue & 0xff;

		switch (req->wValue & 0xff00)
		{
		case 0x0100:	/* Device */
			g_usb.ctrl.data.out = usb_get_device_desc(&g_usb.ctrl.len);
			break;

		case 0x0200:	/* Configuration */
			g_usb.ctrl.data.out = usb_get_config_desc(&g_usb.ctrl.len, idx);
			break;

		case 0x0300:	/* String */
			g_usb.ctrl.data.out = usb_get_string_desc(&g_usb.ctrl.len, idx);
			break;
		}

		handled = g_usb.ctrl.data.out != NULL;
		break;
	}

	case USB_REQ_SET_DESCRIPTOR:
	case USB_REQ_GET_CONFIGURATION:
		break;

	case USB_REQ_SET_CONFIGURATION:
		handled = true;
		break;

	case USB_REQ_GET_INTERFACE:
	case USB_REQ_SET_INTERFACE:
	case USB_REQ_SYNCHFRAME:
	default:
		break;
	}

	/* If the request isn't handled, answer wil STALL */
	if (!handled) {
		if (USB_REQ_IS_READ(req)) {
			/* Read request, send a STALL for the DATA IN stage */
			g_usb.ctrl.state = STATUS_DONE_IN;
			usb_ep0_in_queue_bd(0, 0, true);
		} else if (req->wLength) {
			/* Write request with some incoming data, send a STALL to next OUT */
			g_usb.ctrl.state = STATUS_DONE_OUT;
			usb_ep0_out_queue_bd(false, 0,  0, true);
		} else {
			/* Write request with no dat, send a STALL in the STATUS IN stage */
			g_usb.ctrl.state = STATUS_DONE_IN;
			usb_ep0_in_queue_bd(0, 0, true);
		}

		return;
	}

	/* Handle the 'data' stage now */
	g_usb.ctrl.state = USB_REQ_IS_READ(req) ? DATA_IN : DATA_OUT;

	if (g_usb.ctrl.len > req->wLength)
		g_usb.ctrl.len = req->wLength;

	usb_handle_control_data();
}

static void
usb_run_control(void)
{
	uint32_t bds_setup, bds_out, bds_in;
	bool acted;

	do {
		/* Not done anything yet */
		acted = false;

		/* Grab current EP status */
		bds_out   = usb_ep0_out_peek_bd(false);
		bds_setup = usb_ep0_out_peek_bd(true);
		bds_in    = usb_ep0_in_peek_bd();

		/* Check for status IN stage finishing */
		if (g_usb.ctrl.state == STATUS_DONE_IN) {
			if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
			{
				g_usb.ctrl.state = IDLE;
				usb_ep0_in_done_bd();
				acted = true;
				continue;
			}
		}

		/* Check for status OUT stage finishing */
		if (g_usb.ctrl.state == STATUS_DONE_OUT) {
			if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
			{
				if ((bds_out & 0x0fff) == 2) {
					g_usb.ctrl.state = IDLE;
					usb_ep0_out_done_bd(false);
					acted = true;
					continue;
				} else {
					puts("[!] Got a non ZLP as a status stage packet ?!?\n");
				}
			}
		}

		/* Retry any RX error on both setup and data buffers */
		if ((bds_setup & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR)
		{
			usb_ep0_out_queue_bd(true, 0, 64, false);
			acted = true;
			continue;
		}

		if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR)
		{
			usb_ep0_out_queue_bd(false, 64, 64, false);
			acted = true;
			continue;
		}

		/* Check for SETUP */
		if ((bds_setup & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
		{
			/* Really setup ? */
			if (!(bds_setup & USB_BD_IS_SETUP)) {
				puts("[!] Got non-SETUP in the SETUP BD !?!\n");
			}

			/* Were we waiting for this ? */
			if (g_usb.ctrl.state != IDLE) {
				puts("[!] Got SETUP while busy !??\n");
			}

			/* Clear descriptors */
			usb_ep_bd(0,0,0,0) = 0x0000;
			usb_ep_bd(0,1,0,0) = 0x0000;

			/* Make sure DT=1 for IN endpoint after a SETUP */
			usb_ep_status(0,1) = 0x0086;	/* Type=Control, single buffered, DT=1 */

			/* We acked it, need to handle it */
			usb_data_read(&g_usb.ctrl.req, &usb_data(0), sizeof(struct usb_ctrl_req_hdr));
			usb_handle_control_request(&g_usb.ctrl.req);

			/* Release the lockout and allow new SETUP */
			usb_csr = g_usb.csr | USB_CR_CEL_RELEASE;
			usb_ep0_out_queue_bd(true, 0, 64, false);

			return;
		}

		/* Process data stage */
		if (((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)) {
			usb_ep0_out_done_bd(false);
			if (g_usb.ctrl.state != DATA_OUT) {
				puts("[!] Got unexpected DATA !?!\n");
				continue;
			}
			usb_handle_control_data();
			acted = true;
		}

		if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
			usb_ep0_in_done_bd();
			if (g_usb.ctrl.state == DATA_IN) {
				usb_handle_control_data();
				acted = true;
			}
		}

	} while (acted);
}

static void
usb_run(void)
{
	uint32_t status;
	int isoc_bdi = 0;

	/* Enable pull-up for detection */
	usb_csr = g_usb.csr;

	/* Main polling loop */
	while (1) {
		if (getchar_nowait() == 'd')
			usb_debug_print();

		/* Poll for activity */
		status = usb_csr;
		if (!(status & USB_SR_IRQ_PENDING))
			continue;

		/* Ack interrupt */
		usb_csr = g_usb.csr | USB_CR_IRQ_ACK;

		/* Check control transfers */
		usb_run_control();

		/* Check ISOC */
		{
			uint32_t bds = usb_ep_bd(1,0,isoc_bdi,0);

			if ((bds & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
			{
				printf("%d\n", bds & 0xfff);

				/* Re-arm */
				usb_ep_bd(1,0,isoc_bdi,0) = 0x4000 | 432;
				isoc_bdi ^= 1;
			}
		}
	}
}


void main()
{
	/* Init debug IO */
	io_init();
	puts("Booting..\n");

	/* Init USB */
	usb_init();

	while (1)
	{
		for (int rep = 10; rep > 0; rep--)
		{
			puts("Command> ");
			char cmd = getchar();
			if (cmd > 32 && cmd < 127)
				putchar(cmd);
			puts("\n");

			switch (cmd)
			{
			case 'd':
				usb_debug_print();
				break;
			case 'r':
				usb_run();
				break;
			default:
				continue;
			}

			break;
		}
	}
}
