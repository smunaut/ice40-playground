/*
 * e1.c
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

#include "config.h"
#include "console.h"
#include "e1.h"

#include "dma.h"
#include "led.h" // FIXME
#include "usb.h"


// Hardware
// --------

struct e1_chan {
	uint32_t csr;
	uint32_t _rsvd0;
	uint32_t bd;
	uint32_t _rsvd1;
} __attribute__((packed,aligned(4)));

struct e1_core {
	struct e1_chan rx[2];
} __attribute__((packed,aligned(4)));

#define E1_RX_CR_ENABLE		(1 <<  0)
#define E1_RX_CR_MODE_TRSP	(0 <<  1)
#define E1_RX_CR_MODE_BYTE	(1 <<  1)
#define E1_RX_CR_MODE_BFA	(2 <<  1)
#define E1_RX_CR_MODE_MFA	(3 <<  1)
#define E1_RX_CR_OVFL_CLR	(1 << 12)
#define E1_RX_SR_ENABLED	(1 <<  0)
#define E1_RX_SR_ALIGNED	(1 <<  1)
#define E1_RX_SR_BD_IN_EMPTY	(1 <<  8)
#define E1_RX_SR_BD_IN_FULL	(1 <<  9)
#define E1_RX_SR_BD_OUT_EMPTY	(1 << 10)
#define E1_RX_SR_BD_OUT_FULL	(1 << 11)
#define E1_RX_SR_OVFL		(1 << 12)

#define E1_BD_VALID		(1 << 15)
#define E1_BD_CRC1		(1 << 14)
#define E1_BD_CRC0		(1 << 13)
#define E1_BD_ADDR(x)		((x) & 0x7f)
#define E1_BD_ADDR_MSK		0x7f
#define E1_BD_ADDR_SHFT		0


static volatile struct e1_core * const e1_regs = (void *)(E1_CORE_BASE);
static volatile uint8_t * const e1_data = (void *)(E1_DATA_BASE);


volatile uint8_t *
e1_data_ptr(int mf, int frame, int ts)
{
	return &e1_data[(mf << 9) | (frame << 5) | ts];
}

unsigned int
e1_data_ofs(int mf, int frame, int ts)
{
	return (mf << 9) | (frame << 5) | ts;
}


// FIFOs
// -----
/* Note: FIFO works at 'frame' level (i.e. 32 bytes) */

struct e1_fifo {
	/* Buffer zone associated with the FIFO */
	unsigned int base;
	unsigned int mask;

	/* Pointers / Levels */
	unsigned int wptr[2];	/* 0=committed 1=allocated */
	unsigned int rptr[2];	/* 0=discared  1=peeked    */
};

	/* Utils */
static void
e1f_reset(struct e1_fifo *fifo, unsigned int base, unsigned int len)
{
	memset(fifo, 0x00, sizeof(struct e1_fifo));
	fifo->base = base;
	fifo->mask = len - 1;
}

static unsigned int
e1f_allocd_frames(struct e1_fifo *fifo)
{
	/* Number of frames that are allocated (i.e. where we can't write to) */
	return (fifo->wptr[1] - fifo->rptr[0]) & fifo->mask;
}

static unsigned int
e1f_valid_frames(struct e1_fifo *fifo)
{
	/* Number of valid frames */
	return (fifo->wptr[0] - fifo->rptr[0]) & fifo->mask;
}

static unsigned int
e1f_unseen_frames(struct e1_fifo *fifo)
{
	/* Number of valid frames that haven't been peeked yet */
	return (fifo->wptr[0] - fifo->rptr[1]) & fifo->mask;
}

static unsigned int
e1f_free_frames(struct e1_fifo *fifo)
{
	/* Number of frames that aren't allocated */
	return (fifo->rptr[0] - fifo->wptr[1] - 1) & fifo->mask;
}

static unsigned int
e1f_ofs_to_dma(unsigned int ofs)
{
	/* DMA address are 32-bits word address. Offsets are 32 byte address */
	return (ofs << 3);
}

static unsigned int
e1f_ofs_to_mf(unsigned int ofs)
{
	/* E1 Buffer Descriptors are always multiframe aligned */
	return (ofs >> 4);
}


	/* Debug */
static void
e1f_debug(struct e1_fifo *fifo, const char *name)
{
	unsigned int la, lv, lu, lf;

	la = e1f_allocd_frames(fifo);
	lv = e1f_valid_frames(fifo);
	lu = e1f_unseen_frames(fifo);
	lf = e1f_free_frames(fifo);

	printf("%s: R: %u / %u | W: %u / %u | A:%u  V:%u  U:%u  F:%u\n",
		name,
		fifo->rptr[0], fifo->rptr[1], fifo->wptr[0], fifo->wptr[1],
		la, lv, lu, lf
	);
}

	/* Frame level read/write */
static unsigned int
e1f_frame_write(struct e1_fifo *fifo, unsigned int *ofs, unsigned int max_frames)
{
	unsigned int lf, le;

	lf = e1f_free_frames(fifo);
	le = fifo->mask - fifo->wptr[0] + 1;

	if (max_frames > le)
		max_frames = le;
	if (max_frames > lf)
		max_frames = lf;

	*ofs = fifo->base + fifo->wptr[0];
	fifo->wptr[1] = fifo->wptr[0] = (fifo->wptr[0] + max_frames) & fifo->mask;

	return max_frames;
}

static unsigned int
e1f_frame_read(struct e1_fifo *fifo, unsigned int *ofs, int max_frames)
{
	unsigned int lu, le;

	lu = e1f_unseen_frames(fifo);
	le = fifo->mask - fifo->rptr[1] + 1;

	if (max_frames > le)
		max_frames = le;
	if (max_frames > lu)
		max_frames = lu;

	*ofs = fifo->base + fifo->rptr[1];
	fifo->rptr[0] = fifo->rptr[1] = (fifo->rptr[1] + max_frames) & fifo->mask;

	return max_frames;
}


	/* MultiFrame level split read/write */
static bool
e1f_multiframe_write_prepare(struct e1_fifo *fifo, unsigned int *ofs)
{
	unsigned int lf;

	lf = e1f_free_frames(fifo);
	if (lf < 16)
		return false;

	*ofs = fifo->base + fifo->wptr[1];
	fifo->wptr[1] = (fifo->wptr[1] + 16) & fifo->mask;

	return true;
}

static void
e1f_multiframe_write_commit(struct e1_fifo *fifo)
{
	fifo->wptr[0] = (fifo->wptr[0] + 16) & fifo->mask;
}

static bool
e1f_multiframe_read_peek(struct e1_fifo *fifo, unsigned int *ofs)
{
	unsigned int lu;

	lu = e1f_unseen_frames(fifo);
	if (lu < 16)
		return false;

	*ofs = fifo->base + fifo->rptr[1];
	fifo->rptr[1] = (fifo->rptr[1] + 16) & fifo->mask;

	return true;
}

static void
e1f_multiframe_read_discard(struct e1_fifo *fifo)
{
	fifo->rptr[0] = (fifo->rptr[0] + 16) & fifo->mask;
}

static void
e1f_multiframe_empty(struct e1_fifo *fifo)
{
	fifo->rptr[0] = fifo->rptr[1] = (fifo->wptr[0] & ~15);
}



// Main logic
// ----------

enum e1_pipe_state {
	IDLE	= 0,
	BOOT	= 1,
	RUN	= 2,
	RECOVER	= 3,
};

static struct {
	struct {
		uint32_t cr;
		struct e1_fifo fifo;
		short in_flight;
		enum e1_pipe_state state;
		uint8_t flags;
	} rx[2];
	uint32_t error;
} g_e1;


void
e1_init(void)
{
	/* Global state init */
	memset(&g_e1, 0x00, sizeof(g_e1));
}

void
e1_start(void)
{
	/* Reset FIFOs */
	e1f_reset(&g_e1.rx[0].fifo,   0, 128);
	e1f_reset(&g_e1.rx[1].fifo, 128, 128);

	/* Enable Rx0 */
	g_e1.rx[0].cr = E1_RX_CR_OVFL_CLR |
	                E1_RX_CR_MODE_MFA |
	                E1_RX_CR_ENABLE;
	e1_regs->rx[0].csr = g_e1.rx[0].cr;

	/* Enable Rx1 */
	g_e1.rx[1].cr = E1_RX_CR_OVFL_CLR |
	                E1_RX_CR_MODE_MFA |
	                E1_RX_CR_ENABLE;
	e1_regs->rx[1].csr = g_e1.rx[1].cr;

	/* State */
	g_e1.rx[0].state = BOOT;
	g_e1.rx[0].in_flight = 0;
	g_e1.rx[0].flags = 0;

	g_e1.rx[1].state = BOOT;
	g_e1.rx[1].in_flight = 0;
	g_e1.rx[1].flags = 0;
}

void
e1_stop()
{
	/* Disable RX0 */
	g_e1.rx[0].cr = 0;
	e1_regs->rx[0].csr = g_e1.rx[0].cr;

	/* Disable RX1 */
	g_e1.rx[1].cr = 0;
	e1_regs->rx[1].csr = g_e1.rx[1].cr;

	/* State */
	g_e1.rx[0].state = IDLE;
	g_e1.rx[1].state = IDLE;
}


#include "dma.h"

unsigned int
e1_rx_need_data(int chan, unsigned int usb_addr, unsigned int max_frames, unsigned int *pos)
{
	unsigned int ofs;
	int tot_frames = 0;
	int n_frames;

	while (max_frames) {
		/* Get some data from the FIFO */
		n_frames = e1f_frame_read(&g_e1.rx[chan].fifo, &ofs, max_frames);
		if (!n_frames)
			break;

		/* Give pos */
		if (pos) {
			*pos = ofs & g_e1.rx[chan].fifo.mask;
			pos = NULL;
		}

		/* Copy from FIFO to USB */
		dma_exec(e1f_ofs_to_dma(ofs), usb_addr, n_frames * (32 / 4), false, NULL, NULL);

		/* Prepare Next */
		usb_addr += n_frames * (32 / 4);
		max_frames -= n_frames;
		tot_frames += n_frames;

		/* Wait for DMA completion */
		while (dma_poll());
	}

	return tot_frames;
}

unsigned int
e1_rx_level(int chan)
{
	return e1f_valid_frames(&g_e1.rx[chan].fifo);
}

uint8_t
e1_get_pending_flags(int chan)
{
	uint8_t f = g_e1.rx[chan].flags;
	g_e1.rx[chan].flags = 0;
	return f;
}


#define ERR_TIME 1000

void
e1_poll(void)
{
	uint32_t bd;
	unsigned int ofs;
	int chan;
	bool error = false;

	/* HACK: LED link status */
	if ((g_e1.rx[0].state == IDLE) && (g_e1.rx[1].state == IDLE))
	{
		/* Static dim red */
		led_color(32, 0, 0);
		led_blink(false, 0, 0);
	} else {
		uint32_t csr[2];

		csr[0] = e1_regs->rx[0].csr;
		csr[1] = e1_regs->rx[1].csr;

		if (!((csr[0] & csr[1]) & E1_RX_SR_ALIGNED))
			error = true;

		/* Color is current SYNC status */
		led_color(
			error ? 1 : 0,
			csr[0] & E1_RX_SR_ALIGNED ?  48 : 0,
			csr[1] & E1_RX_SR_ALIGNED ? 112 : 0
		);
	}

	/* Active ? */
	if ((g_e1.rx[0].state == IDLE) && (g_e1.rx[1].state == IDLE))
		return;

	/* Recover any done RX BD */
	for (chan=0; chan<2; chan++)
	{
		while ( (bd = e1_regs->rx[chan].bd) & E1_BD_VALID ) {
			/* FIXME: CRC status ? */
			e1f_multiframe_write_commit(&g_e1.rx[chan].fifo);
			if (bd & (E1_BD_CRC0 | E1_BD_CRC1)) {
				printf("b: %03x\n", bd);
				g_e1.rx[chan].flags |= 4;
				error = true;
			}
			g_e1.rx[chan].in_flight--;
		}
	}

	/* Handle RX */
	for (chan=0; chan<2; chan++)
	{
			/* Misalign ? */
		if (g_e1.rx[chan].state == RUN) {
			if (!(e1_regs->rx[chan].csr & E1_RX_SR_ALIGNED)) {
				printf("[!] E1 rx misalign\n");
				g_e1.rx[chan].state = RECOVER;
				g_e1.rx[chan].flags |= 1;
				error = true;
			}
		}

			/* Overflow ? */
		if (g_e1.rx[chan].state == RUN) {
			if (e1_regs->rx[chan].csr & E1_RX_SR_OVFL) {
				printf("[!] E1 overflow %d\n", g_e1.rx[chan].in_flight);
				g_e1.rx[chan].state = RECOVER;
				g_e1.rx[chan].flags |= 2;
			}
		}

			/* Recover ready ? */
		if (g_e1.rx[chan].state == RECOVER) {
			if (g_e1.rx[chan].in_flight != 0)
				continue;
			e1f_multiframe_empty(&g_e1.rx[chan].fifo);
		}

			/* Fill new RX BD */
		while (g_e1.rx[chan].in_flight < 4) {
			if (!e1f_multiframe_write_prepare(&g_e1.rx[chan].fifo, &ofs))
				break;
			e1_regs->rx[chan].bd = e1f_ofs_to_mf(ofs);
			g_e1.rx[chan].in_flight++;
		}

			/* Clear overflow if needed */
		if (g_e1.rx[chan].state != RUN) {
			e1_regs->rx[chan].csr = g_e1.rx[chan].cr | E1_RX_CR_OVFL_CLR;
			g_e1.rx[chan].state = RUN;
		}
	}

	/* Error tracking */
	if (error) {
		if (!g_e1.error) {
			printf("Error LED\n");
			led_blink(true, 150, 150);
		}
		g_e1.error = usb_get_tick() + ERR_TIME;
	} else if (g_e1.error && (g_e1.error < usb_get_tick())) {
		g_e1.error = 0;
		led_blink(false, 0, 0);
		printf("No error\n");
	}

}

void
e1_debug_print(bool data)
{
	volatile uint8_t *p;

	puts("E1\n");
	printf("CSR: Rx0 %04x / Rx1 %04x\n", e1_regs->rx[0].csr, e1_regs->rx[1].csr);
	printf("InF: Rx0 %d / Rx1 %d\n", g_e1.rx[0].in_flight, g_e1.rx[1].in_flight);
	printf("Sta: Rx0 %d / Rx1 %d\n", g_e1.rx[0].state, g_e1.rx[1].state);

	e1f_debug(&g_e1.rx[0].fifo, "Rx0 FIFO");
	e1f_debug(&g_e1.rx[1].fifo, "Rx1 FIFO");

	if (data) {
		puts("\nE1 Data\n");
		for (int f=0; f<16; f++) {
			p = e1_data_ptr(0, f, 0);
			for (int ts=0; ts<32; ts++)
				printf(" %02x", p[ts]);
			printf("\n");
		}
	}
}
