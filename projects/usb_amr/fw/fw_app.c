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

#include <no2usb/usb.h>
#include <no2usb/usb_dfu_rt.h>
#include <no2usb/usb_hw.h>
#include <no2usb/usb_priv.h>

#include "audio.h"
#include "cdc-dlm.h"
#include "console.h"
#include "led.h"
#include "mc97.h"
#include "mini-printf.h"
#include "spi.h"
#include "utils.h"

#include "config.h"


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
main()
{
	int cmd = 0;

	/* Init console IO */
	console_init();
	puts("Booting Audio image..\n");

	/* LED */
	led_init();
	led_color(48, 96, 5);
	led_blink(true, 200, 1000);
	led_breathe(true, 100, 200);
	led_state(true);

	/* SPI */
	spi_init();

	/* MC97 link */
	mc97_init();

	/* Init USB stack */
	serial_no_init();
	usb_init(&app_stack_desc);
	usb_dfu_rt_init();

	/* Init class drivers */
	audio_init();
	cdc_dlm_init();

	/* Connect */
	usb_connect();

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
			case 'i': mc97_init();  break;
			case 'p': mc97_debug(); break;

			case 'r': mc97_set_aux_relay(false); break;
			case 'R': mc97_set_aux_relay(true);  break;

			case 'h': mc97_set_hook(ON_HOOK);   break;
			case 'H': mc97_set_hook(OFF_HOOK);  break;
			case 'C': mc97_set_hook(CALLER_ID); break;

			case 'n': mc97_test_ring(); break;

			case '0': mc97_set_loopback(MC97_LOOPBACK_NONE);            break;
			case '1': mc97_set_loopback(MC97_LOOPBACK_DIGITAL_ADC);     break;
			case '2': mc97_set_loopback(MC97_LOOPBACK_ANALOG_LOCAL);    break;
			case '3': mc97_set_loopback(MC97_LOOPBACK_DIGITAL_DAC);     break;
			case '4': mc97_set_loopback(MC97_LOOPBACK_ANALOG_REMOTE);   break;
			case '5': mc97_set_loopback(MC97_LOOPBACK_ISOCAP);          break;
			case '6': mc97_set_loopback(MC97_LOOPBACK_ANALOG_EXTERNAL); break;

			case 's':
				for (int i=0; i<128; i+=2)
					printf("%02x: %04x\n", i, mc97_codec_reg_read(i));
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
			default:
				break;
			}
		}

		/* USB poll */
		usb_poll();
		audio_poll();
		cdc_dlm_poll();
	}
}
