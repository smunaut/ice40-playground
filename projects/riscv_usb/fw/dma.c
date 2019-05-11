/*
 * dma.c
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

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "dma.h"


struct dma {
	uint32_t csr;
	uint32_t _rsvd;
	uint32_t addr_e1;
	uint32_t addr_usb;
} __attribute__((packed,aligned(4)));

#define DMA_CSR_GO		(1 << 15)
#define DMA_CSR_BUSY		(1 << 15)
#define DMA_DIR_E1_TO_USB	(0 << 14)
#define DMA_DIR_USB_TO_E1	(1 << 14)
#define DMA_CSR_LEN(x)		(((x)-2) & 0x1fff)

static volatile struct dma * const dma_regs = (void*)(DMA_BASE);

static struct {
	bool pending;
	dma_cb cb_fn;
	void *cb_data;
} g_dma;


bool
dma_ready(void)
{
	return !(dma_regs->csr & DMA_CSR_BUSY);
}

void
dma_exec(unsigned addr_e1, unsigned addr_usb, unsigned len, bool dir,
         dma_cb cb_fn, void *cb_data)
{
	dma_regs->addr_e1  = addr_e1;
	dma_regs->addr_usb = addr_usb;
	dma_regs->csr =
		DMA_CSR_GO |
		(dir ? DMA_DIR_USB_TO_E1 : DMA_DIR_E1_TO_USB) |
		DMA_CSR_LEN(len);

	g_dma.pending = true;
	g_dma.cb_fn = cb_fn;
	g_dma.cb_data = cb_data;
}

bool
dma_poll(void)
{
	if (g_dma.pending && dma_ready()) {
		g_dma.pending = false;
		if (g_dma.cb_fn)
			g_dma.cb_fn(g_dma.cb_data);
	}

	return g_dma.pending;
}
