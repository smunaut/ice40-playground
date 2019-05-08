/*
 * spi.h
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

#pragma once

#include <stdbool.h>

struct spi_xfer_chunk {
	uint8_t *data;
	unsigned len;
	bool write;
	bool read;
};

#define SPI_CS_FLASH	0
#define SPI_CS_SRAM	1

void spi_init(void);
void spi_xfer(unsigned cs, struct spi_xfer_chunk *xfer, unsigned n);

void flash_cmd(uint8_t cmd);
void flash_deep_power_down(void);
void flash_wake_up(void);
void flash_write_enable(void);
void flash_write_disable(void);
void flash_manuf_id(void *manuf);
void flash_unique_id(void *id);
uint8_t flash_read_sr(void);
void flash_write_sr(uint8_t sr);
void flash_read(void *dst, uint32_t addr, unsigned len);
void flash_page_program(void *src, uint32_t addr, unsigned len);
void flash_sector_erase(uint32_t addr);
