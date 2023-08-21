/*
 * cdc-dlm.c
 *
 * CDC Direct Line Modem control for MC97 modem
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

#include <no2usb/usb.h>
#include <no2usb/usb_hw.h>
#include <no2usb/usb_priv.h>
#include <no2usb/usb_cdc_proto.h>

#include "cdc-dlm.h"
#include "mc97.h"


#define INTF_CDC_DLM		4
#define EP_CDC_DLM_NOTIF	0x83


static void
dlm_send_notif_ring_detect(void)
{
	const struct usb_ctrl_req notif = {
		.bmRequestType	= USB_REQ_READ | USB_REQ_TYPE_CLASS | USB_REQ_RCPT_INTF,
		.bRequest	= USB_NOTIF_CDC_RING_DETECT,
		.wValue		= 0,
		.wIndex		= INTF_CDC_DLM,
		.wLength	= 0,
	};

	usb_data_write(usb_ep_regs[3].in.bd[0].ptr, &notif, sizeof(struct usb_ctrl_req));
	usb_ep_regs[3].in.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(sizeof(struct usb_ctrl_req));
}


static enum usb_fnd_resp
dlm_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	/* Check it's a class request to an interface */
	if (USB_REQ_TYPE_RCPT(req) != (USB_REQ_TYPE_CLASS | USB_REQ_RCPT_INTF))
		return USB_FND_CONTINUE;

	/* Check it's for the DLM interface */
	if ((req->wIndex & 0xff) != INTF_CDC_DLM)
		return USB_FND_CONTINUE;

	switch (req->wRequestAndType)
	{
	case USB_RT_CDC_SET_HOOK_STATE:
		switch (req->wValue) {
		case 0:  mc97_set_hook(ON_HOOK);   break;
		case 1:  mc97_set_hook(OFF_HOOK);  break;
		case 2:  mc97_set_hook(CALLER_ID); break;
		default: return USB_FND_ERROR;
		}
		return USB_FND_SUCCESS;

	case USB_RT_CDC_SET_AUX_LINE_STATE:
		/* Control the relay with that */
		mc97_set_aux_relay(!req->wValue);
		return USB_FND_SUCCESS;

	case USB_RT_CDC_RING_AUX_JACK:
		/* Can't do that ... */
		return USB_FND_SUCCESS;

	/* Pulse is not supported yet (also disabled in bmCapabilities) */
	case USB_RT_CDC_PULSE_SETUP:
	case USB_RT_CDC_SEND_PULSE:
	case USB_RT_CDC_SET_PULSE_TIME:
		return USB_FND_ERROR;

	/* TODO: Maybe implement SET_COMM_FEATURE for country selection ? */
	/* In theory not part of DLM but it's the closest to a standard
	 * thing to support tweaking the codec params to match local specs
	 * for a phone line */
	}

	return USB_FND_ERROR;
}

static enum usb_fnd_resp
dlm_set_conf(const struct usb_conf_desc *conf)
{
	const struct usb_intf_desc *intf;

	intf = usb_desc_find_intf(conf, INTF_CDC_DLM, 0, NULL);
        usb_ep_boot(intf, EP_CDC_DLM_NOTIF, false);

	return USB_FND_SUCCESS;
}


static struct usb_fn_drv _dlm_drv = {
	.ctrl_req = dlm_ctrl_req,
	.set_conf = dlm_set_conf,
};


void
cdc_dlm_init(void)
{
	/* Register function driver */
	usb_register_function_driver(&_dlm_drv);
}

void
cdc_dlm_poll(void)
{
	/* Nothing to do for now */

	/* TODO:
	 *  - Pulse timing when pulse is implemented
	 *  - Ring detection (note that it's not simply calling
	 *    mc97_get_ring_detect(), it must be analyzed to see if the
	 *    ringing frequency matches something between 10 and 100 Hz)
	 */
}
