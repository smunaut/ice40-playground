/*
 * usb_desc_app.c
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

#include "usb_proto.h"
#include "usb.h"

#define NULL ((void*)0)
#define num_elem(a) (sizeof(a) / sizeof(a[0]))


static const struct {
	/* Configuration */
	struct usb_conf_desc conf;

	/* CDC */
	struct {
		struct usb_intf_desc intf_ctl;
		struct usb_cs_intf_hdr_desc cs_intf_hdr;
		struct usb_cs_intf_acm_desc cs_intf_acm;
		struct usb_cs_intf_union_desc cs_intf_union;
		uint8_t cs_intf_union_slave;
		struct usb_ep_desc ep_ctl;
		struct usb_intf_desc intf_data;
		struct usb_ep_desc ep_data_out;
		struct usb_ep_desc ep_data_in;
	} __attribute__ ((packed)) cdc;

	/* DFU Runtime */
	struct {
		struct usb_intf_desc intf;
		struct usb_dfu_desc func;
	} __attribute__ ((packed)) dfu;
} __attribute__ ((packed)) _app_conf_desc = {
	.conf = {
		.bLength                = sizeof(struct usb_conf_desc),
		.bDescriptorType        = USB_DT_CONF,
		.wTotalLength           = sizeof(_app_conf_desc),
		.bNumInterfaces         = 3,
		.bConfigurationValue    = 1,
		.iConfiguration         = 4,
		.bmAttributes           = 0x80,
		.bMaxPower              = 0x32, /* 100 mA */
	},
	.cdc = {
		.intf_ctl = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 0,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 1,
			.bInterfaceClass	= 0x02,
			.bInterfaceSubClass	= 0x02,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 5,
		},
		.cs_intf_hdr = {
			.bLength		= sizeof(struct usb_cs_intf_hdr_desc),
			.bDescriptorType	= USB_DT_CS_INTF,
			.bDescriptorsubtype	= 0x00,
			.bcdCDC			= 0x0110,
		},
		.cs_intf_acm = {
			.bLength		= sizeof(struct usb_cs_intf_acm_desc),
			.bDescriptorType	= USB_DT_CS_INTF,
			.bDescriptorsubtype	= 0x02,
			.bmCapabilities		= 0x02,
		},
		.cs_intf_union = {
			.bLength		= sizeof(struct usb_cs_intf_union_desc) + 1,
			.bDescriptorType	= USB_DT_CS_INTF,
			.bDescriptorsubtype	= 0x06,
			.bMasterInterface	= 0,
		},
		.cs_intf_union_slave = 1,
		.ep_ctl = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x84,
			.bmAttributes		= 0x03,
			.wMaxPacketSize		= 64,
			.bInterval		= 0x40,
		},
		.intf_data = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 1,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 2,
			.bInterfaceClass	= 0x0a,
			.bInterfaceSubClass	= 0x00,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 6,
		},
		.ep_data_out = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x05,
			.bmAttributes		= 0x02,
			.wMaxPacketSize		= 64,
			.bInterval		= 0x00,
		},
		.ep_data_in = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x85,
			.bmAttributes		= 0x02,
			.wMaxPacketSize		= 64,
			.bInterval		= 0x00,
		},
	},
	.dfu = {
		.intf = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 2,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 0,
			.bInterfaceClass	= 0xfe,
			.bInterfaceSubClass	= 0x01,
			.bInterfaceProtocol	= 0x01,
			.iInterface		= 7,
		},
		.func = {
			.bLength		= sizeof(struct usb_dfu_desc),
			.bDescriptorType	= USB_DT_DFU,
			.bmAttributes		= 0x0d,
			.wDetachTimeOut		= 1000,
			.wTransferSize		= 4096,
			.bcdDFUVersion		= 0x0101,
		},
	},
};

static const struct usb_conf_desc * const _conf_desc_array[] = {
	&_app_conf_desc.conf,
};

static const struct usb_dev_desc _dev_desc = {
	.bLength		= sizeof(struct usb_dev_desc),
	.bDescriptorType	= USB_DT_DEV,
	.bcdUSB			= 0x0200,
	.bDeviceClass		= 0,
	.bDeviceSubClass	= 0,
	.bDeviceProtocol	= 0,
	.bMaxPacketSize0	= 64,
	.idVendor		= 0x1d50,
	.idProduct		= 0x6147,
	.bcdDevice		= 0x0001,	/* v0.1 */
	.iManufacturer		= 2,
	.iProduct		= 3,
	.iSerialNumber		= 1,
	.bNumConfigurations	= num_elem(_conf_desc_array),
};

#include "usb_str_app.gen.h"

const struct usb_stack_descriptors app_stack_desc = {
	.dev = &_dev_desc,
	.conf = _conf_desc_array,
	.n_conf = num_elem(_conf_desc_array),
	.str = _str_desc_array,
	.n_str = num_elem(_str_desc_array),
};
