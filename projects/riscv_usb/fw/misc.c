/*
 * misc.c
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
#include "misc.h"


struct misc {
	uint32_t warmboot;
	uint32_t e1_tick;
	uint32_t vio_pdm;
} __attribute__((packed,aligned(4)));

static volatile struct misc * const misc_regs = (void*)(MISC_BASE);


void
vio_set(unsigned value)
{
	misc_regs->vio_pdm = value;
}


void
e1_tick_read(uint16_t *ticks)
{
	uint32_t v = misc_regs->e1_tick;
	ticks[0] = (v      ) & 0xffff;
	ticks[1] = (v >> 16) & 0xffff;
}
