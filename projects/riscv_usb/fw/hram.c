/*
 * hram.c
 *
 * Copyright (C) 2020 Sylvain Munaut
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
#include "console.h"


struct wb_hram {
	uint32_t csr;
	uint32_t cmd;
	struct {
		uint32_t data;
		uint32_t attr;
	} wq;
} __attribute__((packed,aligned(4)));

#define HRAM_CSR_RUN		(1 << 0)
#define HRAM_CSR_RESET		(1 << 1)
#define HRAM_CSR_IDLE_CFG	(1 << 2)
#define HRAM_CSR_IDLE_RUN	(1 << 3)
#define HRAM_CSR_CMD_LAT(x)	((((x)-1) & 15) <<  8)
#define HRAM_CSR_CAP_LAT(x)	((((x)-1) & 15) << 12)
#define HRAM_CSR_PHY_DELAY(x)	(((x) & 15) <<  16)
#define HRAM_CSR_PHY_PHASE(x)	(((x) &  3) <<  20)
#define HRAM_CSR_PHY_EDGE(x)	(((x) &  1) <<  22)

#define HRAM_CMD_LEN(x)		((((x)-1) & 15) << 8)
#define HRAM_CMD_LAT(x)		((((x)-1) & 15) << 4)
#define HRAM_CMD_CS(x)		(((x) &  3) << 2)
#define HRAM_CMD_REG		(1 << 1)
#define HRAM_CMD_MEM		(0 << 1)
#define HRAM_CMD_READ		(1 << 0)
#define HRAM_CMD_WRITE		(0 << 0)


static volatile struct wb_hram * const hram_regs = (void*)(HRAM_BASE);


struct hram_ca {
	union {
		uint64_t qw;
		uint32_t dw[2];
		struct {
			uint16_t reg_val  : 16;
			uint16_t addr_lsb :  3;
			uint16_t _rsvd    : 13;
			uint32_t addr_msb : 29;
			uint32_t linear   :  1;
			uint32_t as       :  1;
			uint32_t rw       :  1;
		};
	};
};


#define HRAM_HWREG_ID0	0
#define HRAM_HWREG_ID1	1
#define HRAM_HWREG_CR0	(1 << 11) | 0
#define HRAM_HWREG_CR1	(1 << 11) | 1


#define HRAM_CR0_BL_16	2
#define HRAM_CR0_BL_32	3
#define HRAM_CR0_BL_64	1
#define HRAM_CR0_BL_128	0

#define HRAM_CR0_LAT_3	14
#define HRAM_CR0_LAT_4	15
#define HRAM_CR0_LAT_5	0
#define HRAM_CR0_LAT_6	1

#define HRAM_CR0_DRIVE_DEFAULT	0
#define HRAM_CR0_DRIVE_115R	1
#define HRAM_CR0_DRIVE_67R	2
#define HRAM_CR0_DRIVE_46R	3
#define HRAM_CR0_DRIVE_34R	4
#define HRAM_CR0_DRIVE_27R	5
#define HRAM_CR0_DRIVE_22R	6
#define HRAM_CR0_DRIVE_19R	7

#define HRAM_CR0_BASE		0x80f0

struct hram_cr0 {
	union {
		uint16_t w;
		struct {
			uint16_t bl		: 2;
			uint16_t hybrid_burst	: 1;
			uint16_t fixed_latency	: 1;
			uint16_t latency	: 4;
			uint16_t rsvd		: 4;
			uint16_t drive		: 3;
			uint16_t dpd_n		: 1;
		};
	};
};


static struct {
	int cmd_lat;
	struct hram_cr0 cr0;
} g_hram;


static void
_hram_wait_idle(void)
{
	while (!(hram_regs->csr & HRAM_CSR_IDLE_CFG));
}

static void
_hram_reg_write(uint8_t cs, uint32_t reg, uint16_t val)
{
	struct hram_ca ca;

	ca.qw = 0;
	ca.rw = 0;
	ca.as = 1;
	ca.linear = 1;
	ca.addr_msb = reg >> 3;
	ca.addr_lsb = reg & 7;
	ca.reg_val = val;

	hram_regs->wq.attr = 0x30;
	hram_regs->wq.data = ca.dw[1];
	hram_regs->wq.data = ca.dw[0];
	hram_regs->wq.data = 0;

	hram_regs->cmd = 
		HRAM_CMD_CS(cs) |
		HRAM_CMD_REG |
		HRAM_CMD_WRITE;

	_hram_wait_idle();
}

static void
_hram_mem_write(uint8_t cs, uint32_t addr, uint32_t val, int count)
{
	struct hram_ca ca;

	ca.qw = 0;
	ca.rw = 0;
	ca.as = 0;
	ca.linear = 1;
	ca.addr_msb = addr >> 3;
	ca.addr_lsb = addr & 7;

	hram_regs->wq.attr = 0x30;
	hram_regs->wq.data = ca.dw[1];

	hram_regs->wq.attr = 0x20;
	hram_regs->wq.data = ca.dw[0];

	hram_regs->wq.attr = 0x30;
	hram_regs->wq.data = val;

	hram_regs->cmd =
		HRAM_CMD_LEN(count) |
		HRAM_CMD_LAT(g_hram.cmd_lat) |
		HRAM_CMD_CS(cs) |
		HRAM_CMD_LEN(count) |
		HRAM_CMD_MEM |
		HRAM_CMD_WRITE;
	
	_hram_wait_idle();
}

static void
_hram_mem_read(uint8_t cs, uint32_t addr, uint32_t *data, uint8_t *attr, int count)
{
	struct hram_ca ca;
	int i;

	ca.qw = 0;
	ca.rw = 1;
	ca.as = 0;
	ca.linear = 1;
	ca.addr_msb = addr >> 3;
	ca.addr_lsb = addr & 7;

	hram_regs->wq.attr = 0x30;
	hram_regs->wq.data = ca.dw[1];

	hram_regs->wq.attr = 0x20;
	hram_regs->wq.data = ca.dw[0];

	hram_regs->wq.attr = 0x00;
	hram_regs->wq.data = 0;

	hram_regs->cmd =
		HRAM_CMD_LEN(count) |
		HRAM_CMD_LAT(g_hram.cmd_lat) |
		HRAM_CMD_CS(cs) |
		HRAM_CMD_LEN(count) |
		HRAM_CMD_MEM |
		HRAM_CMD_READ;

	_hram_wait_idle();

	for (i=count; i<3; i++)
		(void)hram_regs->wq.data;
	
	for (i=0; i<count; i++) {
		*attr++ = hram_regs->wq.attr;
		*data++ = hram_regs->wq.data;
	}
}

void
hram_init(void)
{
	int cs;

	/* Config */
	g_hram.cmd_lat = 2;

	/* Reset HyperRAM and controller */
	hram_regs->csr = HRAM_CSR_RESET;
	_hram_wait_idle();
	hram_regs->csr = 0;
	_hram_wait_idle();

	/* Set chip config */
	g_hram.cr0.w = HRAM_CR0_BASE;
	g_hram.cr0.latency = HRAM_CR0_LAT_3;
	g_hram.cr0.fixed_latency = 1;
	g_hram.cr0.hybrid_burst = 1;
	g_hram.cr0.bl = HRAM_CR0_BL_128;

	for (cs=0; cs<4; cs++)
		_hram_reg_write(cs, HRAM_HWREG_CR0, g_hram.cr0.w);

	/* Set controller config */
	hram_regs->csr =
		HRAM_CSR_CMD_LAT(g_hram.cmd_lat) |
		HRAM_CSR_CAP_LAT(4) |
		HRAM_CSR_PHY_DELAY(0) |
		HRAM_CSR_PHY_PHASE(0) |
		HRAM_CSR_PHY_EDGE(0);

	/* Check */
	for (cs=0; cs<4; cs++)
	{
		_hram_mem_write(cs, 0, 0x600dbabe, 3);
		_hram_mem_write(cs, 2, 0xb16b00b5, 1);

		uint8_t  attr[3];
		uint32_t data[3];

		_hram_mem_read(cs, 0, data, attr, 3);

		printf("CS %d\n", cs);
		for (int i=0; i<3; i++)
			printf("%08x %02x\n", data[i], (uint32_t)attr[i]);
	}

	/* Switch to runtime mode */
	hram_regs->csr |= HRAM_CSR_RUN;
}
