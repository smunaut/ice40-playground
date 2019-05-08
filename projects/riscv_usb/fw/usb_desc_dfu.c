/*
 * usb_desc_dfu.c
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
	struct usb_conf_desc conf;
	struct usb_intf_desc if_fpga;
	struct usb_dfu_desc dfu_fpga;
	struct usb_intf_desc if_riscv;
	struct usb_dfu_desc dfu_riscv;
} __attribute__ ((packed)) _dfu_conf_desc = {
	.conf = {
		.bLength                = sizeof(struct usb_conf_desc),
		.bDescriptorType        = USB_DT_CONF,
		.wTotalLength           = sizeof(_dfu_conf_desc),
		.bNumInterfaces         = 1,
		.bConfigurationValue    = 1,
		.iConfiguration         = 4,
		.bmAttributes           = 0x80,
		.bMaxPower              = 0x32, /* 100 mA */
	},
	.if_fpga = {
		.bLength		= sizeof(struct usb_intf_desc),
		.bDescriptorType	= USB_DT_INTF,
		.bInterfaceNumber	= 0,
		.bAlternateSetting	= 0,
		.bNumEndpoints		= 0,
		.bInterfaceClass	= 0xfe,
		.bInterfaceSubClass	= 0x01,
		.bInterfaceProtocol	= 0x02,
		.iInterface		= 5,
	},
	.dfu_fpga = {
		.bLength		= sizeof(struct usb_dfu_desc),
		.bDescriptorType	= USB_DT_DFU,
		.bmAttributes		= 0x0d,
		.wDetachTimeOut		= 1000,
		.wTransferSize		= 4096,
		.bcdDFUVersion		= 0x0101,
	},
	.if_riscv = {
		.bLength		= sizeof(struct usb_intf_desc),
		.bDescriptorType	= USB_DT_INTF,
		.bInterfaceNumber	= 0,
		.bAlternateSetting	= 1,
		.bNumEndpoints		= 0,
		.bInterfaceClass	= 0xfe,
		.bInterfaceSubClass	= 0x01,
		.bInterfaceProtocol	= 0x02,
		.iInterface		= 6,
	},
	.dfu_riscv = {
		.bLength		= sizeof(struct usb_dfu_desc),
		.bDescriptorType	= USB_DT_DFU,
		.bmAttributes		= 0x0d,
		.wDetachTimeOut		= 1000,
		.wTransferSize		= 4096,
		.bcdDFUVersion		= 0x0101,
	},
};

static const struct usb_conf_desc * const _conf_desc_array[] = {
	&_dfu_conf_desc.conf,
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
	.idProduct		= 0x6146,
	.bcdDevice		= 0x0004,	/* v0.4 */
	.iManufacturer		= 2,
	.iProduct		= 3,
	.iSerialNumber		= 1,
	.bNumConfigurations	= num_elem(_conf_desc_array),
};

#include "usb_str_dfu.gen.h"

const struct usb_stack_descriptors dfu_stack_desc = {
	.dev    = &_dev_desc,
	.conf   = _conf_desc_array,
	.n_conf = num_elem(_conf_desc_array),
	.str    = _str_desc_array,
	.n_str  = num_elem(_str_desc_array),
};
