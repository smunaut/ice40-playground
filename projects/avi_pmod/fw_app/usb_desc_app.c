/*
 * usb_desc_app.c
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <no2usb/usb_proto.h>
#include <no2usb/usb_cdc_proto.h>
#include <no2usb/usb_dfu_proto.h>
#include <no2usb/usb_vc_proto.h>
#include <no2usb/usb.h>


usb_cdc_union_desc_def(1);

usb_vc_vc_hdr_desc_def(1);
usb_vc_vc_processing_desc_def(3);
usb_vc_vs_input_hdr_desc_def(1);
usb_vc_vs_frame_uncompressed_desc_def(1);


static const struct {
	/* Configuration */
	struct usb_conf_desc conf;

	/* DFU Runtime */
	struct {
		struct usb_intf_desc intf;
		struct usb_dfu_func_desc func;
	} __attribute__ ((packed)) dfu;

	/* CDC */
	struct {
		struct usb_intf_desc intf_ctl;
		struct usb_cdc_hdr_desc cdc_hdr;
		struct usb_cdc_acm_desc cdc_acm;
		struct usb_cdc_union_desc__1 cdc_union;
		struct usb_ep_desc ep_ctl;
		struct usb_intf_desc intf_data;
		struct usb_ep_desc ep_data_out;
		struct usb_ep_desc ep_data_in;
	} __attribute__ ((packed)) cdc;

	/* UVC source */
	struct {
		struct usb_intf_assoc_desc assoc;

		struct {
			struct usb_intf_desc intf;
			struct usb_vc_vc_hdr_desc__1 hdr;
			struct usb_vc_vc_input_desc input;
			struct usb_vc_vc_processing_desc__3 proc;
			struct usb_vc_vc_output_desc output;
			struct usb_ep_desc ep_std;
			struct usb_vc_ep_interrupt_desc ep_uvc;
		} __attribute__ ((packed)) ctrl;

		struct {
			struct usb_intf_desc intf_off;
			struct usb_vc_vs_input_hdr_desc__1 hdr;
			struct usb_vc_vs_fmt_uncompressed_desc fmt;
			struct usb_vc_vs_frame_uncompressed_desc__1 frame;
			struct usb_ep_desc ep_off;
			struct usb_intf_desc intf_on;
			struct usb_ep_desc ep_on;
		} __attribute__ ((packed)) data;
	} __attribute__ ((packed)) uvc;
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
			.wDetachTimeOut		= 1000,
			.wTransferSize		= 4096,
			.bcdDFUVersion		= 0x0101,
		},
	},
	.cdc = {
		.intf_ctl = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 1,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 1,
			.bInterfaceClass	= 0x02,
			.bInterfaceSubClass	= 0x02,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 6,
		},
		.cdc_hdr = {
			.bLength		= sizeof(struct usb_cdc_hdr_desc),
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorsubtype	= 0x00,
			.bcdCDC			= 0x0110,
		},
		.cdc_acm = {
			.bLength		= sizeof(struct usb_cdc_acm_desc),
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorsubtype	= 0x02,
			.bmCapabilities		= 0x00,
		},
		.cdc_union = {
			.bLength		= sizeof(struct usb_cdc_union_desc) + 1,
			.bDescriptorType	= USB_CS_DT_INTF,
			.bDescriptorsubtype	= 0x06,
			.bMasterInterface	= 1,
			.bSlaveInterface	= { 2 },
		},
		.ep_ctl = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x81,		/* EP 1 IN */
			.bmAttributes		= 0x03,
			.wMaxPacketSize		= 8,
			.bInterval		= 0x40,
		},
		.intf_data = {
			.bLength		= sizeof(struct usb_intf_desc),
			.bDescriptorType	= USB_DT_INTF,
			.bInterfaceNumber	= 2,
			.bAlternateSetting	= 0,
			.bNumEndpoints		= 2,
			.bInterfaceClass	= 0x0a,
			.bInterfaceSubClass	= 0x00,
			.bInterfaceProtocol	= 0x00,
			.iInterface		= 7,
		},
		.ep_data_out = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x02,		/* EP 2 OUT */
			.bmAttributes		= 0x02,
			.wMaxPacketSize		= 32,
			.bInterval		= 0x00,
		},
		.ep_data_in = {
			.bLength		= sizeof(struct usb_ep_desc),
			.bDescriptorType	= USB_DT_EP,
			.bEndpointAddress	= 0x82,		/* EP 2 IN */
			.bmAttributes		= 0x02,
			.wMaxPacketSize		= 32,
			.bInterval		= 0x00,
		},
	},
	.uvc = {
		.assoc = {
			.bLength		= sizeof(struct usb_intf_assoc_desc),
			.bDescriptorType	= USB_DT_INTF_ASSOC,
			.bFirstInterface	= 3,
			.bInterfaceCount	= 2,
			.bFunctionClass		= USB_CLS_VIDEO,
			.bFunctionSubClass	= USB_VC_SCLS_COLLECTION,
			.bFunctionProtocol	= 0x00,
			.iFunction		= 8,
		},
		.ctrl = {
			.intf = {
				.bLength		= sizeof(struct usb_intf_desc),
				.bDescriptorType	= USB_DT_INTF,
				.bInterfaceNumber	= 3,
				.bAlternateSetting	= 0,
				.bNumEndpoints		= 1,
				.bInterfaceClass	= USB_CLS_VIDEO,
				.bInterfaceSubClass	= USB_VC_SCLS_VIDEOCONTROL,
				.bInterfaceProtocol	= 0x00,
				.iInterface		= 9,
			},
			.hdr = {
				.bLength		= sizeof(struct usb_vc_vc_hdr_desc__1),
				.bDescriptorType	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VC_IDST_HEADER,
				.bcdUVC			= 0x0110,
				.wTotalLength		= sizeof(_app_conf_desc.uvc.ctrl) - sizeof(struct usb_intf_desc),
				.dwClockFrequency	= 1000000,
				.bInCollection		= 1,
				.baInterfaceNr		= { 4 },
			},
			.input = {
				.bLength		= sizeof(struct usb_vc_vc_input_desc),
				.bDescriptortype	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VC_IDST_INPUT_TERMINAL,
				.bTerminalID		= 1,
				.wTerminalType		= 0x0201,	/* Huh ... camera .. sort of */
				.bAssocTerminal		= 0,
				.iTerminal		= 0,
			},
			.proc = {
				.bLength		= sizeof(struct usb_vc_vc_processing_desc__3),
				.bDescriptortype	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VC_IDST_PROCESSING_UNIT,
				.bUnitID		= 2,
				.bSourceID		= 1,
				.wMaxMultiplier		= 0,
				.bControlSize		= 3,
				.bmControls		= { 0x00, 0x00, 0x00 },
				.iProcessing		= 0,
				.bmVideoStandards	= 0x3e,
			},
			.output = {
				.bLength		= sizeof(struct usb_vc_vc_output_desc),
				.bDescriptortype	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VC_IDST_OUTPUT_TERMINAL,
				.bTerminalID		= 3,
				.wTerminalType		= 0x0101,	/* USB Stream */
				.bAssocTerminal		= 0,
				.bSourceID		= 2,
				.iTerminal		= 0,
			},
			.ep_std = {
				.bLength		= sizeof(struct usb_ep_desc),
				.bDescriptorType	= USB_DT_EP,
				.bEndpointAddress	= 0x83,		/* EP 3 IN */
				.bmAttributes		= 0x03,		/* Interrupt */
				.wMaxPacketSize		= 16,
				.bInterval		= 8,		/* Every 256 frames */
			},
			.ep_uvc = {
				.bLength		= sizeof(struct usb_vc_ep_interrupt_desc),
				.bDescriptortype	= USB_CS_DT_EP,
				.bDescriptorSubtype	= USB_VC_EDST_INTERRUPT,
				.wMaxtransferSize	= 64,
			},
		},
		.data = {
			.intf_off = {
				.bLength		= sizeof(struct usb_intf_desc),
				.bDescriptorType	= USB_DT_INTF,
				.bInterfaceNumber	= 4,
				.bAlternateSetting	= 0,
				.bNumEndpoints		= 1,
				.bInterfaceClass	= USB_CLS_VIDEO,
				.bInterfaceSubClass	= USB_VC_SCLS_VIDEOSTREAMING,
				.bInterfaceProtocol	= 0x00,
				.iInterface		= 10,
			},
			.hdr = {
				.bLength		= sizeof(struct usb_vc_vs_input_hdr_desc__1),
				.bDescriptortype	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VS_IDST_INPUT_HEADER,
				.bNumFormats		= 1,
				.wTotalLength		= sizeof(struct usb_vc_vs_input_hdr_desc__1) + sizeof(struct usb_vc_vs_fmt_uncompressed_desc) + sizeof(struct usb_vc_vs_frame_uncompressed_desc__1),
				.bEndpointAddress	= 0x84,		/* EP 4 IN */
				.bmInfo			= 0x00,
				.bTerminalLink		= 3,
				.bStillCaptureMethod	= 1,		/* Maybe use 3 in future */
				.bTriggerSupport	= 1,
				.bTriggerUsage		= 0,
				.bControlSize		= 1,
				.bmaControls		= { 0x00 },
			},
			.fmt = {
				.bLength		= sizeof(struct usb_vc_vs_fmt_uncompressed_desc),
				.bDescriptortype	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VS_IDST_FORMAT_UNCOMPRESSED,
				.bFormatIndex		= 1,
				.bNumFrameDescriptors	= 1,
				.guidFormat		= {
					 'U',  'Y',  'V',  'Y', 0x00, 0x00, 0x10, 0x00,
					0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71,
				},
				.bBitsPerPixel		= 16,
				.bDefaultFrameIndex	= 1,
				.bAspectRatioX		= 1,
				.bAspectRatioY		= 2,
				.bmInterlaceFlags	= 0,
				.bCopyProtect		= 0,
			},
			.frame = {
				.bLength		= sizeof(struct usb_vc_vs_frame_uncompressed_desc__1),
				.bDescriptortype	= USB_CS_DT_INTF,
				.bDescriptorSubtype	= USB_VC_VS_IDST_FRAME_UNCOMPRESSED,
				.bFrameIndex		= 1,
				.bmCapabilities		= 0,
				.wWidth			= 720,
				.wHeight		= 288,
				.dwMinBitRate		= 7680000,
				.dwMaxBitRate		= 7680000,
				.dwMaxVideoFrameBufferSize = 0,
				.dwDefaultFrameInterval	= 4320000,
				.bFrameIntervalType	= 1,
				.dwFrameInterval	= { 4320000 },
			},
			.ep_off = {
				.bLength		= sizeof(struct usb_ep_desc),
				.bDescriptorType	= USB_DT_EP,
				.bEndpointAddress	= 0x84,		/* EP 4 IN */
				.bmAttributes		= 0x05,
				.wMaxPacketSize		= 0,
				.bInterval		= 1,
			},
			.intf_on = {
				.bLength		= sizeof(struct usb_intf_desc),
				.bDescriptorType	= USB_DT_INTF,
				.bInterfaceNumber	= 4,
				.bAlternateSetting	= 1,
				.bNumEndpoints		= 1,
				.bInterfaceClass	= USB_CLS_VIDEO,
				.bInterfaceSubClass	= USB_VC_SCLS_VIDEOSTREAMING,
				.bInterfaceProtocol	= 0x00,
				.iInterface		= 11,
			},
			.ep_on = {
				.bLength		= sizeof(struct usb_ep_desc),
				.bDescriptorType	= USB_DT_EP,
				.bEndpointAddress	= 0x84,		/* EP 4 IN */
				.bmAttributes		= 0x05,
				.wMaxPacketSize		= 964,
				.bInterval		= 1,
			},
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
