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
#include "usb_priv.h"


/* Main stack state */
struct usb_stack g_usb;


/* Helpers for data access */
void
usb_data_write(int dst_ofs, const void *src, int len)
{
	const uint32_t *src_u32 = src;
	volatile uint32_t *dst_u32 = (volatile uint32_t *)((USB_DATA_BASE) + (dst_ofs << 2));

	len = (len + 3) >> 2;
	while (len--)
		*dst_u32++ = *src_u32++;
}

void
usb_data_read (void *dst, int src_ofs, int len)
{
	volatile uint32_t *src_u32 = (volatile uint32_t *)((USB_DATA_BASE) + (src_ofs << 2));
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


/* Debug */
static const char *_hex = "0123456789abcdef";

static void
_fast_print_04x(uint32_t v)
{
	int i;
	char str[5];
	for (i=3; i>=0; i--) {
		str[i] = _hex[v & 0xf];
		v >>= 4;
	}
	str[4] = 0;
	puts(str);
}

static void
_fast_print_hex(uint32_t v)
{
	char str[12], *p = str;
	int i;

	for (i=0; i<4; i++) {
		*p++ = _hex[(v & 0xf0) >> 4];
		*p++ = _hex[ v & 0x0f      ];
		*p++ = ' ';
		v >>= 8;
	}
	str[11] = 0;
	puts(str);
}

void
usb_debug_print_ep(int ep, int dir)
{
	volatile struct usb_ep *ep_regs = dir ? &usb_ep_regs[ep].in : &usb_ep_regs[ep].out;

	printf("EP%d %s", ep, dir ? "IN" : "OUT");
	puts("\n\tS     "); _fast_print_04x(ep_regs->status);
	puts("\n\tBD0.0 "); _fast_print_04x(ep_regs->bd[0].csr);
	puts("\n\tBD0.1 "); _fast_print_04x(ep_regs->bd[0].ptr);
	puts("\n\tBD1.0 "); _fast_print_04x(ep_regs->bd[1].csr);
	puts("\n\tBD1.1 "); _fast_print_04x(ep_regs->bd[1].ptr);
	puts("\n\n");
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
	puts("\nCSR:");
	puts("\n\tSR: "); _fast_print_04x(usb_regs->csr); 
	puts("\n\n");

	usb_debug_print_ep(0, 0);
	usb_debug_print_ep(0, 1);
	usb_debug_print_ep(1, 0);
	usb_debug_print_ep(1, 1);

	puts("\nData:\n");
	usb_debug_print_data(0, 4);
}


/* Exposed API */

void
usb_init(void)
{
	/* Main state init */
	memset(&g_usb, 0x00, sizeof(g_usb));

	g_usb.ctrl.state = IDLE;

	/* Initialize EP0 */
	usb_ep0_init();

	/* Enable the core */
	usb_regs->csr = USB_CSR_PU_ENA | USB_CSR_CEL_ENA;
}

void
usb_poll(void)
{
	uint32_t evt;

	/* Check for activity */
	evt = usb_regs->evt;
	if (!(evt & 0xf000))
		return;

	/* Run EP0 (control) */
	usb_ep0_run();
}
