/*
 * usb_proto.h
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


// Descriptors
// -----------

enum usb_desc_type {
	USB_DT_DEV		= 1,
	USB_DT_CONF		= 2,
	USB_DT_STR		= 3,
	USB_DT_INTF		= 4,
	USB_DT_EP		= 5,
	USB_DT_DEV_QUAL		= 6,
	USB_DT_OTHER_SPEED_CONF	= 7,
	USB_DT_INTF_PWR		= 8,
	USB_DT_OTG		= 9,
	USB_DT_DEBUG		= 10,
	USB_DT_INTF_ASSOC	= 11,
	USB_DT_DFU		= 33,
	USB_DT_CS_INTF		= 36,
	USB_DT_CS_EP		= 37,
};

struct usb_desc_hdr {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
} __attribute__((packed));

struct usb_dev_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint16_t bcdUSB;
	uint8_t  bDeviceClass;
	uint8_t  bDeviceSubClass;
	uint8_t  bDeviceProtocol;
	uint8_t  bMaxPacketSize0;
	uint16_t idVendor;
	uint16_t idProduct;
	uint16_t bcdDevice;
	uint8_t  iManufacturer;
	uint8_t  iProduct;
	uint8_t  iSerialNumber;
	uint8_t  bNumConfigurations;
} __attribute__((packed));

struct usb_conf_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint16_t wTotalLength;
	uint8_t  bNumInterfaces;
	uint8_t  bConfigurationValue;
	uint8_t  iConfiguration;
	uint8_t  bmAttributes;
	uint8_t  bMaxPower;
} __attribute__((packed));

struct usb_intf_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bInterfaceNumber;
	uint8_t  bAlternateSetting;
	uint8_t  bNumEndpoints;
	uint8_t  bInterfaceClass;
	uint8_t  bInterfaceSubClass;
	uint8_t  bInterfaceProtocol;
	uint8_t  iInterface;
} __attribute__((packed));

struct usb_ep_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bEndpointAddress;
	uint8_t  bmAttributes;
	uint16_t wMaxPacketSize;
	uint8_t  bInterval;
} __attribute__((packed));

struct usb_intf_assoc_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bFirstInterface;
	uint8_t  bInterfaceCount;
	uint8_t  bFunctionClass;
	uint8_t  bFunctionSubClass;
	uint8_t  bFunctionProtocol;
	uint8_t  iFunction;
} __attribute__((packed));

struct usb_str_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint16_t wString[];
} __attribute__((packed));

struct usb_dfu_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bmAttributes;
	uint16_t wDetachTimeOut;
	uint16_t wTransferSize;
	uint16_t bcdDFUVersion;
} __attribute__((packed));

struct usb_cs_intf_hdr_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bDescriptorsubtype;
	uint16_t bcdCDC;
} __attribute__((packed));

struct usb_cs_intf_acm_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bDescriptorsubtype;
	uint8_t  bmCapabilities;
} __attribute__((packed));

struct usb_cs_intf_union_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bDescriptorsubtype;
	uint8_t  bMasterInterface;
	/* uint8_t  bSlaveInterface[]; */
} __attribute__((packed));

struct usb_cs_intf_call_mgmt_desc {
	uint8_t  bLength;
	uint8_t  bDescriptorType;
	uint8_t  bDescriptorsubtype;
	uint8_t  bmCapabilities;
	uint8_t  bDataInterface;
} __attribute__((packed));


// Control requests
// ----------------

struct usb_ctrl_req {
	union {
		struct {
			uint8_t  bmRequestType;
			uint8_t  bRequest;
		};
		uint16_t wRequestAndType;
	};
	uint16_t wValue;
	uint16_t wIndex;
	uint16_t wLength;
} __attribute__((packed,aligned(4)));

#define USB_REQ_RCPT_MSK	(0x1f)
#define USB_REQ_RCPT(req)	((req)->bmRequestType & USB_REQ_RCPT_MSK)
#define USB_REQ_RCPT_DEV	(0 << 0)
#define USB_REQ_RCPT_INTF	(1 << 0)
#define USB_REQ_RCPT_EP		(2 << 0)
#define USB_REQ_RCPT_OTHER	(3 << 0)

#define USB_REQ_TYPE_MSK	(0x60)
#define USB_REQ_TYPE(req)	((req)->bmRequestType & USB_REQ_TYPE_MSK)
#define USB_REQ_TYPE_STD	(0 << 5)
#define USB_REQ_TYPE_CLASS	(1 << 5)
#define USB_REQ_TYPE_VENDOR	(2 << 5)
#define USB_REQ_TYPE_RSVD	(3 << 5)

#define USB_REQ_TYPE_RCPT(req)	((req)->bmRequestType & (USB_REQ_RCPT_MSK | USB_REQ_TYPE_MSK))

#define USB_REQ_READ		(1 << 7)
#define USB_REQ_IS_READ(req)	(  (req)->bmRequestType & USB_REQ_READ )
#define USB_REQ_IS_WRITE(req)	(!((req)->bmRequestType & USB_REQ_READ))

	/* wRequestAndType */
#define USB_RT_GET_STATUS_DEV		(( 0 << 8) | 0x80)
#define USB_RT_GET_STATUS_INTF		(( 0 << 8) | 0x81)
#define USB_RT_GET_STATUS_EP		(( 0 << 8) | 0x82)
#define USB_RT_CLEAR_FEATURE_DEV	(( 1 << 8) | 0x00)
#define USB_RT_CLEAR_FEATURE_INTF	(( 1 << 8) | 0x01)
#define USB_RT_CLEAR_FEATURE_EP		(( 1 << 8) | 0x02)
#define USB_RT_SET_FEATURE_DEV		(( 3 << 8) | 0x00)
#define USB_RT_SET_FEATURE_INTF		(( 3 << 8) | 0x01)
#define USB_RT_SET_FEATURE_EP		(( 3 << 8) | 0x02)
#define USB_RT_SET_ADDRESS		(( 5 << 8) | 0x00)
#define USB_RT_GET_DESCRIPTOR		(( 6 << 8) | 0x80)
#define USB_RT_SET_DESCRIPTOR		(( 7 << 8) | 0x00)
#define USB_RT_GET_CONFIGURATION	(( 8 << 8) | 0x80)
#define USB_RT_SET_CONFIGURATION	(( 9 << 8) | 0x00)
#define USB_RT_GET_INTERFACE		((10 << 8) | 0x81)
#define USB_RT_SET_INTERFACE		((11 << 8) | 0x01)
#define USB_RT_SYNCHFRAME		((12 << 8) | 0x82)
