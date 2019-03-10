/*
 * usb_desc.c
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

#include "usb_desc_data.h"

#define NULL ((void*)0)
#define num_elem(a) (sizeof(a) / sizeof(a[0]))

const void *
usb_get_device_desc(int *len)
{
	*len = Devices[0][0];
	return Devices[0];
}

const void *
usb_get_config_desc(int *len, int idx)
{
	if (idx < num_elem(Configurations)) {
		*len = Configurations[idx][2] + (Configurations[idx][3] << 8);
		return Configurations[idx];
	} else {
		*len = 0;
		return NULL;
	}
}

const void *
usb_get_string_desc(int *len, int idx)
{
	if (idx <= 0) {
		*len = StringZeros[0][0];
		return StringZeros[0];
	} else if ((idx-1) < num_elem(Strings)) {
		*len = Strings[idx-1][0];
		return Strings[idx-1];
	} else {
		*len = 0;
		return NULL;
	}
}
