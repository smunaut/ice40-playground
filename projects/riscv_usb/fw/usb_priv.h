/*
 * usb_priv.h
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

#pragma once

#include <stdint.h>

#include "config.h"


/* Hardware registers */
/* ------------------ */

struct usb_core {
	uint32_t csr;
	uint32_t ar;
	uint32_t evt;
} __attribute__((packed,aligned(4)));

#define USB_CSR_PU_ENA		(1 << 15)
#define USB_CSR_CEL_ENA		(1 << 12)
#define USB_CSR_CEL_ACTIVE	(1 << 13)
#define USB_AR_CEL_RELEASE	(1 << 13)


struct usb_ep {
	uint32_t status;
	uint32_t _rsvd[3];
	struct {
		uint32_t csr;
		uint32_t ptr;
	} bd[2];
} __attribute__((packed,aligned(4)));

struct usb_ep_pair {
	struct usb_ep out;
	struct usb_ep in;
} __attribute__((packed,aligned(4)));

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

#define USB_BD_LEN(l)		((l) & 0x3ff)
#define USB_BD_LEN_MSK		0x03ff


static volatile struct usb_core *    const usb_regs    = (void*) (USB_CORE_BASE);
static volatile struct usb_ep_pair * const usb_ep_regs = (void*)((USB_CORE_BASE) + (1 << 13));



/* USB protocol */
/* ------------ */

struct usb_ctrl_req_hdr {
	uint8_t  bmRequestType;
	uint8_t  bRequest;
	uint16_t wValue;
	uint16_t wIndex;
	uint16_t wLength;
} __attribute__((packed));

#define USB_REQ_IS_READ(req)	(  req->bmRequestType & 0x80 )
#define USB_REQ_IS_WRITE(req)	(!(req->bmRequestType & 0x80))

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



/* Internal functions */
/* ------------------ */

/* Internal state */
struct usb_stack {
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
};

extern struct usb_stack g_usb;


/* Helpers for data access */
void usb_data_write(int dst_ofs, const void *src, int len);
void usb_data_read(void *dst, int src_ofs, int len);

/* Descriptors retrieval */
const void *usb_get_device_desc(int *len);
const void *usb_get_config_desc(int *len, int idx);
const void *usb_get_string_desc(int *len, int idx);

/* EndPoint 0 */
void usb_ep0_run(void);
void usb_ep0_init(void);
