/*
 * usb_desc_app.c
 *
 * Copyright (C) 2020 Sylvain Munaut
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

#include <no2usb/usb_proto.h>
#include <no2usb/usb_ac_proto.h>
#include <no2usb/usb_cdc_proto.h>
#include <no2usb/usb_dfu_proto.h>
#include <no2usb/usb.h>


usb_cdc_union_desc_def(1);
usb_ac_ac_hdr_desc_def(2);
usb_ac_ac_feature_desc_def(4);
usb_ac_as_fmt_type1_desc_def(3);

static const struct {
	/* Configuration */
	struct usb_conf_desc conf;

	/* DFU Runtime */
	struct {
		struct usb_intf_desc intf;
		struct usb_dfu_func_desc func;
	} __attribute__ ((packed)) dfu;

	/* Audio Control Interface */
	struct {
		struct usb_intf_desc intf;
		struct usb_ac_ac_hdr_desc__2 hdr;
		struct usb_ac_ac_input_desc it_phone;
		struct usb_ac_ac_feature_desc__4 feat_in;
		struct usb_ac_ac_output_desc ot_usb;
		struct usb_ac_ac_input_desc it_usb;
		struct usb_ac_ac_feature_desc__4 feat_out;
		struct usb_ac_ac_output_desc ot_phone;
	} __attribute__ ((packed)) audio_ctl;

	/* Audio Inpput Streaming Interface */
	struct {
		struct usb_intf_desc intf[2];
		struct usb_ac_as_general_desc general;
		struct usb_ac_as_fmt_type1_desc__3 fmt;
		struct usb_cc_ep_desc ep_data;
		struct usb_ac_as_ep_general_desc ep_gen;
	} __attribute__ ((packed)) audio_stream_in;

	/* Audio Output Streaming Interface */
	struct {
		struct usb_intf_desc intf[2];
		struct usb_ac_as_general_desc general;
		struct usb_ac_as_fmt_type1_desc__3 fmt;
		struct usb_cc_ep_desc ep_data;
		struct usb_ac_as_ep_general_desc ep_gen;
		struct usb_cc_ep_desc ep_sync;
	} __attribute__ ((packed)) audio_stream_out;

	/* USB CDC DLM */
	struct {
		struct usb_intf_desc intf;
		struct usb_cdc_hdr_desc hdr;
		struct usb_cdc_dlm_desc dlm;
		struct usb_cdc_union_desc__1 ud;
		struct usb_ep_desc ep;
	} __attribute__ ((packed)) cdc_dlm;

} __attribute__ ((packed)) _app_conf_desc = {
	.conf = {
		.bLength                = sizeof(struct usb_conf_desc),
		.bDescriptorType        = USB_DT_CONF,
		.wTotalLength           = sizeof(_app_conf_desc),
		.bNumInterfaces         = 5,
		.bConfigurationValue    = 1,
		.iConfiguration         = 4,
		.bmAttributes           = 0x80,
		.bMaxPower              = 0x32, /* 100 mA */
	},
	.dfu = {
		.intf = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 0,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 0,
			.bInterfaceClass	= 0xfe,
			.bInterfaceSubClass	= 0x01,
			.bInterfaceProtocol	= 0x01,
			.iInterface		= 5,
		},
		.func = {
			.bLength		= sizeof(struct usb_dfu_func_desc),
			.bDescriptorType	= USB_DFU_DT_FUNC,
			.bmAttributes		= 0x0d,
			.wDetachTimeOut		= 0,
			.wTransferSize		= 4096,
			.bcdDFUVersion		= 0x0101,
		},
	},
	.audio_ctl = {
		.intf = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 1,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 0,
			.bInterfaceClass	= USB_CLS_AUDIO,
			.bInterfaceSubClass	= USB_AC_SCLS_AUDIOCONTROL,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 0,
		},
		.hdr = {
			.bLength		= sizeof(struct usb_ac_ac_hdr_desc__2),
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_HEADER,
			.bcdADC			= 0x0100,
			.wTotalLength		= sizeof(_app_conf_desc.audio_ctl) - sizeof(struct usb_intf_desc),
			.bInCollection		= 2,
			.baInterfaceNr		= { 0x02, 0x03 },
		},
		.it_phone = {	/* ID 1 */
			.bLength		= sizeof(struct usb_ac_ac_input_desc),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_INPUT_TERMINAL,
			.bTerminalID		= 1,
			.wTerminalType		= 0x0501, /* Phone Line */
			.bAssocTerminal		= 6,
			.bNrChannels		= 1,
			.wChannelConfig		= 0x0000,
			.iChannelNames		= 0,
			.iTerminal		= 0,
		},
		.feat_in = {	/* ID 2 */
			.bLength		= sizeof(struct usb_ac_ac_feature_desc__4),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_FEATURE_UNIT,
			.bUnitID		= 2,
			.bSourceID		= 1,
			.bControlSize		= 2,
			.bmaControls		= {
				U16_TO_U8_LE(0x0003),	// Mute + Volume
				U16_TO_U8_LE(0x0000),	// n/a
			},
			.iFeature		= 6,
		},
		.ot_usb = {	/* ID 3 */
			.bLength		= sizeof(struct usb_ac_ac_output_desc),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_OUTPUT_TERMINAL,
			.bTerminalID		= 3,
			.wTerminalType		= 0x0101, /* USB Streaming */
			.bAssocTerminal		= 4,
			.bSourceID		= 2,
			.iTerminal		= 0,
		},
		.it_usb = {	/* ID 4 */
			.bLength		= sizeof(struct usb_ac_ac_input_desc),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_INPUT_TERMINAL,
			.bTerminalID		= 4,
			.wTerminalType		= 0x0101, /* USB Streaming */
			.bAssocTerminal		= 3,
			.bNrChannels		= 1,
			.wChannelConfig		= 0x0000,
			.iChannelNames		= 0,
			.iTerminal		= 0,
		},
		.feat_out = {	/* ID 5 */
			.bLength		= sizeof(struct usb_ac_ac_feature_desc__4),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_FEATURE_UNIT,
			.bUnitID		= 5,
			.bSourceID		= 4,
			.bControlSize		= 2,
			.bmaControls		= {
				U16_TO_U8_LE(0x0003),	// Mute + Volume
				U16_TO_U8_LE(0x0000),	// n/a
			},
			.iFeature		= 7,
		},
		.ot_phone = {	/* ID 6 */
			.bLength		= sizeof(struct usb_ac_ac_output_desc),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AC_IDST_OUTPUT_TERMINAL,
			.bTerminalID		= 6,
			.wTerminalType		= 0x0501, /* Phone Line */
			.bAssocTerminal		= 1,
			.bSourceID		= 5,
			.iTerminal		= 0,
		},
	},
	.audio_stream_in = {
		.intf[0] = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 2,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 0,
			.bInterfaceClass	= USB_CLS_AUDIO,
			.bInterfaceSubClass	= USB_AC_SCLS_AUDIOSTREAMING,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 0,
		},
		.intf[1] = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 2,
			.bAlternateSetting	= 1,
			.bNumEndpoints		= 1,
			.bInterfaceClass	= USB_CLS_AUDIO,
			.bInterfaceSubClass	= USB_AC_SCLS_AUDIOSTREAMING,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 0,
		},
		.general = {
			.bLength		= sizeof(struct usb_ac_as_general_desc),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AS_IDST_GENERAL,
			.bTerminalLink		= 3,
			.bDelay			= 0,
			.wFormatTag		= 0x0001,	/* PCM */
		},
		.fmt = {
			.bLength		= sizeof(struct usb_ac_as_fmt_type1_desc__3),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AS_IDST_FORMAT_TYPE,
			.bFormatType		= 1,
			.bNrChannels		= 1,
			.bSubframeSize		= 2,
			.bBitResolution		= 16,
			.bSamFreqType		= 1,
			.tSamFreq		= {
				U24_TO_U8_LE(8000),
			},
		},
		.ep_data = {
			.bLength		= sizeof(struct usb_cc_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x81,		/* 1 IN */
			.bmAttributes		= 0x05,		/* Data, Async, Isoc */
			.wMaxPacketSize		= 120,
			.bInterval		= 1,
			.bRefresh		= 0,
			.bSynchAddress		= 0,
		},
		.ep_gen = {
			.bLength		= sizeof(struct usb_ac_as_ep_general_desc),
			.bDescriptortype	= USB_CS_DT_EP,
			.bDescriptorSubtype	= USB_AC_EDST_GENERAL,
			.bmAttributes		= 0x00,
			.bLockDelayUnits	= 0,
			.wLockDelay		= 0,
		},
	},
	.audio_stream_out = {
		.intf[0] = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 3,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 0,
			.bInterfaceClass	= USB_CLS_AUDIO,
			.bInterfaceSubClass	= USB_AC_SCLS_AUDIOSTREAMING,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 0,
		},
		.intf[1] = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 3,
			.bAlternateSetting	= 1,
			.bNumEndpoints		= 2,
			.bInterfaceClass	= USB_CLS_AUDIO,
			.bInterfaceSubClass	= USB_AC_SCLS_AUDIOSTREAMING,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 0,
		},
		.general = {
			.bLength		= sizeof(struct usb_ac_as_general_desc),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AS_IDST_GENERAL,
			.bTerminalLink		= 4,
			.bDelay			= 0,
			.wFormatTag		= 0x0001,	/* PCM */
		},
		.fmt = {
			.bLength		= sizeof(struct usb_ac_as_fmt_type1_desc__3),
			.bDescriptortype	= USB_CS_DT_INTF,
			.bDescriptorSubtype	= USB_AC_AS_IDST_FORMAT_TYPE,
			.bFormatType		= 1,
			.bNrChannels		= 1,
			.bSubframeSize		= 2,
			.bBitResolution		= 16,
			.bSamFreqType		= 1,
			.tSamFreq		= {
				U24_TO_U8_LE(8000),
			},
		},
		.ep_data = {
			.bLength		= sizeof(struct usb_cc_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x01,		/* 1 OUT */
			.bmAttributes		= 0x05,		/* Data, Async, Isoc */
			.wMaxPacketSize		= 120,
			.bInterval		= 1,
			.bRefresh		= 0,
			.bSynchAddress		= 0x82,
		},
		.ep_gen = {
			.bLength		= sizeof(struct usb_ac_as_ep_general_desc),
			.bDescriptortype	= USB_CS_DT_EP,
			.bDescriptorSubtype	= USB_AC_EDST_GENERAL,
			.bmAttributes		= 0x00,
			.bLockDelayUnits	= 0,
			.wLockDelay		= 0,
		},
		.ep_sync = {
			.bLength		= sizeof(struct usb_cc_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x82,		/* 2 IN */
			.bmAttributes		= 0x11,		/* Feedback, Isoc */
			.wMaxPacketSize		= 8,
			.bInterval		= 1,
			.bRefresh		= 1,
			.bSynchAddress		= 0,
		},
	},
	.cdc_dlm = {
		.intf = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 4,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 1,
			.bInterfaceClass	= USB_CLS_COMMUNICATIONS,
			.bInterfaceSubClass	= USB_CDC_SCLS_DLCM,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 0,
		},
		.hdr = {
			.bLength		= sizeof(struct usb_cdc_hdr_desc),
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorsubtype	= USB_CDC_DST_HEADER,
			.bcdCDC			= 0x0110,
		},
		.dlm = {
			.bLength		= sizeof(struct usb_cdc_dlm_desc),
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorsubtype 	= USB_CDC_DST_DLM,
			.bmCapabilities		= 0x02,
		},
		.ud = {
			.bLength		= sizeof(struct usb_cdc_union_desc) + 1,
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorsubtype	= USB_CDC_DST_UNION,
			.bMasterInterface	= 4,
			.bSlaveInterface	= { 1 },
		},
		.ep = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x83,		/* 3 IN */
			.bmAttributes		= 0x03,		/* Interupt */
			.wMaxPacketSize		= 8,
			.bInterval		= 32,
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
	.idProduct		= 0x6175,
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
