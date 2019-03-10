/*
 * io.c
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

#include "mini-printf.h"

#define NULL ((void*)0)

#define reg_uart_clkdiv (*(volatile uint32_t*)0x81000004)
#define reg_uart_data   (*(volatile uint32_t*)0x81000000)

static char _printf_buf[128];

void io_init(void)
{
	reg_uart_clkdiv = 23;	/* 1 Mbaud with clk=24MHz */
}

char getchar(void)
{
	int32_t c;
	do {
		c = reg_uart_data;
	} while (c & 0x80000000);
	return c;
}

int getchar_nowait(void)
{
	int32_t c;
	c = reg_uart_data;
	return c & 0x80000000 ? -1 : (c & 0xff);
}

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

void puts(const char *p)
{
	while (*p)
		putchar(*(p++));
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
