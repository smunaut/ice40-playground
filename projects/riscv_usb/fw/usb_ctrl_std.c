/*
 * usb_ctrl_std.c
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

	/* Internal helpers */

static const struct usb_intf_desc *
_find_intf(uint8_t idx)
{
	const struct usb_conf_desc *conf = g_usb.conf;
	const struct usb_intf_desc *intf = NULL;
	const void *sod, *eod;

	if (!conf)
		return NULL;

	sod = conf;
	eod = sod + conf->wTotalLength;

	while (1) {
		sod = usb_desc_find(sod, eod, USB_DT_INTF);
		if (!sod)
			break;

		intf = (void*)sod;
		if (intf->bInterfaceNumber == idx)
			return intf;
	}

	return NULL;
}

static const struct usb_intf_desc *
_find_intf_alt(uint8_t idx, uint8_t alt, const struct usb_intf_desc *start)
{
	const struct usb_conf_desc *conf = g_usb.conf;
	const struct usb_intf_desc *intf = NULL;
	const void *sod, *eod;

	if (!conf)
		return NULL;

	sod = conf;
	eod = sod + conf->wTotalLength;

	if (start)
		sod = (const void *)start;

	while (sod != NULL) {
		intf = (void*)sod;
		if ((intf->bInterfaceNumber == idx) && (intf->bAlternateSetting == alt))
			return intf;
		sod = usb_desc_find(usb_desc_next(sod), eod, USB_DT_INTF);
	}

	return NULL;
}


	/* Control Request implementation */

static bool
_get_status_dev(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	xfer->data[0] = 0x00;	/* No remote wakeup, bus-powered */
	xfer->data[1] = 0x00;
	xfer->len = 2;
	return true;
}

static bool
_get_status_intf(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	/* Check interface exits */
	if (_find_intf(req->wIndex) == NULL)
		return false;

	/* Nothing to return really */
	xfer->data[0] = 0x00;
	xfer->data[1] = 0x00;
	xfer->len = 2;
	return true;
}

static bool
_get_status_ep(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	uint8_t ep = req->wIndex;

	if (!usb_ep_is_configured(ep))
		return false;

	xfer->data[0] = usb_ep_is_halted(ep) ? 0x01 : 0x00;
	xfer->data[1] = 0x00;
	xfer->len = 2;
	return true;
}

static bool
_clear_feature_dev(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	/* No support for any device feature */
	return false;
}

static bool
_clear_feature_intf(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	/* No support for any interface feature */
	return false;
}

static bool
_clear_feature_ep(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	uint8_t ep = req->wIndex;

	/* Only support ENDPOINT_HALT feature on non-zero EP that exist
	 * and only when in CONFIGURED state */
	if ((usb_get_state() < USB_DS_CONFIGURED) ||
	    (req->wValue != 0) ||	/* ENDPOINT_HALT */
	    (ep == 0) ||
	    (!usb_ep_is_configured(ep)))
		return false;

	/* Resume the EP */
	return usb_ep_resume(ep);
}

static bool
_set_feature_dev(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	/* No support for any device feature */
	return false;
}

static bool
_set_feature_intf(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	/* No support for any interface feature */
	return false;
}

static bool
_set_feature_ep(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	uint8_t ep = req->wIndex;

	/* Only support ENDPOINT_HALT feature on non-zero EP that exist
	 * and only when in CONFIGURED state */
	if ((usb_get_state() < USB_DS_CONFIGURED) ||
	    (req->wValue != 0) ||	/* ENDPOINT_HALT */
	    (ep == 0) ||
	    (!usb_ep_is_configured(ep)))
		return false;

	/* Halt the EP */
	return usb_ep_halt(ep);
}

static bool
_set_addr_done(struct usb_xfer *xfer)
{
	struct usb_ctrl_req *req = xfer->cb_ctx;
	usb_set_address(req->wValue);
	return true;
}

static bool
_set_address(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	xfer->len = 0;
	xfer->cb_done = _set_addr_done;
	xfer->cb_ctx = req;
	return true;
}

static bool
_get_descriptor(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	int idx = req->wValue & 0xff;

	xfer->data = NULL;

	switch (req->wValue & 0xff00)
	{
	case 0x0100:	/* Device */
		xfer->data = (void*)g_usb.stack_desc->dev;
		xfer->len  = g_usb.stack_desc->dev->bLength;
		break;

	case 0x0200:	/* Configuration */
		if (idx < g_usb.stack_desc->n_conf) {
			xfer->data = (void*)g_usb.stack_desc->conf[idx];
			xfer->len  = g_usb.stack_desc->conf[idx]->wTotalLength;
		}
		break;

	case 0x0300:	/* String */
		if (idx < g_usb.stack_desc->n_str) {
			xfer->data = (void*)g_usb.stack_desc->str[idx];
			xfer->len  = g_usb.stack_desc->str[idx]->bLength;
		}
		break;
	}

	return xfer->data != NULL;
}

static bool
_get_configuration(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	xfer->data[0] = g_usb.conf ? g_usb.conf->bConfigurationValue : 0;
	xfer->len = 1;
	return true;
}

static bool
_set_configuration(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	const struct usb_conf_desc *conf = NULL;
	enum usb_dev_state new_state;

	/* Handle the 'zero' case first */
	if (req->wValue == 0) {
		new_state = USB_DS_DEFAULT;
	} else {
		/* Find the requested config */
		for (int i=0; i<g_usb.stack_desc->n_conf; i++)
			if (g_usb.stack_desc->conf[i]->bConfigurationValue == req->wValue) {
				conf = g_usb.stack_desc->conf[i];
				break;
			}

		if (!conf)
			return false;

		new_state = USB_DS_CONFIGURED;
	}

	/* Update state */
		/* FIXME: configure all endpoint */
	g_usb.conf = conf;
	g_usb.intf_alt = 0;
	usb_set_state(new_state);
	usb_dispatch_set_conf(g_usb.conf);

	return true;
}

static bool
_get_interface(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	const struct usb_intf_desc *intf;
	uint8_t idx = req->wIndex;
	uint8_t alt = req->wValue;
	enum usb_fnd_resp rv;

	/* Check interface exits */
	intf = _find_intf(idx);
	if (intf == NULL)
		return false;

	/* Fast path */
	if (!(g_usb.intf_alt & (1 << idx))) {
		xfer->data[0] = 0x00;
		xfer->len = 1;
		return true;
	}

	/* Dispatch for an answer */
	rv = usb_dispatch_get_intf(intf, &alt);
	if (rv != USB_FND_SUCCESS)
		return false;

	/* Setup response */
	xfer->data[0] = alt;
	xfer->len = 1;

	return true;
}

static bool
_set_interface(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	const struct usb_intf_desc *intf_base, *intf_alt;
	uint8_t idx = req->wIndex;
	uint8_t alt = req->wValue;
	enum usb_fnd_resp rv;

	/* Check interface exits and its altsettings */
	intf_base = _find_intf(req->wIndex);
	if (intf_base == NULL)
		return false;

	if (intf_base->bAlternateSetting == alt) {
		intf_alt = intf_base;
	} else {
		intf_alt = _find_intf_alt(idx, alt, intf_base);
		if (!intf_alt)
			return false;
	}

	/* Disable fast path */
	g_usb.intf_alt |= (1 << idx);

	/* Dispatch enable */
	rv = usb_dispatch_set_intf(intf_base, intf_alt);
	if (rv != USB_FND_SUCCESS)
		return false;

	return true;
}


	/* Control Request dispatch */

static enum usb_fnd_resp
usb_ctrl_std_handle(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	bool rv = false;

	/* Main dispatch */
	switch (req->wRequestAndType)
	{
	case USB_RT_GET_STATUS_DEV:
		rv = _get_status_dev(req, xfer);
		break;

	case USB_RT_GET_STATUS_INTF:
		rv = _get_status_intf(req, xfer);
		break;

	case USB_RT_GET_STATUS_EP:
		rv = _get_status_ep(req, xfer);
		break;

	case USB_RT_CLEAR_FEATURE_DEV:
		rv = _clear_feature_dev(req, xfer);
		break;

	case USB_RT_CLEAR_FEATURE_INTF:
		rv = _clear_feature_intf(req, xfer);
		break;

	case USB_RT_CLEAR_FEATURE_EP:
		rv = _clear_feature_ep(req, xfer);
		break;

	case USB_RT_SET_FEATURE_DEV:
		rv = _set_feature_dev(req, xfer);
		break;

	case USB_RT_SET_FEATURE_INTF:
		rv = _set_feature_intf(req, xfer);
		break;

	case USB_RT_SET_FEATURE_EP:
		rv = _set_feature_ep(req, xfer);
		break;

	case USB_RT_SET_ADDRESS:
		rv = _set_address(req, xfer);
		break;

	case USB_RT_GET_DESCRIPTOR:
		rv = _get_descriptor(req, xfer);
		break;

	case USB_RT_GET_CONFIGURATION:
		rv = _get_configuration(req, xfer);
		break;

	case USB_RT_SET_CONFIGURATION:
		rv = _set_configuration(req, xfer);
		break;

	case USB_RT_GET_INTERFACE:
		rv = _get_interface(req, xfer);
		break;

	case USB_RT_SET_INTERFACE:
		rv = _set_interface(req, xfer);
		break;

	default:
		return USB_FND_CONTINUE;
	}

	return rv ? USB_FND_SUCCESS : USB_FND_ERROR;
}

struct usb_fn_drv usb_ctrl_std_drv = {
	.ctrl_req = usb_ctrl_std_handle,
};
