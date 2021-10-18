/*
 * framegrab.c
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "config.h"

#include "console.h"
#include "framegrab.h"


/* DMA Hardware */

struct dma {
	uint32_t csr;
	uint32_t _rsvd;
	uint32_t cmd_eaddr;
	uint32_t cmd_iaddr_len_id;
} __attribute__((packed,aligned(4)));

#define DMA_CSR_FIFO_EMPTY	(1 << 7)
#define DMA_CSR_FIFO_FULL	(1 << 6)
#define DMA_CSR_BUSY		(1 << 3)

#define DMA_ID(i)		((  (i)          &   0xff) << 24)
#define DMA_LEN(l)		(((((l) >> 2)-1) &   0x7f) << 16)
#define DMA_IADDR(a)		((( (a) >> 2   ) & 0xffff) <<  0)
#define DMA_EADDR(a)		((a) >> 2)

static volatile struct dma * const dma_regs = (void*)(DMA_BASE);


/* Frame grabber hardware */

struct framegrab {
	uint32_t csr;
	uint32_t fifo;
} __attribute__((packed,aligned(4)));

#define FG_CSR_PDESC_FULL	(1 << 15)
#define FG_CSR_PDESC_EMPTY	(1 << 14)
#define FG_CSR_PDESC_OVERFLOW	(1 << 13)
#define FG_CSR_PDESC_UNDERFLOW	(1 << 12)

#define FG_CSR_DDESC_FULL	(1 << 11)
#define FG_CSR_DDESC_EMPTY	(1 << 10)
#define FG_CSR_DDESC_OVERFLOW	(1 <<  9)

#define FG_CSR_FRAME_CAP_ENA	(1 <<  3)
#define FG_CSR_PIXEL_CAP_ENA	(1 <<  2)
#define FG_CSR_PIXEL_FIFO_ENA	(1 <<  1)
#define FG_CSR_VIDEO_IN_ENA	(1 <<  0)

#define FG_PD_FRAME_ID(i)	(((i) & 0xf) << 26)
#define FG_PD_MEM_BASE(b)	((((b) >> 10) & 0x3fff) << 12)
#define FG_PD_MEM_LEN(l)	(((((l) >> 10) - 1) &  0xfff) <<  0)

#define FG_DD_IS_VALID(d)	((d) & (1 << 31))
#define FG_DD_IS_FRAME_OK(d)	((d) & (1 << 30))
#define FG_DD_GET_FRAME_ID(d)	(((d) >> 26) & 0x00f)
#define FG_DD_GET_HTOTAL(d)	(((((d) >> 16) & 0x3ff) + 1) << 1)
#define FG_DD_GET_VBLANK(d)	(((d) >> 10) & 0x03f)
#define FG_DD_GET_VTOTAL(d)	(((d) >>  0) & 0x3ff)

static volatile struct framegrab * const fg_regs = (void*)(FRAMEGRAB_BASE);


/* Frame grabber API */

enum frame_state {
	INVALID = 0,
	FILLING = 1,
	VALID   = 2,
	LOCKED  = 3,
};

struct frame_link {
	uint8_t prev;
	uint8_t next;
};

struct frame {
	struct frame_link link;

	uint32_t mem_base;
	uint32_t mem_len;
	uint32_t timestamp;

	enum frame_state state;

	uint16_t h_blank;
	uint16_t h_total;
	uint16_t v_blank;
	uint16_t v_total;
};


#define FRAMES_COUNT	6
#define FRAMES_LEN	((1024 + 128) * 1024)

struct {
	bool     active;
	uint32_t timestamp;
	uint8_t  next_frame;		/* Next frame to fill */

	struct frame frames[FRAMES_COUNT];
} g_fg;



static void
_framegrab_fill_descriptors(void)
{
	while (!(fg_regs->csr & FG_CSR_PDESC_FULL))
	{
		uint8_t fid = g_fg.next_frame;
		struct frame *f = &g_fg.frames[fid];

		fg_regs->fifo = \
			FG_PD_FRAME_ID(fid) |
			FG_PD_MEM_LEN(f->mem_len) |
			FG_PD_MEM_BASE(f->mem_base);

		f->state = FILLING;

		g_fg.next_frame = f->link.next;
	}
}

void
framegrab_init(void)
{
	int i;

	/* Software state init */
	memset(&g_fg, 0x00, sizeof(g_fg));

	for (i=0; i<FRAMES_COUNT; i++)
	{
		struct frame *f = &g_fg.frames[i];
		f->mem_base = FRAMES_LEN * i;
		f->mem_len  = FRAMES_LEN;
	}

	/* Hardware startup */
		/* Disable all */
	fg_regs->csr = 0;

		/* Enable ingress logic */
	fg_regs->csr |= FG_CSR_VIDEO_IN_ENA;

		/* Enable pixel FIFO */
	fg_regs->csr |= FG_CSR_PIXEL_FIFO_ENA;

		/* Enable pixel FIFO capture */
	fg_regs->csr |= FG_CSR_PIXEL_CAP_ENA;
}

void
framegrab_start(void)
{
	int i;

	/* Reset links and state */
	for (i=0; i<FRAMES_COUNT; i++)
	{
		struct frame *f = &g_fg.frames[i];

		f->link.prev = (i + FRAMES_COUNT - 1) % FRAMES_COUNT;
		f->link.next = (i + FRAMES_COUNT + 1) % FRAMES_COUNT;

		f->state = INVALID;
	}

	g_fg.next_frame = 0;

	/* Preload descriptors */
	_framegrab_fill_descriptors();

	/* Enable hardware frame grab process */
	fg_regs->csr |= FG_CSR_FRAME_CAP_ENA;

	/* We're active ! */
	g_fg.active = true;
}

void
framegrab_stop(void)
{
	/* Done for now */
	g_fg.active = false;
}

void
framegrab_poll(void)
{
	uint32_t dd;

	/* Retire all done frames */
	while (FG_DD_IS_VALID(dd = fg_regs->fifo))
	{
		int fid = FG_DD_GET_FRAME_ID(dd);
		struct frame *f = &g_fg.frames[fid];

		if (!FG_DD_IS_FRAME_OK(dd)) {
			printf("Invalid frame ? %08x", dd);
			f->state = INVALID;
		} else {
			f->timestamp = g_fg.timestamp++;
			f->state     = VALID;
			f->h_blank   = 144;	/* FIXME */
			f->h_total   = FG_DD_GET_HTOTAL(dd);
			f->v_blank   = FG_DD_GET_VBLANK(dd);
			f->v_total   = FG_DD_GET_VTOTAL(dd);
		}
	}

	/* Are we active ? */
	if (g_fg.active) {
		/* Fill back up */
		_framegrab_fill_descriptors();
	} else {
		/* If we're still enabled, wait until the pending FIFO
		 * is empty to disable hw */
		uint32_t csr = fg_regs->csr;

		if ((csr & FG_CSR_FRAME_CAP_ENA) && (csr & FG_CSR_PDESC_UNDERFLOW)) {
			/* Disable hardware frame grab process */
			fg_regs->csr &= ~FG_CSR_FRAME_CAP_ENA;
		}
	}
}


uint8_t
framegrab_get_latest(void)
{
	struct frame *f = &g_fg.frames[g_fg.next_frame];
	uint8_t fid;

	while (f->link.prev != g_fg.next_frame) {
		/* Go back */
		f = &g_fg.frames[fid = f->link.prev];

		/* Is it valid ? */
		if (f->state == VALID) {
			/* Yes ! Grab it */
			struct frame *fn = &g_fg.frames[f->link.next];
			struct frame *fp = &g_fg.frames[f->link.prev];

			fn->link.prev = f->link.prev;
			fp->link.next = f->link.next;

			f->link.next = f->link.prev = 0xff;

			return fid;
		}
	}

	return 0xff;
}

void
framegrab_release(uint8_t frame)
{
	struct frame *fc = &g_fg.frames[frame];
	struct frame *fn = &g_fg.frames[g_fg.next_frame];
	struct frame *fp = &g_fg.frames[fn->link.prev];

	/* Re-insert as the 'next' */
	fc->link.next = g_fg.next_frame;
	fc->link.prev = fn->link.prev;
	fn->link.prev = frame;
	fp->link.next = frame;

	g_fg.next_frame = frame;

	/* Mark as 'invalid' */
	fc->state = INVALID;
}


void
framegrab_debug(void)
{
	uint32_t v;
	int i;

	v = fg_regs->csr;
	printf("HW CSR     : %08x");
	if (v & FG_CSR_PDESC_FULL)	printf(" pd_full");
	if (v & FG_CSR_PDESC_EMPTY)	printf(" pd_empty");
	if (v & FG_CSR_PDESC_OVERFLOW)	printf(" pd_overflow");
	if (v & FG_CSR_PDESC_UNDERFLOW)	printf(" pd_underflow");
	if (v & FG_CSR_DDESC_FULL)	printf(" dd_full");
	if (v & FG_CSR_DDESC_EMPTY)	printf(" dd_empty");
	if (v & FG_CSR_DDESC_OVERFLOW)	printf(" dd_overflow");
	if (v & FG_CSR_FRAME_CAP_ENA)	printf(" frame_cap_ena");
	if (v & FG_CSR_PIXEL_CAP_ENA)	printf(" pixel_cap_ena");
	if (v & FG_CSR_PIXEL_FIFO_ENA)	printf(" pixel_fifo_ena");
	if (v & FG_CSR_VIDEO_IN_ENA)	printf(" video_in_ena");
	printf("\n");

	printf("Active     : %d\n", g_fg.active);
	printf("Timestamp  : %d\n", g_fg.timestamp);
	printf("Next Frame : %d\n", g_fg.next_frame);

	for (i=0; i<FRAMES_COUNT; i++) {
		printf(" .frame[%d] : [%d %d], %08x/%08x, %d %d, %d:%d:%d:%d\n", i,
			g_fg.frames[i].link.prev,
			g_fg.frames[i].link.next,
			g_fg.frames[i].mem_base,
			g_fg.frames[i].mem_len,
			g_fg.frames[i].timestamp,
			g_fg.frames[i].state,
			g_fg.frames[i].h_blank,
			g_fg.frames[i].h_total,
			g_fg.frames[i].v_blank,
			g_fg.frames[i].v_total
		);
	}
}


void
dma_start(struct dma_state *ds, uint8_t frame)
{
	struct frame *f = &g_fg.frames[frame];

	ds->frame = frame;
	ds->y = f->v_blank;
	ds->x = f->h_blank;
}

bool
dma_fill_pkt(struct dma_state *ds, uint32_t ptr, int *len)
{
	struct frame *f = &g_fg.frames[ds->frame];
	int l = *len;
	int o = 0;
	int blen;
	uint32_t eaddr;
	bool done = false;

	while (!done && (l > 0)) {
		/* Burst len */
			/* Whatever is left on the current line */
		blen = 2 * (f->h_total - ds->x);

			/* Limit to whatever size is left in packet */
		if (blen > l)
			blen = l;

			/* And limit to 512 bytes bursts */
		if (blen > 512)
			blen = 512;

			/* Always multiple of 4 */
		blen &= ~3;

		/* Address in external RAM */
		eaddr = f->mem_base + 2 * (
			(ds->y * f->h_total) +
			(ds->x             )
		);

		/* Submit command */
		dma_regs->cmd_iaddr_len_id = \
			DMA_ID(0) | /* not used */
			DMA_LEN(blen) |
			DMA_IADDR(ptr);

		dma_regs->cmd_eaddr = DMA_EADDR(eaddr);

		/* Prepare for next */
		l     -= blen;
		ptr   += blen;
		o     += blen;

		ds->x += (blen >> 1);
		if (ds->x == f->h_total) {
			ds->x = f->h_blank;
			ds->y += 1;
			if (ds->y == f->v_total)
				done = true;
		}
	};

	*len = o;

	return done;
}

bool
dma_done(void)
{
	return !(dma_regs->csr & DMA_CSR_BUSY);
}

