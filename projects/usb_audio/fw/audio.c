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
#include "led.h"
#include "mini-printf.h"
#include "spi.h"
#include <no2usb/usb.h>
#include <no2usb/usb_ac_proto.h>
#include <no2usb/usb_dfu_rt.h>
#include <no2usb/usb_hw.h>
#include <no2usb/usb_priv.h>
#include "utils.h"
#include "config.h"


// Volume helpers
// ---------------------------------------------------------------------------

/* [round(256*(math.pow(2,i/256.0)-1)) for i in range(256)] */
static const uint8_t vol_log2lin_lut[] = {
	0x00, 0x01, 0x01, 0x02, 0x03, 0x03, 0x04, 0x05,
	0x06, 0x06, 0x07, 0x08, 0x08, 0x09, 0x0a, 0x0b,
	0x0b, 0x0c, 0x0d, 0x0e, 0x0e, 0x0f, 0x10, 0x10,
	0x11, 0x12, 0x13, 0x13, 0x14, 0x15, 0x16, 0x16,
	0x17, 0x18, 0x19, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
	0x1d, 0x1e, 0x1f, 0x20, 0x20, 0x21, 0x22, 0x23,
	0x24, 0x24, 0x25, 0x26, 0x27, 0x28, 0x28, 0x29,
	0x2a, 0x2b, 0x2c, 0x2c, 0x2d, 0x2e, 0x2f, 0x30,
	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x35, 0x36,
	0x37, 0x38, 0x39, 0x3a, 0x3a, 0x3b, 0x3c, 0x3d,
	0x3e, 0x3f, 0x40, 0x41, 0x41, 0x42, 0x43, 0x44,
	0x45, 0x46, 0x47, 0x48, 0x48, 0x49, 0x4a, 0x4b,
	0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x51, 0x52,
	0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
	0x5b, 0x5c, 0x5d, 0x5e, 0x5e, 0x5f, 0x60, 0x61,
	0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
	0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71,
	0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
	0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f, 0x80, 0x81,
	0x82, 0x83, 0x84, 0x85, 0x87, 0x88, 0x89, 0x8a,
	0x8b, 0x8c, 0x8d, 0x8e, 0x8f, 0x90, 0x91, 0x92,
	0x93, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b,
	0x9c, 0x9d, 0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4,
	0xa5, 0xa6, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad,
	0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb6, 0xb7,
	0xb8, 0xb9, 0xba, 0xbc, 0xbd, 0xbe, 0xbf, 0xc0,
	0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc8, 0xc9, 0xca,
	0xcb, 0xcd, 0xce, 0xcf, 0xd0, 0xd2, 0xd3, 0xd4,
	0xd6, 0xd7, 0xd8, 0xd9, 0xdb, 0xdc, 0xdd, 0xde,
	0xe0, 0xe1, 0xe2, 0xe4, 0xe5, 0xe6, 0xe8, 0xe9,
	0xea, 0xec, 0xed, 0xee, 0xf0, 0xf1, 0xf2, 0xf4,
	0xf5, 0xf6, 0xf8, 0xf9, 0xfa, 0xfc, 0xfd, 0xff,
};

/*  [round(math.log2(1.0 + x / 256.0) * 256) for x in range(256)] */
static const uint8_t vol_lin2log_lut[] = {
	0x00, 0x01, 0x03, 0x04, 0x06, 0x07, 0x09, 0x0a,
	0x0b, 0x0d, 0x0e, 0x10, 0x11, 0x12, 0x14, 0x15,
	0x16, 0x18, 0x19, 0x1a, 0x1c, 0x1d, 0x1e, 0x20,
	0x21, 0x22, 0x24, 0x25, 0x26, 0x28, 0x29, 0x2a,
	0x2c, 0x2d, 0x2e, 0x2f, 0x31, 0x32, 0x33, 0x34,
	0x36, 0x37, 0x38, 0x39, 0x3b, 0x3c, 0x3d, 0x3e,
	0x3f, 0x41, 0x42, 0x43, 0x44, 0x45, 0x47, 0x48,
	0x49, 0x4a, 0x4b, 0x4d, 0x4e, 0x4f, 0x50, 0x51,
	0x52, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
	0x5c, 0x5d, 0x5e, 0x5f, 0x60, 0x61, 0x62, 0x63,
	0x64, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c,
	0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x74, 0x75,
	0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d,
	0x7e, 0x7f, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85,
	0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d,
	0x8e, 0x8f, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95,
	0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9b, 0x9c,
	0x9d, 0x9e, 0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4,
	0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xa9, 0xaa, 0xab,
	0xac, 0xad, 0xae, 0xaf, 0xb0, 0xb1, 0xb2, 0xb2,
	0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xb9,
	0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf, 0xc0, 0xc0,
	0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc6, 0xc7,
	0xc8, 0xc9, 0xca, 0xcb, 0xcb, 0xcc, 0xcd, 0xce,
	0xcf, 0xd0, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd4,
	0xd5, 0xd6, 0xd7, 0xd8, 0xd8, 0xd9, 0xda, 0xdb,
	0xdc, 0xdc, 0xdd, 0xde, 0xdf, 0xe0, 0xe0, 0xe1,
	0xe2, 0xe3, 0xe4, 0xe4, 0xe5, 0xe6, 0xe7, 0xe7,
	0xe8, 0xe9, 0xea, 0xea, 0xeb, 0xec, 0xed, 0xee,
	0xee, 0xef, 0xf0, 0xf1, 0xf1, 0xf2, 0xf3, 0xf4,
	0xf4, 0xf5, 0xf6, 0xf7, 0xf7, 0xf8, 0xf9, 0xf9,
	0xfa, 0xfb, 0xfc, 0xfc, 0xfd, 0xfe, 0xff, 0xff,
};


#define VOL_INVALID (-32768)

/* 16384 * math.pow(10, x/(20*256)) */
static int16_t
vol_log2lin(int16_t log)
{
	uint16_t lin;
	int s = 0;

	/* Special cases */
	if (log == VOL_INVALID)	/* Special value */
		return 0x0000;

	if (log >= 1541)	/* Max is ~6 dB */
		return 0x7fff;

	/* Integer part */
	while (log < 0) {
		log += 1541;
		s += 1;
	}

	/* LUT */
	lin = vol_log2lin_lut[(log * 680) >> 12];

	/* Scaling */
	lin = (lin << 6) | (lin >> 2) | 0x4000;
	lin >>= s;

	return lin;
}

/* 20 * 256 * math.log10(lin / 16384) */
static int16_t
vol_lin2log(int16_t lin)
{
	int32_t l = 0;

	/* Special cases */
	if (lin <= 0)
		return VOL_INVALID;

	/* Integer part */
	while (lin < 0x4000) {
		lin <<= 1;
		l = l - 256;
	}

	/* LUT correct */
	l += vol_lin2log_lut[(lin >> 6) & 0xff];

	/* Final scaling */
	l = (l * 1541) >> 8;

	return (int16_t) l;
}


// PCM Audio
// ---------------------------------------------------------------------------

struct wb_audio_pcm {
	uint32_t csr;
	uint32_t volume;
	uint32_t fifo;
} __attribute__((packed,aligned(4)));

static volatile struct wb_audio_pcm * const pcm_regs = (void*)(AUDIO_PCM_BASE);

static struct {
	bool active;
	bool mute_all;

	struct {
		bool     mute;
		int16_t  vol_log;
		uint16_t vol_lin;
	} chan[2];

	uint8_t bdi;
} g_pcm;


static void
pcm_hw_update_volume(void)
{
	pcm_regs->volume =
		(((!g_pcm.mute_all && !g_pcm.chan[1].mute) ?
			g_pcm.chan[1].vol_lin : 0) << 16) |
		(((!g_pcm.mute_all && !g_pcm.chan[0].mute) ?
			g_pcm.chan[0].vol_lin : 0));
}

static void
pcm_set_volume(uint8_t chan, int16_t vol_log)
{
	printf("Volume set %d to %d\n", chan, vol_log);

	if (g_pcm.chan[chan].vol_log == vol_log)
		return;

	g_pcm.chan[chan].vol_lin = vol_log2lin(vol_log);
	g_pcm.chan[chan].vol_log = vol_lin2log(g_pcm.chan[chan].vol_lin);

	pcm_hw_update_volume();
}

static void
pcm_init(void)
{
	/* Local state */
	memset(&g_pcm, 0x00, sizeof(g_pcm));

	/* Audio enabled at -6 dB by default */
	pcm_set_volume(0, -6*256);
	pcm_set_volume(1, -6*256);
}

static int
pcm_level(void)
{
	return (pcm_regs->csr >> 4) & 0xfff;
}


// Audio USB data
// ---------------------------------------------------------------------------

static void
pcm_usb_fill_feedback_ep(void)
{
	/* FIXME figure this out */
#if 0 
	uint32_t val = 8192;

	/* Prepare buffer */
	usb_data_write(64, &val, 4);
	usb_ep_regs[1].in.bd[0].ptr = 64;
	usb_ep_regs[1].in.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(3);
#endif
}



static void
pcm_usb_flow_start(void)
{
	/* Reset Buffer index */
	g_pcm.bdi = 0;

	/* EP 1 OUT: Type=Isochronous, dual buffered */
	usb_ep_regs[1].out.status = USB_EP_TYPE_ISOC | USB_EP_BD_DUAL;

	/* EP1 OUT: Queue two buffers */
	usb_ep_regs[1].out.bd[0].ptr = 1024;
	usb_ep_regs[1].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(288);

	usb_ep_regs[1].out.bd[1].ptr = 1024 + 288;
	usb_ep_regs[1].out.bd[1].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(288);

	/* EP1 IN: Type=Isochronous, single buffered */
	usb_ep_regs[1].in.status = USB_EP_TYPE_ISOC;

	pcm_usb_fill_feedback_ep();
}

static void
pcm_usb_flow_stop(void)
{
	/* EP 1 OUT: Disable */
	usb_ep_regs[1].out.status = 0;

	/* EP 1 IN: Disable */
	usb_ep_regs[1].in.status = 0;

	/* Stop playing audio */
	pcm_regs->csr = 0;
}

static void
pcm_usb_set_active(bool active)
{
	if (g_pcm.active == active)
		return;

	g_pcm.active = active;

	if (active)
		pcm_usb_flow_start();
	else
		pcm_usb_flow_stop();
}

static void
pcm_poll(void)
{
	/* Check if enough space in FIFO */
	if (pcm_level() >= 440)
		return;

	/* EP BD Status */
	uint32_t ptr = usb_ep_regs[1].out.bd[g_pcm.bdi].ptr;
	uint32_t csr = usb_ep_regs[1].out.bd[g_pcm.bdi].csr;

	/* Check if we have a USB packet */
	if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_RDY_DATA)
		return;

	/* Valid data ? */
	if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
	{
		static uint32_t lt;
		uint32_t ct;

		volatile uint32_t __attribute__((aligned(4))) *src_u32 = (volatile uint32_t *)((USB_DATA_BASE) + ptr);
		int len = (csr & USB_BD_LEN_MSK) - 2; /* Reported length includes CRC */

		for (int i=0; i<len; i+=4)
			pcm_regs->fifo = *src_u32++;

		ct = usb_get_tick();
		if ((ct-lt) > 1)
			printf("%d %d %d %d\n", len, pcm_level(), ct-lt, ct);
		lt = ct;

		/* If we have enough in the FIFO, enable core */
		if ((pcm_level() > 200) && !(pcm_regs->csr & 1))
			pcm_regs->csr = 1;
	}

	/* Next transfer */
	usb_ep_regs[1].out.bd[g_pcm.bdi].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(288);
	g_pcm.bdi ^= 1;
}


// PCM Audio USB control
// ---------------------------------------------------------------------------

static bool
pcm_usb_mute_set(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if (chan >= 3)
		return false;

	if (chan == 0) {
		g_pcm.mute_all = data[0];
		pcm_hw_update_volume();
	} else {
		g_pcm.chan[chan-1].mute =data[0];
		pcm_hw_update_volume();
	}

	return true;
}

static bool
pcm_usb_mute_get(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if (chan >= 3)
		return false;

	if (chan == 0) {
		data[0] = g_pcm.mute_all;
	} else {
		data[0] = g_pcm.chan[chan-1].mute;
	}

	return true;
}


static bool
pcm_usb_volume_set(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if ((chan == 0) || (chan >= 3))
		return false;

	pcm_set_volume(chan, *((int16_t*)data));

	return true;
}

static bool
pcm_usb_volume_get(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if ((chan == 0) || (chan >= 3))
		return false;

	*((int16_t*)data) = g_pcm.chan[chan-1].vol_log;

	return true;
}

static bool
pcm_usb_volume_min(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if ((chan == 0) || (chan >= 3))
		return false;

	*((int16_t*)data) = (-80 * 256);

	return true;
}

static bool
pcm_usb_volume_max(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if ((chan == 0) || (chan >= 3))
		return false;

	*((int16_t*)data) = (5 * 256);

	return true;
}

static bool
pcm_usb_volume_res(uint16_t wValue, uint8_t *data, int *len)
{
	uint8_t chan = wValue & 0xff;

	if ((chan == 0) || (chan >= 3))
		return false;

	*((int16_t*)data) = (256 / 2);

	return true;
}


// MIDI
// ---------------------------------------------------------------------------

struct wb_uart {
	uint32_t data;
	uint32_t clkdiv;
} __attribute__((packed,aligned(4)));

static volatile struct wb_uart * const midi_regs = (void*)(MIDI_BASE);


void
midi_usb_set_conf(void)
{
	/* EP 2 OUT: Type=Bulk, single buffered */
	usb_ep_regs[2].out.status = USB_EP_TYPE_BULK;

	/* Fill a buffer */
	usb_ep_regs[2].out.bd[0].ptr = 1536;
	usb_ep_regs[2].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(64);
}

static const int
midi_pkt[16] = {
	-1,	/* 0x0 Miscellaneous function codes. Reserved for future extensions */
	-1,	/* 0x1 Cable events. Reserved for future expansion */
	2,	/* 0x2 Two-byte System Common messages like MTC, SongSelect, etc */
	3,	/* 0x3 Three-byte System Common messages like SPP, etc */
	3,	/* 0x4 SysEx starts or continues */
	1,	/* 0x5 SysEx ends with following single byte */
	2,	/* 0x6 SysEx ends with following two bytes */
	3,	/* 0x7 SysEx ends with following three bytes */
	3,	/* 0x8 Note-off */
	3,	/* 0x9 Note-on */
	3,	/* 0xa Poly-KeyPress */
	3,	/* 0xb Control Change */
	2,	/* 0xc Program Change */
	2,	/* 0xd Channel Pressure */
	3,	/* 0xe PitchBend Change */
	1,	/* 0xf Single Byte */
};

static void
midi_poll(void)
{
	/* EP BD Status */
	uint32_t ptr = usb_ep_regs[2].out.bd[0].ptr;
	uint32_t csr = usb_ep_regs[2].out.bd[0].csr;

	/* Check if we have a USB packet */
	if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_RDY_DATA)
		return;

	/* Valid data ? */
	if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK)
	{
		uint32_t midi[64];
		int len = (csr & USB_BD_LEN_MSK) - 2; /* Reported length includes CRC */

		usb_data_read(midi, ptr, len);

		for (int i=0; i<(len>>2); i++) {
			uint32_t w = midi[i];
			int bl = midi_pkt[w & 0xf];
			w >>= 8;

			while (bl-- > 0) {
				midi_regs->data = (w & 0xff);
				w >>= 8;
			}
		}
	}

	/* Next transfer */
	usb_ep_regs[2].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(64);
}

static void
midi_init(void)
{
	/* 31250 baud with 24MHz system clk */
	midi_regs->clkdiv = 768;
}



// Shared USB driver
// ---------------------------------------------------------------------------

/* Control handler structs */

typedef bool (*usb_audio_control_fn)(uint16_t wValue, uint8_t *data, int *len);

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

#define INTF_AUDIO_CONTROL	1
#define UNIT_FEATURE		2

static const struct usb_audio_req_handler _uac_handlers[] = {
	{ USB_REQ_RCPT_INTF, INTF_AUDIO_CONTROL, UNIT_FEATURE, (USB_AC_FU_CONTROL_MUTE   << 8), 0xff00, &_uac_mute   },
	{ USB_REQ_RCPT_INTF, INTF_AUDIO_CONTROL, UNIT_FEATURE, (USB_AC_FU_CONTROL_VOLUME << 8), 0xff00, &_uac_volume },
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
	return fn(req->wValue, xfer->data, &xfer->len);
}

static enum usb_fnd_resp
audio_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	const struct usb_audio_req_handler *rh;

	/* Check it's a class request to an interface */
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
			return fn(req->wValue, xfer->data, &xfer->len) ? USB_FND_SUCCESS : USB_FND_ERROR;
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
	pcm_usb_set_active(false);

	/* MIDI EP config */
	midi_usb_set_conf();

	return USB_FND_SUCCESS;
}

static enum usb_fnd_resp
audio_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	/* Check it's audio class */
	if (base->bInterfaceClass != 0x01)
		return USB_FND_CONTINUE;

	/* Sub class */
	switch (base->bInterfaceSubClass)
	{
	case USB_AC_SCLS_AUDIOCONTROL:
	case USB_AC_SCLS_MIDISTREAMING:
		return USB_FND_SUCCESS;

	case USB_AC_SCLS_AUDIOSTREAMING:
		pcm_usb_set_active(sel->bAlternateSetting != 0);
		return USB_FND_SUCCESS;

	default:
		return USB_FND_ERROR;
	}
}

static enum usb_fnd_resp
audio_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	/* Check it's audio class */
	if (base->bInterfaceClass != 0x01)
		return USB_FND_CONTINUE;

	/* Sub class */
	switch (base->bInterfaceSubClass)
	{
	case USB_AC_SCLS_AUDIOCONTROL:
	case USB_AC_SCLS_MIDISTREAMING:
		*alt = 0;
		return USB_FND_SUCCESS;

	case USB_AC_SCLS_AUDIOSTREAMING:
		*alt = g_pcm.active ? 1 : 0;
		return USB_FND_SUCCESS;

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
	midi_init();

	/* Register function driver */
	usb_register_function_driver(&_audio_drv);
}

void
audio_poll(void)
{
	pcm_poll();
	midi_poll();
}

void
audio_debug_print(void)
{
	uint32_t csr = pcm_regs->csr;

	printf("Audio PCM tick       : %04x\n", csr >> 16);
	printf("Audio PCM FIFO level : %d\n", (csr >> 4) & 0xfff);
	printf("Audio PCM State      : %d\n", csr & 3);
}
