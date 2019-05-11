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


// Hardware
// --------

struct e1_chan {
	uint32_t csr;
	uint32_t _rsvd0;
	uint32_t bd;
	uint32_t _rsvd1;
} __attribute__((packed,aligned(4)));

struct e1_core {
	struct e1_chan rx;
	struct e1_chan tx;
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

#define E1_TX_CR_ENABLE		(1 <<  0)
#define E1_TX_CR_MODE_TRSP	(0 <<  1)
#define E1_TX_CR_MODE_TS0	(1 <<  1)
#define E1_TX_CR_MODE_TS0_CRC	(2 <<  1)
#define E1_TX_CR_MODE_TS0_CRC_E	(3 <<  1)
#define E1_TX_CR_TICK_LOCAL	(0 <<  3)
#define E1_TX_CR_TICK_REMOTE	(1 <<  3)
#define E1_TX_CR_ALARM		(1 <<  4)
#define E1_TX_CR_LOOPBACK	(1 <<  5)
#define E1_TX_CR_UNFL_CLR	(1 << 12)
#define E1_TX_SR_ENABLED	(1 <<  0)
#define E1_TX_SR_BD_IN_EMPTY	(1 <<  8)
#define E1_TX_SR_BD_IN_FULL	(1 <<  9)
#define E1_TX_SR_BD_OUT_EMPTY	(1 << 10)
#define E1_TX_SR_BD_OUT_FULL	(1 << 11)
#define E1_TX_SR_UNFL		(1 << 12)

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
		int in_flight;
		enum e1_pipe_state state;
	} rx;

	struct {
		uint32_t cr;
		struct e1_fifo fifo;
		int in_flight;
		enum e1_pipe_state state;
	} tx;
} g_e1;




void
e1_init(bool clk_mode)
{
	/* Global state init */
	memset(&g_e1, 0x00, sizeof(g_e1));

	/* Reset FIFOs */
	e1f_reset(&g_e1.rx.fifo,   0, 128);
	e1f_reset(&g_e1.tx.fifo, 128, 128);

	/* Enable Rx */
	g_e1.rx.cr = E1_RX_CR_OVFL_CLR |
	             E1_RX_CR_MODE_MFA |
	             E1_RX_CR_ENABLE;
	e1_regs->rx.csr = g_e1.rx.cr;

	/* Enable Tx */
	g_e1.tx.cr = E1_TX_CR_UNFL_CLR |
	             (clk_mode ? E1_TX_CR_TICK_REMOTE : E1_TX_CR_TICK_LOCAL) |
	             E1_TX_CR_MODE_TS0_CRC_E |
		     E1_TX_CR_ENABLE;
	e1_regs->tx.csr = g_e1.tx.cr;

	/* State */
	g_e1.rx.state = BOOT;
	g_e1.tx.state = BOOT;
}


#include "dma.h"

unsigned int
e1_rx_need_data(unsigned int usb_addr, unsigned int max_frames)
{
	unsigned int ofs;
	int tot_frames = 0;
	int n_frames;

	while (max_frames) {
		/* Get some data from the FIFO */
		n_frames = e1f_frame_read(&g_e1.rx.fifo, &ofs, max_frames);
		if (!n_frames)
			break;

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
e1_tx_feed_data(unsigned int usb_addr, unsigned int frames)
{
	unsigned int ofs;
	int n_frames;

	while (frames) {
		/* Get some space in FIFO */
		n_frames = e1f_frame_write(&g_e1.tx.fifo, &ofs, frames);
		if (!n_frames) {
			printf("[!] TX FIFO Overflow %d %d\n", frames, n_frames);
			break;
		}

		/* Copy from USB to FIFO */
		dma_exec(e1f_ofs_to_dma(ofs), usb_addr, n_frames * (32 / 4), true, NULL, NULL);

		/* Prepare next */
		usb_addr += n_frames * (32 / 4);
		frames -= n_frames;

		/* Wait for DMA completion */
		while (dma_poll());
	}

	return frames;
}

unsigned int
e1_tx_level(void)
{
	return e1f_valid_frames(&g_e1.tx.fifo);
}

unsigned int
e1_rx_level(void)
{
	return e1f_valid_frames(&g_e1.rx.fifo);
}


void
e1_poll(void)
{
	uint32_t bd;
	unsigned int ofs;

	/* Active ? */
	if ((g_e1.rx.state == IDLE) && (g_e1.tx.state == IDLE))
		return;

	/* HACK: LED link status */
	if (e1_regs->rx.csr & 2)
		led_color(0, 48, 0);
	else
		led_color(48, 0, 0);

	/* Recover any done TX BD */
	while ( (bd = e1_regs->tx.bd) & E1_BD_VALID ) {
		e1f_multiframe_read_discard(&g_e1.tx.fifo);
		g_e1.tx.in_flight--;
	}

	/* Recover any done RX BD */
	while ( (bd = e1_regs->rx.bd) & E1_BD_VALID ) {
		/* FIXME: CRC status ? */
		e1f_multiframe_write_commit(&g_e1.rx.fifo);
		if (bd & (E1_BD_CRC0 | E1_BD_CRC1)) 
			printf("b: %03x\n", bd);
		g_e1.rx.in_flight--;
	}

	/* Boot procedure */
	if (g_e1.tx.state == BOOT) {
		if (e1f_unseen_frames(&g_e1.tx.fifo) < (16 * 5))
			return;
		/* HACK: LED flow status */
		led_blink(true, 200, 1000);
		led_breathe(true, 100, 200);
	}

	/* Handle RX */
		/* Misalign ? */
	if (g_e1.rx.state == RUN) {
		if (!(e1_regs->rx.csr & E1_RX_SR_ALIGNED)) {
			printf("[!] E1 rx misalign\n");
			g_e1.rx.state = RECOVER;
		}
	}

		/* Overflow ? */
	if (g_e1.rx.state == RUN) {
		if (e1_regs->rx.csr & E1_RX_SR_OVFL) {
			printf("[!] E1 overflow %d\n", g_e1.rx.in_flight);
			g_e1.rx.state = RECOVER;
		}
	}

		/* Recover ready ? */
	if (g_e1.rx.state == RECOVER) {
		if (g_e1.rx.in_flight != 0)
			goto done_rx;
		e1f_multiframe_empty(&g_e1.rx.fifo);
	}

		/* Fill new RX BD */
	while (g_e1.rx.in_flight < 4) {
		if (!e1f_multiframe_write_prepare(&g_e1.rx.fifo, &ofs))
			break;
		e1_regs->rx.bd = e1f_ofs_to_mf(ofs);
		g_e1.rx.in_flight++;
	}

		/* Clear overflow if needed */
	if (g_e1.rx.state != RUN) {
		e1_regs->rx.csr = g_e1.rx.cr | E1_RX_CR_OVFL_CLR;
		g_e1.rx.state = RUN;
	}
done_rx:

	/* Handle TX */
		/* Underflow ? */
	if (g_e1.tx.state == RUN) {
		if (e1_regs->tx.csr & E1_TX_SR_UNFL) {
			printf("[!] E1 underflow %d\n", g_e1.tx.in_flight);
			g_e1.tx.state = RECOVER;
		}
	}

		/* Recover ready ? */
	if (g_e1.tx.state == RECOVER) {
		if (e1f_unseen_frames(&g_e1.tx.fifo) < (16 * 5))
			return;
	}

		/* Fill new TX BD */
	while (g_e1.tx.in_flight < 4) {
		if (!e1f_multiframe_read_peek(&g_e1.tx.fifo, &ofs))
			break;
		e1_regs->tx.bd = e1f_ofs_to_mf(ofs);
		g_e1.tx.in_flight++;
	}

		/* Clear underflow if needed */
	if (g_e1.tx.state != RUN) {
		e1_regs->tx.csr = g_e1.tx.cr | E1_TX_CR_UNFL_CLR;
		g_e1.tx.state = RUN;
	}
}

void
e1_debug_print(bool data)
{
	volatile uint8_t *p;

	puts("E1\n");
	printf("CSR: Rx %04x / Tx %04x\n", e1_regs->rx.csr, e1_regs->tx.csr);
	printf("InF: Rx %d / Tx %d\n", g_e1.rx.in_flight, g_e1.tx.in_flight);
	printf("Sta: Rx %d / Tx %d\n", g_e1.rx.state, g_e1.tx.state);

	e1f_debug(&g_e1.rx.fifo, "Rx FIFO");
	e1f_debug(&g_e1.tx.fifo, "Tx FIFO");

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
