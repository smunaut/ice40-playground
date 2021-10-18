/*
 * console.c
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <no2usb/usb.h>
#include <no2usb/usb_priv.h>
#include <no2usb/usb_hw.h>

#include "config.h"
#include "mini-printf.h"


// ---------------------------------------------------------------------------
// CDC ACM
// ---------------------------------------------------------------------------

#define CDC_INTF	2
#define CDC_EP_CTL	0x81
#define CDC_EP_OUT	0x02
#define CDC_EP_IN	0x82

#define CDC_PKT_SIZE	32
#define CDC_TX_BUF_LEN	256
#define CDC_TX_BUF_MSK	(CDC_TX_BUF_LEN-1)


struct {
	/* RX buffer (just 1 packet) */
	struct {
		char    data[CDC_PKT_SIZE] __attribute__((aligned(4)));
		uint8_t len;
		uint8_t pos;
	} rx;

	/* TX buffer */
	struct {
		char    data[CDC_TX_BUF_LEN] __attribute__((aligned(4)));
		uint8_t rd;
		uint8_t wr;
	} tx;
} g_cdc;



static enum usb_fnd_resp
cdc_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	return USB_FND_CONTINUE;
}

static enum usb_fnd_resp
cdc_set_conf(const struct usb_conf_desc *desc)
{
	const struct usb_intf_desc *intf;

	intf = usb_desc_find_intf(desc, CDC_INTF, 0, NULL);
	if (!intf)
		return USB_FND_CONTINUE;

	/* State init */
	memset(&g_cdc, 0x00, sizeof(g_cdc));

	/* EP init */
	usb_ep_boot(intf, CDC_EP_OUT, false);
	usb_ep_boot(intf, CDC_EP_IN,  false);

	/* Prime RX buffer */
	usb_ep_regs[CDC_EP_OUT & 0xf].out.bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(CDC_PKT_SIZE);

	return USB_FND_SUCCESS;
}

static void
cdc_poll(void)
{
	volatile struct usb_ep *ep;
	uint32_t csr;

	/* RX */
	ep = &usb_ep_regs[CDC_EP_OUT & 0xf].out;
	csr = ep->bd[0].csr;

	if ((csr & USB_BD_STATE_MSK) == USB_BD_STATE_DONE_OK) {
		if (!g_cdc.rx.len) {
			/* Grab data */
			if ((csr & USB_BD_LEN_MSK) >= 2) {
				g_cdc.rx.len = (csr & USB_BD_LEN_MSK) - 2;
				usb_data_read(g_cdc.rx.data, ep->bd[0].ptr, CDC_PKT_SIZE);
			} else
				g_cdc.rx.len = 0;

			/* Reload */
			ep->bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(CDC_PKT_SIZE);
		}
	} else if ((csr & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA) {
		/* Reload */
		ep->bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(CDC_PKT_SIZE);
	}

	/* TX */
	ep = &usb_ep_regs[CDC_EP_IN & 0xf].in;
	csr = ep->bd[0].csr;

	if (((csr & USB_BD_STATE_MSK) != USB_BD_STATE_RDY_DATA) && (g_cdc.tx.rd != g_cdc.tx.wr))
	{
		uint8_t pkt[CDC_PKT_SIZE] __attribute__((aligned(4)));
		int len = 0;

		/* Prepare packet */
		while ((len < CDC_PKT_SIZE) && (g_cdc.tx.rd != g_cdc.tx.wr)) {
			pkt[len++] = g_cdc.tx.data[g_cdc.tx.rd];
			g_cdc.tx.rd = (g_cdc.tx.rd + 1) & CDC_TX_BUF_MSK;
		}

		/* Send it */
		usb_data_write(ep->bd[0].ptr, pkt, CDC_PKT_SIZE);
		ep->bd[0].csr = USB_BD_STATE_RDY_DATA | USB_BD_LEN(len);
	}
}

static struct usb_fn_drv _cdc_drv = {
	.ctrl_req = cdc_ctrl_req,
	.set_conf = cdc_set_conf,
};


// ---------------------------------------------------------------------------
// Console API
// ---------------------------------------------------------------------------

void
console_init(void)
{
	usb_register_function_driver(&_cdc_drv);
}

void
console_poll(void)
{
	cdc_poll();
}

int getchar_nowait(void)
{
	int rv;

	/* If local buf is empty, try reload */
	if (g_cdc.rx.len == 0)
		cdc_poll();

	/* Anything ? */
	if (g_cdc.rx.len == 0)
		return -1;

	/* Get char */
	rv = g_cdc.rx.data[g_cdc.rx.pos++];

	/* Handle end of packet */
	if (g_cdc.rx.pos == g_cdc.rx.len)
		g_cdc.rx.len = g_cdc.rx.pos = 0;

	/* Value */
	return rv;
}

char getchar(void)
{
	int c;

	do {
		c = getchar_nowait();
	} while (c == -1);

	return c;
}

void putchar(char c)
{
	/* Next write pos */
	uint8_t nxt = (g_cdc.tx.wr + 1) & CDC_TX_BUF_MSK;

	/* Wait for some space */
	while (g_cdc.tx.rd == nxt)
	{
		usb_poll();
		cdc_poll();
	}

	/* Store char */
	g_cdc.tx.data[g_cdc.tx.wr] = c;
	g_cdc.tx.wr = nxt;
}

void puts(const char *p)
{
	char c;
	while ((c = *(p++)) != 0x00) {
		if (c == '\n')
			putchar('\r');
		putchar(c);
	}
}

int printf(const char *fmt, ...)
{
	static char _printf_buf[128];
	va_list va;
	int l;

	va_start(va, fmt);
	l = mini_vsnprintf(_printf_buf, 128, fmt, va);
	va_end(va);

	puts(_printf_buf);

	return l;
}
