/*
 * fw_app.c
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
#include "hram.h"
#include "led.h"
#include "mini-printf.h"
#include "spi.h"
#include "usb.h"
#include "usb_dfu_rt.h"
#include "utils.h"


extern const struct usb_stack_descriptors app_stack_desc;

static void
serial_no_init()
{
	uint8_t buf[8];
	char *id, *desc;
	int i;

	flash_manuf_id(buf);
	printf("Flash Manufacturer : %s\n", hexstr(buf, 3, true));

	flash_unique_id(buf);
	printf("Flash Unique ID    : %s\n", hexstr(buf, 8, true));

	/* Overwrite descriptor string */
		/* In theory in rodata ... but nothing is ro here */
	id = hexstr(buf, 8, false);
	desc = (char*)app_stack_desc.str[1];
	for (i=0; i<16; i++)
		desc[2 + (i << 1)] = id[i];
}

static void
boot_dfu(void)
{
	/* Force re-enumeration */
	usb_disconnect();

	/* Boot firmware */
	volatile uint32_t *boot = (void*)0x80000000;
	*boot = (1 << 2) | (1 << 0);
}

void
usb_dfu_rt_cb_reboot(void)
{
        boot_dfu();
}


void
memtest()
{
#define	MAIN_RAM_BASE		0x41000000
#define	MEMTEST_DATA_SIZE	(1 << 23)

	volatile unsigned int *array = (unsigned int *)MAIN_RAM_BASE;
	unsigned int x;
	int i;

	/* Write */
	x = 0x600dc0de;
	for (i=0; i<MEMTEST_DATA_SIZE/4;i++) {
		x = (x << 1) ^ (x + 1);
		array[i] = x;
	}

	/* Read */
	x = 0x600dc0de;
	for (i=0; i<MEMTEST_DATA_SIZE/4;i++) {
		x = (x << 1) ^ (x + 1);
		if (array[i] != x)
			printf("Error 0x%08x\n", i);
	}

#undef MAIN_RAM_BASE
#undef MEMTEST_DATA_SIZE
}

void
membench()
{
#define	MAIN_RAM_BASE		0x41000000
#define	MEMTEST_DATA_SIZE	(1 << 15)
#define CONFIG_CLOCK_FREQUENCY	24000000

	volatile unsigned int *array = (unsigned int *)MAIN_RAM_BASE;
	int i;
	unsigned int start, end;
	unsigned long write_speed;
	unsigned long read_speed;
	__attribute__((unused)) unsigned int data;

	/* write speed */
	__asm__ volatile ("rdcycle %0" : "=r"(start));
	for(i=0;i<MEMTEST_DATA_SIZE/4;i++) {
		array[i] = i;
	}
	__asm__ volatile ("rdcycle %0" : "=r"(end));
	write_speed = (8*MEMTEST_DATA_SIZE*(CONFIG_CLOCK_FREQUENCY/1000000))/(end - start);
	printf("%d\n", end-start);

	/* read speed */
	__asm__ volatile ("rdcycle %0" : "=r"(start));
	for(i=0;i<MEMTEST_DATA_SIZE/4;i++) {
		data = array[i];
	}
	__asm__ volatile ("rdcycle %0" : "=r"(end));
	read_speed = (8*MEMTEST_DATA_SIZE*(CONFIG_CLOCK_FREQUENCY/1000000))/(end-start);
	printf("%d\n", end-start);

	printf("Memspeed Writes: %dMbps Reads: %dMbps\n", write_speed, read_speed);

#undef MAIN_RAM_BASE
#undef MEMTEST_DATA_SIZE
#undef CONFIG_CLOCK_FREQUENCY
}


void python()
{
	void (*foo)(void) = 0x40100000;
	foo();
}

void main()
{
	int cmd = 0;

	/* Init console IO */
	console_init();
	puts("Booting App image..\n");

	/* LED */
	led_init();
	led_color(48, 96, 5);
	led_blink(true, 200, 1000);
	led_breathe(true, 100, 200);
	led_state(true);

	/* SPI */
	//spi_init();

	/* Enable USB directly */
	//serial_no_init();
	usb_init(&app_stack_desc);
	usb_dfu_rt_init();

	/* Main loop */
	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			printf("Command> ");

		/* Poll for command */
		cmd = getchar_nowait();

		if (cmd >= 0) {
			if (cmd > 32 && cmd < 127) {
				putchar(cmd);
				putchar('\r');
				putchar('\n');
			}

			switch (cmd)
			{
			case 'p':
				usb_debug_print();
				break;
			case 'b':
				boot_dfu();
				break;
			case 'c':
				usb_connect();
				break;
			case 'd':
				usb_disconnect();
				break;
			case 'h':
				hram_init();
				break;
			case 't':
				membench();
				break;
			case 'T':
				memtest();
				break;
			case 'P':
				python();
				break;
			default:
				break;
			}
		}

		/* USB poll */
		usb_poll();
	}
}
