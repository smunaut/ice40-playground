/*
 * framegrab.h
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>


void framegrab_init(void);
void framegrab_start(void);
void framegrab_stop(void);
void framegrab_poll(void);

uint8_t framegrab_get_latest(void);
void    framegrab_release(uint8_t frame);

void framegrab_debug(void);


struct dma_state
{
	/* Frame ID */
	uint8_t frame;

	/* Current position */
	int y;
	int x;
};

void dma_start(struct dma_state *ds, uint8_t frame);
bool dma_fill_pkt(struct dma_state *ds, uint32_t ptr, int *len);
bool dma_done(void);
