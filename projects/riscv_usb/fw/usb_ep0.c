/*
 * usb_ep0.c
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
#include "usb_priv.h"


/* Helpers to manipulate BDs */

static inline void
usb_ep0_out_queue_bd(bool setup, int ofs, int len, bool stall)
{
	int bdi = setup ? 1 : 0;
	usb_ep_regs[0].out.bd[bdi].ptr = ofs;
	usb_ep_regs[0].out.bd[bdi].csr = stall ? USB_BD_STATE_RDY_STALL : (USB_BD_STATE_RDY_DATA | USB_BD_LEN(len));
}

static inline void
usb_ep0_in_queue_bd(int ofs, int len, bool stall)
{
	usb_ep_regs[0].in.bd[0].ptr = ofs;
	usb_ep_regs[0].in.bd[0].csr = stall ? USB_BD_STATE_RDY_STALL : (USB_BD_STATE_RDY_DATA | USB_BD_LEN(len));
}

static inline uint32_t
usb_ep0_out_peek_bd(bool setup)
{
	int bdi = setup ? 1 : 0;
	return usb_ep_regs[0].out.bd[bdi].csr;
}

static inline uint32_t
usb_ep0_in_peek_bd(void)
{
	return usb_ep_regs[0].in.bd[0].csr;
}

static inline void
usb_ep0_out_done_bd(bool setup)
{
	int bdi = setup ? 1 : 0;
	usb_ep_regs[0].out.bd[bdi].csr = 0;
}

static inline void
usb_ep0_in_done_bd(void)
{
	usb_ep_regs[0].in.bd[0].csr = 0;
}


/* Standard control request handling */



/* Handle control transfers */

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
			usb_data_write(0, &g_usb.ctrl.data.in[g_usb.ctrl.ofs], xflen);
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

	/* If the request isn't handled, answer with STALL */
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
			/* Write request with no data, send a STALL in the STATUS IN stage */
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


/* Internally exposed "API" */

void
usb_ep0_run(void)
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
				if ((bds_out & USB_BD_LEN_MSK) == 2) {
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
			usb_ep0_out_done_bd(false);
			usb_ep0_in_done_bd();

			/* Make sure DT=1 for IN endpoint after a SETUP */
			usb_ep_regs[0].in.status = USB_EP_TYPE_CTRL | USB_EP_DT_BIT;  /* Type=Control, single buffered, DT=1 */

			/* We acked it, need to handle it */
			usb_data_read(&g_usb.ctrl.req, 0, sizeof(struct usb_ctrl_req_hdr));
			usb_handle_control_request(&g_usb.ctrl.req);

			/* Release the lockout and allow new SETUP */
			usb_regs->ar = USB_AR_CEL_RELEASE;
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

void
usb_ep0_init(void)
{
	/* Configure EP0 */
	usb_ep_regs[0].out.status = USB_EP_TYPE_CTRL | USB_EP_BD_CTRL; /* Type=Control, control mode buffered */
	usb_ep_regs[0].in.status  = USB_EP_TYPE_CTRL | USB_EP_DT_BIT;  /* Type=Control, single buffered, DT=1 */

	/* Queue one buffer for SETUP */
	usb_ep0_out_queue_bd(true, 0, 64, false);
}
