/*
 * audio.c
 *
 * USB Audio class firmware
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

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "console.h"
#include "mc97.h"

#include <no2usb/usb.h>
#include <no2usb/usb_ac_proto.h>
#include <no2usb/usb_dfu_rt.h>
#include <no2usb/usb_hw.h>
#include <no2usb/usb_priv.h>

#include "config.h"


#define INTF_AUDIO_CONTROL	1
#define INTF_AUDIO_DATA_IN	2
#define INTF_AUDIO_DATA_OUT	3
#define UNIT_FEAT_PCM_IN	2
#define UNIT_FEAT_PCM_OUT	5

#define PKT_SIZE_SAMP  60
#define PKT_SIZE_BYTE 120


// PCM Audio
// ---------------------------------------------------------------------------

static struct {
	bool    active;
	uint8_t bdi;
} g_pcm[2];


static void
pcm_init(void)
{
	/* Local state */
	memset(&g_pcm, 0x00, sizeof(g_pcm));

	/* Init MC97 */
	mc97_init();
}


// PCM Audio USB helpers
// ---------------------------------------------------------------------------

static int
_idx_from_req(struct usb_ctrl_req *req)
{
	int unit_id = (req->wIndex >> 8) & 0xff;
	int chan    = req->wValue & 0xff;

	if (chan != 0)
		return -1;

	switch (unit_id)
	{
	case UNIT_FEAT_PCM_IN:  return 0;
	case UNIT_FEAT_PCM_OUT: return 1;
	}

	return -1;
}


// PCM Audio USB data
// ---------------------------------------------------------------------------

static void
pcm_usb_configure(const struct usb_conf_desc *conf)
{
	const struct usb_intf_desc *intf;

	/* Reset state */
	g_pcm[0].bdi = 0;
	g_pcm[1].bdi = 0;

	/* Boot PCM input */
	intf = usb_desc_find_intf(conf, INTF_AUDIO_DATA_IN, 0, NULL);
        usb_ep_boot(intf, 0x81, true);

	/* Boot PCM output */
	intf = usb_desc_find_intf(conf, INTF_AUDIO_DATA_OUT, 0, NULL);
        usb_ep_boot(intf, 0x01, true);
        usb_ep_boot(intf, 0x82, false);

	/* MC97 flow reset */
	mc97_flow_rx_reset();
	mc97_flow_tx_reset();
}

static bool
pcm_usb_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	switch (base->bInterfaceNumber)
	{
	case INTF_AUDIO_DATA_IN:
		/* If same state, don't do anything */
		if (sel->bAlternateSetting == g_pcm[0].active)
			break;

		g_pcm[0].active = sel->bAlternateSetting;

		/* Reset BDI and reconfigure EPs */
		g_pcm[0].bdi = 0;
		usb_ep_reconf(sel, 0x81);

		/* MC97 data flow */
		if (!g_pcm[0].active)
			mc97_flow_rx_reset();
		else
			mc97_flow_rx_start();

		break;

	case INTF_AUDIO_DATA_OUT:
		/* If same state, don't do anything */
		if (sel->bAlternateSetting == g_pcm[1].active)
			break;

		g_pcm[1].active = sel->bAlternateSetting;

		/* Reset BDI and reconfigure EPs */
		g_pcm[1].bdi = 0;
		usb_ep_reconf(sel, 0x01);
		usb_ep_reconf(sel, 0x82);

		/* MC97 data flow */
		if (!g_pcm[1].active)
			mc97_flow_tx_reset();

		/* If active, pre-queue two buffers */
		if (g_pcm[1].active) {
			usb_ep_regs[1].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(PKT_SIZE_BYTE);
			usb_ep_regs[1].out.bd[1].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(PKT_SIZE_BYTE);
		}

		break;

	default:
		return false;
	}

	return true;
}

static bool
pcm_usb_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	switch (base->bInterfaceNumber)
	{
	case INTF_AUDIO_DATA_IN:
		*alt = g_pcm[0].active;
		break;

	case INTF_AUDIO_DATA_OUT:
		*alt = g_pcm[1].active;
		break;

	default:
		return false;
	}

	return true;
}


static void
pcm_poll_feedback_ep(void)
{
	static int rate;
	uint32_t val;

	/* If not active, reset state */
	if (!g_pcm[1].active) {
		rate = 8 * 16384;
		return;
	}

	/* Fetch current level and flow active status */
	int lvl     = mc97_flow_tx_level();
	bool active = mc97_flow_tx_active();

	/* If flow isn't running, don't run the algo */
	if (!active)
		return;

	/* If previous packet isn't sent, don't run the algo */
	if ((usb_ep_regs[2].in.bd[0].csr & USB_BD_STATE_MSK) == USB_BD_STATE_RDY_DATA)
		return;

	/* Level alerts */
	if ((lvl < 32) || (lvl > 224))
		printf("LEVEL ALERT: %d (%d)\n", lvl, (rate >> 14));


	/* Adapt the rate depending on fifo level */
	rate += ((MC97_FIFO_SIZE / 2) - lvl) << 4;

	if (rate > (9 * 16384))
		rate = 9 * 16384;
	else if (rate < (7 * 16384))
		rate =  7 * 16384;

	/* Set rate */
	val = rate;

	/* Prepare buffer */
	usb_data_write(usb_ep_regs[2].in.bd[0].ptr, &val, 4);
	usb_ep_regs[2].in.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(3);
}


static void
pcm_poll_in(void)
{
	int16_t buf[PKT_SIZE_SAMP];

	/* Active ? */
	if (!g_pcm[0].active)
		return;

	/* Fill as many BDs as we can */
	while (1) {
		uint32_t csr = usb_ep_regs[1].in.bd[g_pcm[0].bdi].csr;
		uint32_t ptr = usb_ep_regs[1].in.bd[g_pcm[0].bdi].ptr;

		/* Is that BD free ? */
		if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_RDY_DATA)
			break;

		/* Read data from MC97 link */
		int n = mc97_flow_rx_pull(buf, PKT_SIZE_SAMP);
		if (!n)
			break;

		/* Submit what we got */
		usb_data_write(ptr, buf, PKT_SIZE_BYTE);
		usb_ep_regs[1].in.bd[g_pcm[0].bdi].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(n*2);
		g_pcm[0].bdi ^= 1;

		/* If packet wasn't full, wait for the next iteration */
		if (n < PKT_SIZE_SAMP)
			break;
	}
}

static void
pcm_poll_out(void)
{
	int16_t buf[PKT_SIZE_SAMP];

	/* Active ? */
	if (!g_pcm[1].active)
		return;

	/* Starting level */
	int  lvl    = mc97_flow_tx_level();
	bool active = mc97_flow_tx_active();

	/* Refill process ? */
	if (!lvl & active)
		mc97_flow_tx_stop();

	/* Empty as many BDs as we can */
	while (1) {
		uint32_t csr = usb_ep_regs[1].out.bd[g_pcm[1].bdi].csr;
		uint32_t ptr = usb_ep_regs[1].out.bd[g_pcm[1].bdi].ptr;

		/* Is that BD pending ? */
		if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_RDY_DATA)
			break;

		/* Pull valid data */
		if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
		{
			int n = ((csr & USB_BD_LEN_MSK) - 2) / 2; /* Reported length includes CRC */

			/* If it doesn't fit, we're done for now */
			if ((lvl + n) > MC97_FIFO_SIZE)
				break;

			lvl += n;

			/* Read and push */
			if (n) {
				usb_data_read(buf, ptr, PKT_SIZE_BYTE);
				mc97_flow_tx_push(buf, n);
			}
		}

		/* Reprepare and move on */
		usb_ep_regs[1].out.bd[g_pcm[1].bdi].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(PKT_SIZE_BYTE);
		g_pcm[1].bdi ^= 1;
	}

	/* Delayed enable */
	if ((lvl > (MC97_FIFO_SIZE/2)) && !active)
		mc97_flow_tx_start();
}

static void
pcm_poll(void)
{
	pcm_poll_in();
	pcm_poll_out();
	pcm_poll_feedback_ep();
}


// PCM Audio USB control
// ---------------------------------------------------------------------------

static bool
pcm_usb_mute_set(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	int idx = _idx_from_req(req);

	switch (idx) {
	case 0: mc97_set_rx_mute(data[0]); return true;
	case 1: mc97_set_tx_mute(data[0]); return true;
	}

	return false;
}

static bool
pcm_usb_mute_get(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	int idx = _idx_from_req(req);

	switch (idx) {
	case 0: data[0] = mc97_get_rx_mute(); return true;
	case 1: data[0] = mc97_get_tx_mute(); return true;
	}

	return false;
}

#define BOUND(x, a, b) (((x)<(a))?(a):(((x)>(b))?(b):(x)))

static bool
pcm_usb_volume_set(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	int idx = _idx_from_req(req);
	int16_t vol = *((int16_t*)data);

	switch (idx) {
	case 0:
		vol = BOUND(vol, 0, 5760) >> 7;
		mc97_set_rx_gain(vol);
		return true;

	case 1:
		vol = BOUND(-vol, 0, 5760) >> 7;
		mc97_set_tx_attenuation(vol);
		return true;
	}

	return false;
}

static bool
pcm_usb_volume_get(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	int idx = _idx_from_req(req);

	switch (idx) {
	case 0: *((int16_t*)data) =  (mc97_get_rx_gain()        << 7); return true;
	case 1: *((int16_t*)data) = -(mc97_get_tx_attenuation() << 7); return true;
	}

	return false;
}

static bool
pcm_usb_volume_min(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	const int16_t max[] = { 0 /* 0 dB gain */, -5760 /* 22.5 dB attenuation */ };
	int idx;

	if ((idx = _idx_from_req(req)) < 0)
		return false;

	*((int16_t*)data) = max[idx];

	return true;
}

static bool
pcm_usb_volume_max(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	const int16_t max[] = { 5760 /* 22.5 dB gain */, 0 /* 0 dB attenuation */ };
	int idx;

	if ((idx = _idx_from_req(req)) < 0)
		return false;

	*((int16_t*)data) = max[idx];

	return true;
}

static bool
pcm_usb_volume_res(struct usb_ctrl_req *req, uint8_t *data, int *len)
{
	const int16_t res[] = { 384, 384 }; /* 1.5 dB resolution */
	int idx;

	if ((idx = _idx_from_req(req)) < 0)
		return false;

	*((int16_t*)data) = res[idx];

	return true;
}


// Shared USB driver
// ---------------------------------------------------------------------------

/* Control handler structs */

typedef bool (*usb_audio_control_fn)(struct usb_ctrl_req *req, uint8_t *data, int *len);

struct usb_audio_control_handler {
	int len;
	usb_audio_control_fn set_cur;
	usb_audio_control_fn get_cur;
	usb_audio_control_fn get_min;
	usb_audio_control_fn get_max;
	usb_audio_control_fn get_res;
};

struct usb_audio_req_handler {
	uint8_t rcpt;		/* USB_REQ_RCPT_INTF or USB_REQ_RCPT_EP */
	uint8_t idx;		/* Interface or EP index */
	uint8_t entity_id;
	uint16_t val_match;
	uint16_t val_mask;
	const struct usb_audio_control_handler *h;
};


/* Control handlers for this implementation */

static const struct usb_audio_control_handler _uac_mute = {	/* USB_AC_FU_CONTROL_MUTE */
	.len		= 1,
	.set_cur	= pcm_usb_mute_set,
	.get_cur	= pcm_usb_mute_get,
};

static const struct usb_audio_control_handler _uac_volume = {	/* USB_AC_FU_CONTROL_VOLUME */
	.len		= 2,
	.set_cur	= pcm_usb_volume_set,
	.get_cur	= pcm_usb_volume_get,
	.get_min	= pcm_usb_volume_min,
	.get_max	= pcm_usb_volume_max,
	.get_res	= pcm_usb_volume_res,
};

static const struct usb_audio_req_handler _uac_handlers[] = {
	{ USB_REQ_RCPT_INTF, INTF_AUDIO_CONTROL, UNIT_FEAT_PCM_IN,  (USB_AC_FU_CONTROL_MUTE   << 8), 0xff00, &_uac_mute   },
	{ USB_REQ_RCPT_INTF, INTF_AUDIO_CONTROL, UNIT_FEAT_PCM_IN,  (USB_AC_FU_CONTROL_VOLUME << 8), 0xff00, &_uac_volume },
	{ USB_REQ_RCPT_INTF, INTF_AUDIO_CONTROL, UNIT_FEAT_PCM_OUT, (USB_AC_FU_CONTROL_MUTE   << 8), 0xff00, &_uac_mute   },
	{ USB_REQ_RCPT_INTF, INTF_AUDIO_CONTROL, UNIT_FEAT_PCM_OUT, (USB_AC_FU_CONTROL_VOLUME << 8), 0xff00, &_uac_volume },
	{ 0 }
};


/* USB driver implemntation (including control handler dispatch */

static struct {
	struct usb_ctrl_req *req;
	usb_audio_control_fn fn;
} g_cb_ctx;

static bool
audio_ctrl_req_cb(struct usb_xfer *xfer)
{
	struct usb_ctrl_req *req = g_cb_ctx.req;
	usb_audio_control_fn fn = g_cb_ctx.fn;
	return fn(req, xfer->data, &xfer->len);
}

static enum usb_fnd_resp
audio_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	const struct usb_audio_req_handler *rh;

	/* Check it's a class request */
	if (USB_REQ_TYPE(req) != USB_REQ_TYPE_CLASS)
		return USB_FND_CONTINUE;

	/* Check R/W consitency */
		/* The control request ID mirrors the read flag in the MSB */
	if ((req->bmRequestType ^ req->bRequest) & 0x80)
		return USB_FND_ERROR;

	/* Find a matching handler */
	for (rh=&_uac_handlers[0]; rh->rcpt; rh++)
	{
		usb_audio_control_fn fn = NULL;

		/* Check recipient type and index */
		if (USB_REQ_RCPT(req) != rh->rcpt)
			continue;

		if ((req->wIndex & 0xff) != rh->idx)
			continue;

		/* Check Entity ID */
		if ((req->wIndex >> 8) != rh->entity_id)
			continue;

		/* Check control */
		if ((req->wValue & rh->val_mask) != rh->val_match)
			continue;

		/* We have a match, first check it's not a NOP and check length */
		if (!rh->h)
			return USB_FND_ERROR;

		if ((rh->h->len != -1) && (rh->h->len != req->wLength))
			return USB_FND_ERROR;

		/* Then grab appropriate function */
		switch (req->bRequest)
		{
		case USB_REQ_AC_SET_CUR:
			fn = rh->h->set_cur;
			break;

		case USB_REQ_AC_GET_CUR:
			fn = rh->h->get_cur;
			break;

		case USB_REQ_AC_GET_MIN:
			fn = rh->h->get_min;
			break;

		case USB_REQ_AC_GET_MAX:
			fn = rh->h->get_max;
			break;

		case USB_REQ_AC_GET_RES:
			fn = rh->h->get_res;
			break;

		default:
			fn = NULL;
		}

		if (!fn)
			return USB_FND_ERROR;

		/* And try to call it */
		if (USB_REQ_IS_READ(req)) {
			/* Request is a read, we can call handler immediately */
			xfer->len = req->wLength;
			return fn(req, xfer->data, &xfer->len) ? USB_FND_SUCCESS : USB_FND_ERROR;
		} else {
			/* Request is a write, we need to hold off until end of data phase */
			g_cb_ctx.req = req;
			g_cb_ctx.fn = fn;
			xfer->len = req->wLength;
			xfer->cb_done = audio_ctrl_req_cb;
			return USB_FND_SUCCESS;
		}
	}

	return USB_FND_ERROR;
}

static enum usb_fnd_resp
audio_set_conf(const struct usb_conf_desc *conf)
{
	/* Default PCM interface is inactive */
	pcm_usb_configure(conf);

	return USB_FND_SUCCESS;
}

static enum usb_fnd_resp
audio_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	/* Check it's audio class */
	if (base->bInterfaceClass != USB_CLS_AUDIO)
		return USB_FND_CONTINUE;

	/* Sub class */
	switch (base->bInterfaceSubClass)
	{
	case USB_AC_SCLS_AUDIOCONTROL:
		return USB_FND_SUCCESS;

	case USB_AC_SCLS_AUDIOSTREAMING:
		return pcm_usb_set_intf(base, sel) ? USB_FND_SUCCESS : USB_FND_ERROR;

	default:
		return USB_FND_ERROR;
	}
}

static enum usb_fnd_resp
audio_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	/* Check it's audio class */
	if (base->bInterfaceClass != USB_CLS_AUDIO)
		return USB_FND_CONTINUE;

	/* Sub class */
	switch (base->bInterfaceSubClass)
	{
	case USB_AC_SCLS_AUDIOCONTROL:
		*alt = 0;
		return USB_FND_SUCCESS;

	case USB_AC_SCLS_AUDIOSTREAMING:
		return pcm_usb_get_intf(base, alt) ? USB_FND_SUCCESS : USB_FND_ERROR;

	default:
		return USB_FND_ERROR;
	}
}

static struct usb_fn_drv _audio_drv = {
	.ctrl_req = audio_ctrl_req,
	.set_conf = audio_set_conf,
	.set_intf = audio_set_intf,
	.get_intf = audio_get_intf,
};


// Exposed API
// ---------------------------------------------------------------------------

void
audio_init(void)
{
	/* Init hardware */
	pcm_init();

	/* Register function driver */
	usb_register_function_driver(&_audio_drv);
}

void
audio_poll(void)
{
	pcm_poll();
}
