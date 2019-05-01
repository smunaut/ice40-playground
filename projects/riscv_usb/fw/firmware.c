/*
 * firmware.c
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
#include "led.h"
#include "mini-printf.h"
#include "spi.h"
#include "usb.h"


static char *
hexstr(void *d, int n)
{
	static const char * const hex = "0123456789abcdef";
	static char buf[96];
	uint8_t *p = d;
	char *s = buf;
	char c;

	while (n--) {
		c = *p++;
		*s++ = hex[c >> 4];
		*s++ = hex[c & 0xf];
		*s++ = ' ';
	}

	s[-1] = '\0';

	return buf;
}

void main()
{
	bool usb_active = false;
	uint8_t buf[8];
	int cmd = 0;

	/* Init console IO */
	console_init();
	puts("Booting..\n");

	/* LED */
	led_init();
	led_color(48, 96, 5);
	led_blink(true, 200, 1000);
	led_breathe(true, 100, 200);
	led_state(true);

	/* SPI */
	spi_init();

	flash_manuf_id(buf);
	puts("Flash Manuf ID  : "); puts(hexstr(buf, 3)); puts("\n");

	flash_unique_id(buf);
	puts("Flash Unique ID : "); puts(hexstr(buf, 8)); puts("\n");

	/* Main loop */
	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			puts("\nCommand> ");

		/* Poll for command */
		cmd = getchar_nowait();

		if (cmd >= 0) {
			if (cmd > 32 && cmd < 127)
				putchar(cmd);

			switch (cmd)
			{
			case 'd':
				usb_debug_print();
				break;
			case 'u':
				usb_active = true;
				usb_init();
				break;
			default:
				break;
			}
		}

		/* USB poll */
		if (usb_active)
			usb_poll();
	}
}
