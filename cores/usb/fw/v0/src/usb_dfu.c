/*
 * usb_dfu.c
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

#include <no2usb/usb.h>
#include <no2usb/usb_dfu.h>
#include <no2usb/usb_dfu_proto.h>

#include "spi.h"


#define DFU_VENDOR_PROTO
#ifdef DFU_VENDOR_PROTO
enum usb_fnd_resp dfu_vendor_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer);
#endif


#define DFU_POLL_MS		250


static const uint32_t dfu_valid_req[_DFU_MAX_STATE] = {
	/* appIDLE */
	(1 << USB_REQ_DFU_DETACH) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	0,

	/* appDETACH */
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	0,

	/* dfuIDLE */
	(1 << USB_REQ_DFU_DETACH) |		/* Non-std */
	(1 << USB_REQ_DFU_DNLOAD) |
	(1 << USB_REQ_DFU_UPLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuDNLOAD_SYNC */
	(1 << USB_REQ_DFU_DNLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuDNBUSY */
	0,

	/* dfuDNLOAD_IDLE */
	(1 << USB_REQ_DFU_DNLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuMANIFEST_SYNC */
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuMANIFEST */
	0,

	/* dfuMANIFEST_WAIT_RESET */
	0,

	/* dfuUPLOAD_IDLE */
	(1 << USB_REQ_DFU_UPLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuERROR */
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_CLRSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	0,
};

static struct {
	enum dfu_state state;
	enum dfu_status status;

	uint8_t tick;
	uint8_t intf;	// Selected interface number
	uint8_t alt;	// Selected alt settings

	uint8_t buf[4096] __attribute__((aligned(4)));

	struct {
		uint32_t addr_prog;
		uint32_t addr_erase;
		uint32_t addr_end;

		int op_ofs;
		int op_len;

		enum {
			FL_IDLE = 0,
			FL_ERASE,
			FL_PROGRAM,
		} op;
	} flash;
} g_dfu;

static const struct {
	uint32_t start;
	uint32_t end;
} dfu_zones[2] = {
	{ 0x00080000, 0x000a0000 },	/* iCE40 bitstream */
	{ 0x000a0000, 0x000c0000 },	/* RISC-V firmware */
};


static void
_dfu_tick(void)
{
	/* Rate limit to once every 10 ms */
	if (g_dfu.tick++ < 10)
		return;

	g_dfu.tick = 0;

	/* Anything to do ? Is flash ready ? */
	if ((g_dfu.flash.op == FL_IDLE) || (flash_read_sr() & 1))
		return;

	/* Erase */
	if (g_dfu.flash.op == FL_ERASE) {
		/* Done ? */
		if (g_dfu.flash.addr_erase >= (g_dfu.flash.addr_prog + g_dfu.flash.op_len)) {
			/* Yes, move to programming */
			g_dfu.flash.op = FL_PROGRAM;
		} else{
			/* No, issue the next command */
			flash_write_enable();
			flash_sector_erase(g_dfu.flash.addr_erase);
			g_dfu.flash.addr_erase += 4096;
		}
	}

	/* Programming */
	if ((g_dfu.flash.op == FL_PROGRAM) && (g_dfu.state == dfuDNLOAD_SYNC)) {
		/* Done ? */
		if (g_dfu.flash.op_ofs == g_dfu.flash.op_len) {
			/* Yes ! */
			g_dfu.flash.op = FL_IDLE;
			g_dfu.state = dfuDNLOAD_IDLE;
			g_dfu.flash.addr_prog += g_dfu.flash.op_len;
		} else {
			/* Max len */
			unsigned l = g_dfu.flash.op_len - g_dfu.flash.op_ofs;
			unsigned pl = 256 - ((g_dfu.flash.addr_prog + g_dfu.flash.op_ofs) & 0xff);
			if (l > pl)
				l = pl;

			/* Write page */
			flash_write_enable();
			flash_page_program(&g_dfu.buf[g_dfu.flash.op_ofs], g_dfu.flash.addr_prog + g_dfu.flash.op_ofs, l);

			/* Next page */
			g_dfu.flash.op_ofs += l;
		}
	}
}

static void
_dfu_bus_reset(void)
{
	if (g_dfu.state != appDETACH)
		usb_dfu_cb_reboot();
}

static void
_dfu_state_chg(enum usb_dev_state state)
{
	if (state == USB_DS_CONFIGURED)
		g_dfu.state = dfuIDLE;
}

static bool
_dfu_detach_done_cb(struct usb_xfer *xfer)
{
	usb_dfu_cb_reboot();
	return true;
}

static bool
_dfu_dnload_done_cb(struct usb_xfer *xfer)
{
	/* State update */
	g_dfu.state = dfuDNLOAD_SYNC;

	return true;
}

static enum usb_fnd_resp
_dfu_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	uint8_t state;

	/* If this a class or vendor request for DFU interface ? */
	if (req->wIndex != g_dfu.intf)
		return USB_FND_CONTINUE;

#ifdef DFU_VENDOR_PROTO
	if ((USB_REQ_TYPE(req) | USB_REQ_RCPT(req)) == (USB_REQ_TYPE_VENDOR | USB_REQ_RCPT_INTF)) {
		/* Let vendor code use our large buffer */
		xfer->data = g_dfu.buf;
		xfer->len  = sizeof(g_dfu.buf);

		/* Call vendor code */
		return dfu_vendor_ctrl_req(req, xfer);
	}
#endif

	if ((USB_REQ_TYPE(req) | USB_REQ_RCPT(req)) != (USB_REQ_TYPE_CLASS | USB_REQ_RCPT_INTF))
		return USB_FND_CONTINUE;

	/* Check if this request is allowed in this state */
	if ((dfu_valid_req[g_dfu.state] & (1 << req->bRequest)) == 0)
		goto error;

	/* Handle request */
	switch (req->wRequestAndType)
	{
	case USB_RT_DFU_DETACH:
		/* In theory this should be in runtime mode only but we support
		 * it as a request to reboot to user mode when in DFU mode */
		xfer->cb_done = _dfu_detach_done_cb;
		break;

	case USB_RT_DFU_DNLOAD:
		/* Check for last block */
		if (req->wLength) {
			/* Check length doesn't overflow */
			if ((g_dfu.flash.addr_erase + req->wLength) > g_dfu.flash.addr_end)
				goto error;

			/* Setup buffer for data */
			xfer->len     = req->wLength;
			xfer->data    = g_dfu.buf;
			xfer->cb_done = _dfu_dnload_done_cb;

			/* Prepare flash */
			g_dfu.flash.op_ofs = 0;
			g_dfu.flash.op_len = req->wLength;
			g_dfu.flash.op     = FL_ERASE;
		} else {
			/* Last xfer */
			g_dfu.state = dfuIDLE;
		}
		break;

	case USB_RT_DFU_UPLOAD:
		/* Not supported */
		goto error;

	case USB_RT_DFU_GETSTATUS:
		/* Update state */
		if (g_dfu.state == dfuDNLOAD_SYNC) {
			if (g_dfu.flash.op == FL_IDLE) {
				g_dfu.state = state = dfuDNLOAD_IDLE;
			} else {
				state = dfuDNBUSY;
			}
		} else if (g_dfu.state == dfuMANIFEST_SYNC) {
			g_dfu.state = state = dfuIDLE;
		} else {
			state = g_dfu.state;
		}

		/* Return data */
		xfer->data[0] = g_dfu.status;
		xfer->data[1] = (DFU_POLL_MS >>  0) & 0xff;
		xfer->data[2] = (DFU_POLL_MS >>  8) & 0xff;
		xfer->data[3] = (DFU_POLL_MS >> 16) & 0xff;
		xfer->data[4] = state;
		xfer->data[5] = 0;
		break;

	case USB_RT_DFU_CLRSTATUS:
		/* Clear error */
		g_dfu.state = dfuIDLE;
		g_dfu.status = OK;
		break;

	case USB_RT_DFU_GETSTATE:
		/* Return state */
		xfer->data[0] = g_dfu.state;
		break;

	case USB_RT_DFU_ABORT:
		/* Go to IDLE */
		g_dfu.state = dfuIDLE;
		break;

	default:
		goto error;
	}

	return USB_FND_SUCCESS;

error:
	g_dfu.state  = dfuERROR;
	g_dfu.status = errUNKNOWN;
	return USB_FND_ERROR;
}

static enum usb_fnd_resp
_dfu_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	if ((sel->bInterfaceClass != 0xfe) ||
	    (sel->bInterfaceSubClass != 0x01) ||
	    (sel->bInterfaceProtocol != 0x02))
		return USB_FND_CONTINUE;

	g_dfu.state = dfuIDLE;
	g_dfu.intf  = sel->bInterfaceNumber;
	g_dfu.alt   = sel->bAlternateSetting;

	g_dfu.flash.addr_prog  = dfu_zones[g_dfu.alt].start;
	g_dfu.flash.addr_erase = dfu_zones[g_dfu.alt].start;
	g_dfu.flash.addr_end   = dfu_zones[g_dfu.alt].end;

	return USB_FND_SUCCESS;
}

static enum usb_fnd_resp
_dfu_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	if ((base->bInterfaceClass != 0xfe) ||
	    (base->bInterfaceSubClass != 0x01) ||
	    (base->bInterfaceProtocol != 0x02))
		return USB_FND_CONTINUE;

	*alt = g_dfu.alt;

	return USB_FND_SUCCESS;
}


static struct usb_fn_drv _dfu_drv = {
	.sof		= _dfu_tick,
	.bus_reset      = _dfu_bus_reset,
	.state_chg	= _dfu_state_chg,
	.ctrl_req	= _dfu_ctrl_req,
	.set_intf	= _dfu_set_intf,
	.get_intf	= _dfu_get_intf,
};


void __attribute__((weak))
usb_dfu_cb_reboot(void)
{
	/* Nothing */
}

void
usb_dfu_init(void)
{
	memset(&g_dfu, 0x00, sizeof(g_dfu));

	g_dfu.state = appDETACH;

	usb_register_function_driver(&_dfu_drv);
}
