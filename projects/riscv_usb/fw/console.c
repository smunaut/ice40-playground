/*
 * console.c
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

#include "config.h"
#include "mini-printf.h"


struct wb_uart {
	uint32_t data;
	uint32_t clkdiv;
} __attribute__((packed,aligned(4)));

static volatile struct wb_uart * const uart_regs = (void*)(UART_BASE);


static char _printf_buf[128];

void console_init(void)
{
	uart_regs->clkdiv = 22;	/* 1 Mbaud with clk=24MHz */
}

char getchar(void)
{
	int32_t c;
	do {
		c = uart_regs->data;
	} while (c & 0x80000000);
	return c;
}

int getchar_nowait(void)
{
	int32_t c;
	c = uart_regs->data;
	return c & 0x80000000 ? -1 : (c & 0xff);
}

void putchar(char c)
{
	uart_regs->data = c;
}

void puts(const char *p)
{
	char c;
	while ((c = *(p++)) != 0x00) {
		if (c == '\n')
			uart_regs->data = '\r';
		uart_regs->data = c;
	}
}

int printf(const char *fmt, ...)
{
        va_list va;
        int l;

        va_start(va, fmt);
        l = mini_vsnprintf(_printf_buf, 128, fmt, va);
        va_end(va);

	puts(_printf_buf);

	return l;
}
