/*
 * usb.c
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
#include "usb.h"


/* Main stack state */
struct usb_stack g_usb;


/* Helpers */
/* ------- */

	/* Data buffer access */

void
usb_data_write(unsigned int dst_ofs, const void *src, int len)
{
	/* FIXME unaligned ofs */
	const uint32_t *src_u32 = src;
	volatile uint32_t *dst_u32 = (volatile uint32_t *)((USB_DATA_BASE) + dst_ofs);

	len = (len + 3) >> 2;
	while (len--)
		*dst_u32++ = *src_u32++;
}

void
usb_data_read (void *dst, unsigned int src_ofs, int len)
{
	/* FIXME unaligned ofs */
	volatile uint32_t *src_u32 = (volatile uint32_t *)((USB_DATA_BASE) + src_ofs);
	uint32_t *dst_u32 = dst;

	int i = len >> 2;

	while (i--)
		*dst_u32++ = *src_u32++;

	if ((len &= 3) != 0) {
		uint32_t x = *src_u32;
		uint8_t  *dst_u8 = (uint8_t *)dst_u32;
		while (len--) {
			*dst_u8++ = x & 0xff;
			x >>= 8;
		}
	}
}


	/* Descriptors */

const struct usb_conf_desc *
usb_desc_find_conf(uint8_t cfg_value)
{
	for (int i=0; i<g_usb.stack_desc->n_conf; i++)
		if (g_usb.stack_desc->conf[i]->bConfigurationValue == cfg_value)
			return g_usb.stack_desc->conf[i];
	return NULL;
}

const void *
usb_desc_find(const void *sod, const void *eod, uint8_t dt)
{
	const uint8_t *sod_p = sod, *eod_p = eod;
	while ((eod_p - sod_p) >= 2) {
		if (sod_p[1] == dt)
			return sod_p;
		sod_p += sod_p[0];
	}
	return NULL;
}

const void *
usb_desc_next(const void *sod)
{
	const uint8_t *sod_p = sod;
	return sod_p + sod_p[0];
}


	/* Callback dispatching */

void
usb_dispatch_sof(void)
{
	struct usb_fn_drv *p = g_usb.fnd;

	while (p) {
		if (p->sof)
			p->sof();
		p = p->next;
	}
}

void
usb_dipatch_bus_reset(void)
{
	struct usb_fn_drv *p = g_usb.fnd;

	while (p) {
		if (p->bus_reset)
			p->bus_reset();
		p = p->next;
	}
}

void
usb_dispatch_state_chg(enum usb_dev_state state)
{
	struct usb_fn_drv *p = g_usb.fnd;

	while (p) {
		if (p->state_chg)
			p->state_chg(state);
		p = p->next;
	}
}

enum usb_fnd_resp
usb_dispatch_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	struct usb_fn_drv *p = g_usb.fnd;
	enum usb_fnd_resp rv = USB_FND_CONTINUE;

	while (p) {
		if (p->ctrl_req) {
			rv = p->ctrl_req(req, xfer);
			if (rv != USB_FND_CONTINUE)
				return rv;
		}
		p = p->next;
	}

	return rv;
}

enum usb_fnd_resp
usb_dispatch_set_conf(const struct usb_conf_desc *desc)
{
	struct usb_fn_drv *p = g_usb.fnd;
	enum usb_fnd_resp rv = USB_FND_SUCCESS;

	while (p) {
		if (p->set_conf) {
			if (p->set_conf(desc) == USB_FND_ERROR)
				rv = USB_FND_ERROR;
		}
		p = p->next;
	}

	return rv;
}

enum usb_fnd_resp
usb_dispatch_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	struct usb_fn_drv *p = g_usb.fnd;
	enum usb_fnd_resp rv = USB_FND_CONTINUE;

	while (p) {
		if (p->set_intf) {
			rv = p->set_intf(base, sel);
			if (rv != USB_FND_CONTINUE)
				return rv;
		}
		p = p->next;
	}

	return rv;
}

enum usb_fnd_resp
usb_dispatch_get_intf(const struct usb_intf_desc *base, uint8_t *sel)
{
	struct usb_fn_drv *p = g_usb.fnd;
	enum usb_fnd_resp rv = USB_FND_CONTINUE;

	while (p) {
		if (p->get_intf) {
			rv = p->get_intf(base, sel);
			if (rv != USB_FND_CONTINUE)
				return rv;
		}
		p = p->next;
	}

	return rv;
}


/* Debug */
/* ----- */

static void
_fast_print_hex(uint32_t v)
{
	const char _hex[] = "0123456789abcdef";
	int i;

	for (i=0; i<4; i++) {
		putchar(_hex[(v & 0xf0) >> 4]);
		putchar(_hex[ v & 0x0f      ]);
		putchar(' ');
		v >>= 8;
	}
}

void
usb_debug_print_ep(int ep, int dir)
{
	volatile struct usb_ep *ep_regs = dir ? &usb_ep_regs[ep].in : &usb_ep_regs[ep].out;

	printf("EP%d %s", ep, dir ? "IN" : "OUT");
	printf("\tS     %04x\n", ep_regs->status);
	printf("\tBD0.0 %04x\n", ep_regs->bd[0].csr);
	printf("\tBD0.1 %04x\n", ep_regs->bd[0].ptr);
	printf("\tBD1.0 %04x\n", ep_regs->bd[1].csr);
	printf("\tBD1.1 %04x\n", ep_regs->bd[1].ptr);
	printf("\n");
}

void
usb_debug_print_data(int ofs, int len)
{
	volatile uint32_t *data = (volatile uint32_t *)((USB_DATA_BASE) + (ofs << 2));
	int i;

	for (i=0; i<len; i++) {
		_fast_print_hex(*data++);
		putchar((((i & 3) == 3) | (i == (len-1))) ? '\n' : ' ');
	}
	puts("\n");
}

void
usb_debug_print(void)
{
	printf("Stack:\n");
	printf("\tState: %d\n", g_usb.state);
	printf("HW:\n");
	printf("\tSR   : %04x\n", usb_regs->csr);
	printf("\tTick : %04x\n", g_usb.tick);
	printf("\n");

	usb_debug_print_ep(0, 0);
	usb_debug_print_ep(0, 1);

	printf("Data:\n");
	usb_debug_print_data(0, 4);
}


/* Internal API */
/* ------------ */

static void
_usb_hw_reset_ep(volatile struct usb_ep *ep)
{
	ep->status = 0;
	ep->bd[0].csr = 0;
	ep->bd[0].ptr = 0;
	ep->bd[1].csr = 0;
	ep->bd[1].ptr = 0;
}

static void
_usb_hw_reset(bool pu)
{
	/* Clear all descriptors */
	for (int i=0; i<16; i++) {
		_usb_hw_reset_ep(&usb_ep_regs[i].out);
		_usb_hw_reset_ep(&usb_ep_regs[i].in);
	}

	/* Main control */
	usb_regs->csr = (pu ? USB_CSR_PU_ENA : 0) | USB_CSR_CEL_ENA | USB_CSR_ADDR_MATCH | USB_CSR_ADDR(0);
	usb_regs->ar  = USB_AR_BUS_RST_CLEAR | USB_AR_SOF_CLEAR | USB_AR_CEL_RELEASE;
}

static void
usb_bus_reset(void)
{
	/* Reset hw */
	_usb_hw_reset(true);

	/* Reset EP0 */
	usb_ep0_reset();

	/* Dispatch event */
	usb_dipatch_bus_reset();

	/* Set state */
	usb_set_state(USB_DS_DEFAULT);
}


/* Exposed API */
/* ----------- */

void
usb_init(const struct usb_stack_descriptors *stack_desc)
{
	/* Main state reset */
	memset(&g_usb, 0x00, sizeof(g_usb));

	/* Stack setup */
	g_usb.state = USB_DS_DISCONNECTED;
	g_usb.stack_desc = stack_desc;

	usb_register_function_driver(&usb_ctrl_std_drv);

	/* Reset and enable the core */
	_usb_hw_reset(false);
}

void
usb_poll(void)
{
	uint32_t csr;

	/* Active ? */
	if (g_usb.state < USB_DS_CONNECTED)
		return;

	/* Read CSR */
	csr = usb_regs->csr;

	/* Check for pending bus reset */
	if (csr & USB_CSR_BUS_RST_PENDING) {
		if (csr & USB_CSR_BUS_RST)
			return;
		usb_bus_reset();
	}

	/* If we've not been reset, only reset is of interest */
	if (g_usb.state < USB_DS_DEFAULT)
		return;

	/* Supspend handling */
	if (csr & USB_CSR_BUS_SUSPEND) {
		if (!(g_usb.state & USB_DS_SUSPENDED)) {
			usb_set_state(USB_DS_SUSPENDED);
		}
		return;
	} else if (g_usb.state & USB_DS_SUSPENDED) {
		usb_set_state(USB_DS_RESUME);
	}

	/* SOF Tick */
	if (csr & USB_CSR_SOF_PENDING) {
		g_usb.tick++;
		usb_regs->ar = USB_AR_SOF_CLEAR;
		usb_dispatch_sof();
	}

	/* Check for activity */
	if (!(csr & USB_CSR_EVT_PENDING))
		return;
	csr = usb_regs->evt;

	/* Poll EP0 (control) */
	usb_ep0_poll();
}

void
usb_set_state(enum usb_dev_state new_state)
{
	/* Handle resume/suspend 'markers' */
	if (new_state == USB_DS_RESUME)
		new_state = g_usb.state & ~USB_DS_SUSPENDED;
	else if (new_state == USB_DS_SUSPENDED)
		new_state = g_usb.state | USB_DS_SUSPENDED;

	/* If state is new, update */
	if (g_usb.state != new_state) {
		g_usb.state = new_state;
		usb_dispatch_state_chg(usb_get_state());
	}
}

enum usb_dev_state
usb_get_state(void)
{
	return (g_usb.state & USB_DS_SUSPENDED) ? USB_DS_SUSPENDED : g_usb.state;
}

uint32_t
usb_get_tick(void)
{
	return g_usb.tick;
}

void
usb_connect(void)
{
	/* Sanity check */
	if (g_usb.state != USB_DS_DISCONNECTED)
		return;

	/* Turn-off pull-up */
	usb_regs->csr |= USB_CSR_PU_ENA;

	/* Stack update */
	usb_set_state(USB_DS_CONNECTED);
}

void
usb_disconnect(void)
{
	/* Sanity check */
	if (g_usb.state < USB_DS_CONNECTED)
		return;

	/* Turn-off pull-up */
	usb_regs->csr &= ~USB_CSR_PU_ENA;

	/* Stack state */
	usb_set_state(USB_DS_DISCONNECTED);
}


void
usb_set_address(uint8_t addr)
{
	usb_regs->csr = USB_CSR_PU_ENA | USB_CSR_CEL_ENA | USB_CSR_ADDR_MATCH | USB_CSR_ADDR(addr);
}


void
usb_register_function_driver(struct usb_fn_drv *drv)
{
	drv->next = g_usb.fnd;
	g_usb.fnd = drv;
}

void
usb_unregister_function_driver(struct usb_fn_drv *drv)
{
	struct usb_fn_drv **p = &g_usb.fnd;
	while (*p) {
		if (*p == drv) {
			*p = drv->next;
			drv->next = NULL;
			break;
		}
		p = &(*p)->next->next;
	}
}


static volatile struct usb_ep *
_get_ep_regs(uint8_t ep)
{
	return (ep & 0x80) ?
		&usb_ep_regs[ep & 0xf].in :
		&usb_ep_regs[ep & 0xf].out;
}

bool
usb_ep_is_configured(uint8_t ep)
{
	volatile struct usb_ep *epr = _get_ep_regs(ep);
	uint32_t s = epr->status;
	return USB_EP_TYPE(s) != USB_EP_TYPE_NONE;
}

bool
usb_ep_is_halted(uint8_t ep)
{
	volatile struct usb_ep *epr = _get_ep_regs(ep);
	uint32_t s = epr->status;
	return USB_EP_TYPE_IS_BCI(s) && (s & USB_EP_TYPE_HALTED);
}

bool
usb_ep_halt(uint8_t ep)
{
	volatile struct usb_ep *epr = _get_ep_regs(ep);
	uint32_t s = epr->status;
	if (!USB_EP_TYPE_IS_BCI(s))
		return false;
	epr->status = s | USB_EP_TYPE_HALTED;
	return true;
}

bool
usb_ep_resume(uint8_t ep)
{
	volatile struct usb_ep *epr = _get_ep_regs(ep);
	uint32_t s = epr->status;
	if (!USB_EP_TYPE_IS_BCI(s))
		return false;
	epr->status = s & ~(USB_EP_TYPE_HALTED | USB_EP_DT_BIT); /* DT bit clear needed by CLEAR_FEATURE */
	return true;
}
