/*
 * usb_dfu_vendor.c
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

#include "spi.h"


#define USB_RT_DFU_VENDOR_VERSION	((0 << 8) | 0xc1)
#define USB_RT_DFU_VENDOR_SPI_EXEC	((1 << 8) | 0x41)
#define USB_RT_DFU_VENDOR_SPI_RESULT	((2 << 8) | 0xc1)


static bool
_dfu_vendor_spi_exec_cb(struct usb_xfer *xfer)
{
	struct spi_xfer_chunk sx[1] = {
		{ .data = xfer->data, .len = xfer->len, .read = true, .write = true, },
	};
	spi_xfer(SPI_CS_FLASH, sx, 1);
	return true;
}

enum usb_fnd_resp
dfu_vendor_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	switch (req->wRequestAndType)
	{
	case USB_RT_DFU_VENDOR_VERSION:
		xfer->len  = 2;
		xfer->data[0] = 0x01;
		xfer->data[1] = 0x00;
		break;

	case USB_RT_DFU_VENDOR_SPI_EXEC:
		xfer->cb_done = _dfu_vendor_spi_exec_cb;
		break;

	case USB_RT_DFU_VENDOR_SPI_RESULT:
		/* Really nothing to do, data is already in the buffer, and we serve
		 * whatever the host requested ... */
		break;

	default:
		return USB_FND_ERROR;
	}

	return USB_FND_SUCCESS;
}
