/*
 * usb_ctrl_ep0.c
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
#include "usb_hw.h"
#include "usb_priv.h"

#define EP0_PKT_LEN	64

/* Helpers to manipulate BDs */

	/* IN */
static inline uint32_t
usb_ep0_in_peek(void)
{
	return usb_ep_regs[0].in.bd[0].csr;
}

static inline void
usb_ep0_in_clear(void)
{
	usb_ep_regs[0].in.bd[0].csr = 0;
}

static inline void
usb_ep0_in_queue_data(unsigned int len)
{
	usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(len);
}

static inline void
usb_ep0_in_queue_stall(void)
{
	usb_ep_regs[0].in.bd[0].csr = USB_BD_STATE_RDY_STALL;
}

	/* OUT */
static inline uint32_t
usb_ep0_out_peek(void)
{
	return usb_ep_regs[0].out.bd[0].csr;
}

static inline void
usb_ep0_out_clear(void)
{
	usb_ep_regs[0].out.bd[0].csr = 0;
}

static inline void
usb_ep0_out_queue_data(void)
{
	usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(EP0_PKT_LEN);
}

static inline void
usb_ep0_out_queue_stall(void)
{
	usb_ep_regs[0].out.bd[0].csr = USB_BD_STATE_RDY_STALL;
}

	/* SETUP */
static inline uint32_t
usb_ep0_setup_peek(void)
{
	return usb_ep_regs[0].out.bd[1].csr;
}

static inline void
usb_ep0_setup_clear(void)
{
	usb_ep_regs[0].out.bd[1].csr = 0;
}

static inline void
usb_ep0_setup_queue_data(void)
{
	usb_ep_regs[0].out.bd[1].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(EP0_PKT_LEN);
}


/* Handle control transfers */

static void
usb_handle_control_data()
{
	/* Handle read requests */
	if (g_usb.ctrl.state == DATA_IN) {
		/* How much left to do ? */
		int xflen = g_usb.ctrl.xfer.len - g_usb.ctrl.xfer.ofs;
		if (xflen > EP0_PKT_LEN)
			xflen = EP0_PKT_LEN;

		/* Setup descriptor for output */
		if (xflen)
			usb_data_write(0, &g_usb.ctrl.xfer.data[g_usb.ctrl.xfer.ofs], xflen);
		usb_ep0_in_queue_data(xflen);

		/* Move on */
		g_usb.ctrl.xfer.ofs += xflen;

		/* If we're done, setup the OUT ack */
		if (xflen < EP0_PKT_LEN) {
			usb_ep0_out_queue_data();
			g_usb.ctrl.state = STATUS_DONE_OUT;
		}
	}

	/* Handle write requests */
	if (g_usb.ctrl.state == DATA_OUT) {
		/* Read off any data we got */
		uint32_t bds_out = usb_ep0_out_peek();

		if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
		{
			/* Read data from USB buffer */
			int xflen = (bds_out & USB_BD_LEN_MSK) - 2;
			usb_data_read(&g_usb.ctrl.xfer.data[g_usb.ctrl.xfer.ofs], 0, xflen);

			/* Move on */
			g_usb.ctrl.xfer.ofs += xflen;

			/* Done with that buffer */
			usb_ep0_out_clear();
		}

		/* Next ? */
		if (g_usb.ctrl.xfer.ofs == g_usb.ctrl.xfer.len)
		{
			/* Done, ACK with a ZLP */
			usb_ep0_in_queue_data(0);
			g_usb.ctrl.state = STATUS_DONE_IN;
		}
		else if ((bds_out & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA)
		{
			/* Submit next BD to fill */
			usb_ep0_out_queue_data();
		}
	}
}

static void
usb_handle_control_request(struct usb_ctrl_req *req)
{
	enum usb_fnd_resp rv = USB_FND_CONTINUE;

	/* Defaults */
	g_usb.ctrl.xfer.data = g_usb.ctrl.buf;
	g_usb.ctrl.xfer.len  = req->wLength;
	g_usb.ctrl.xfer.ofs     = 0;
	g_usb.ctrl.xfer.cb_data = NULL;
	g_usb.ctrl.xfer.cb_done = NULL;
	g_usb.ctrl.xfer.cb_ctx  = NULL;

	/* Dipatch to all handlers */
	rv = usb_dispatch_ctrl_req(req, &g_usb.ctrl.xfer);

	/* If the request isn't handled, answer with STALL */
	if (rv != USB_FND_SUCCESS) {
		g_usb.ctrl.state = STALL;
		usb_ep0_in_queue_stall();
		usb_ep0_out_queue_stall();
		return;
	}

	/* Handle the 'data' stage now */
	g_usb.ctrl.state = USB_REQ_IS_READ(req) ? DATA_IN : DATA_OUT;

	if (g_usb.ctrl.xfer.len > req->wLength)
		g_usb.ctrl.xfer.len = req->wLength;

	usb_handle_control_data();
}


/* Internally exposed "API" */

void
usb_ep0_reset(void)
{
	/* Reset internal state */
	g_usb.ctrl.state = IDLE;

	/* Configure EP0 */
	usb_ep_regs[0].out.status = USB_EP_TYPE_CTRL | USB_EP_BD_CTRL; /* Type=Control, control mode buffered */
	usb_ep_regs[0].in.status  = USB_EP_TYPE_CTRL | USB_EP_DT_BIT;  /* Type=Control, single buffered, DT=1 */

	/* Setup the BD pointers */
	usb_ep_regs[0].in.bd[0].ptr  = 0;
	usb_ep_regs[0].out.bd[0].ptr = 0;
	usb_ep_regs[0].out.bd[1].ptr = EP0_PKT_LEN;

	/* Clear BD for IN/OUT */
	usb_ep0_in_clear();
	usb_ep0_out_clear();

	/* Queue one buffer for SETUP */
	usb_ep0_setup_queue_data();
}

void
usb_ep0_poll(void)
{
	uint32_t bds_setup, bds_out, bds_in;
	bool acted;

	do {
		/* Not done anything yet */
		acted = false;

		/* Grab current EP status */
		bds_setup = usb_ep0_setup_peek();
		bds_out   = usb_ep0_out_peek();
		bds_in    = usb_ep0_in_peek();

		/* Check for status IN stage finishing */
		if (g_usb.ctrl.state == STATUS_DONE_IN) {
			if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
				/* Return to IDLE */
				g_usb.ctrl.state = IDLE;
				usb_ep0_in_clear();

				/* Completion Callback */
				if (g_usb.ctrl.xfer.cb_done)
					g_usb.ctrl.xfer.cb_done(&g_usb.ctrl.xfer);

				/* Next event */
				acted = true;
			}
		}

		/* Check for status OUT stage finishing */
		else if (g_usb.ctrl.state == STATUS_DONE_OUT) {
			if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
				/* Done with the last IN BD of this transfer */
				usb_ep0_in_clear();

				/* Next event */
				acted = true;
			}
			if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
				/* Sanity check */
				if ((bds_out & USB_BD_LEN_MSK) != 2)
					USB_LOG_ERR("[!] Got a non ZLP as a status stage packet ?!?\n");

				/* Return to IDLE */
				g_usb.ctrl.state = IDLE;
				usb_ep0_out_clear();

				/* Completion Callback */
				if (g_usb.ctrl.xfer.cb_done)
					g_usb.ctrl.xfer.cb_done(&g_usb.ctrl.xfer);

				/* Next event */
				acted = true;
			}
		}

		/* Check for STALL needing a refresh */
		else if (g_usb.ctrl.state == STALL) {
			if ((bds_in & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_STALL) {
				usb_ep0_in_queue_stall();
				acted = true;
			}
			if ((bds_out & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_STALL) {
				usb_ep0_out_queue_stall();
				acted = true;
			}
		}

		/* If any of the above was acted upon, we need a refresh */
		if (acted)
			continue;

		/* Retry any RX error on both setup and data buffers */
		if ((bds_setup & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR) {
			USB_LOG_ERR("[!] Retry SETUP error\n");
			usb_ep0_setup_queue_data();
			acted = true;
			continue;
		}

		if ((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_ERR) {
			USB_LOG_ERR("[!] Retry OUT error\n");
			usb_ep0_out_queue_data();
			acted = true;
			continue;
		}

		/* Check for SETUP */
		if ((bds_setup & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
			/* Really setup ? */
			if (!(bds_setup & USB_BD_IS_SETUP)) {
				USB_LOG_ERR("[!] Got non-SETUP in the SETUP BD !?!\n");
			}

			/* Were we waiting for this ? */
			if ((g_usb.ctrl.state != IDLE) && (g_usb.ctrl.state != STALL)) {
				USB_LOG_ERR("[!] Got SETUP while busy !??\n");
			}

			/* Clear descriptors */
			usb_ep0_out_clear();
			usb_ep0_in_clear();

			/* Make sure DT=1 for IN endpoint after a SETUP */
			usb_ep_regs[0].in.status = USB_EP_TYPE_CTRL | USB_EP_DT_BIT;  /* Type=Control, single buffered, DT=1 */

			/* We acked it, need to handle it */
			usb_data_read(&g_usb.ctrl.req, EP0_PKT_LEN, sizeof(struct usb_ctrl_req));
			usb_handle_control_request(&g_usb.ctrl.req);

			/* Release the lockout and allow new SETUP */
			usb_regs->ar = USB_AR_CEL_RELEASE;
			usb_ep0_setup_queue_data();

			return;
		}

		/* Process data stage */
		if (((bds_out & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)) {
			/* Sanity check */
			if (g_usb.ctrl.state != DATA_OUT) {
				USB_LOG_ERR("[!] Got unexpected DATA !?!\n");
				usb_ep0_out_clear();
			} else {
				/* Process data */
				usb_handle_control_data();
			}

			/* Next event */
			acted = true;
			continue;
		}

		if ((bds_in & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
			/* Sanity check */
			if (g_usb.ctrl.state != DATA_IN) {
				USB_LOG_ERR("[!] Got ack for DATA we didn't send !?!\n");
				usb_ep0_in_clear();
			} else {
				/* Process data */
				usb_handle_control_data();
			}

			/* Next event */
			acted = true;
			continue;
		}
	} while (acted);
}
