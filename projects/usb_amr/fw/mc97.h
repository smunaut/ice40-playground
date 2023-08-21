/*
 * mc97.h
 *
 * MC97 controller
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>


enum mc97_hook_state {
	ON_HOOK,
	CALLER_ID,
	OFF_HOOK,
};

enum mc97_loopback_mode {
	MC97_LOOPBACK_NONE		= 0x0,
	MC97_LOOPBACK_DIGITAL_ADC	= 0x1,
	MC97_LOOPBACK_ANALOG_LOCAL	= 0x2,
	MC97_LOOPBACK_DIGITAL_DAC	= 0x3,
	MC97_LOOPBACK_ANALOG_REMOTE	= 0x4,
	MC97_LOOPBACK_ISOCAP		= 0x5,	/* Sil3038 */
	MC97_LOOPBACK_ANALOG_EXTERNAL	= 0x6,	/* Sil3038 */
};

#define MC97_FIFO_SIZE 256


void     mc97_codec_reg_write(uint8_t addr, uint16_t val);
uint16_t mc97_codec_reg_read(uint8_t addr);

void     mc97_init(void);
void     mc97_debug(void);
bool     mc97_select_country(int cc);

void     mc97_set_aux_relay(bool disconnect);
void     mc97_set_hook(enum mc97_hook_state s);
void     mc97_test_ring(void);
bool     mc97_get_ring_detect(void);
void     mc97_set_loopback(enum mc97_loopback_mode m);

uint8_t  mc97_get_rx_gain(void);
void     mc97_set_rx_gain(uint8_t gain);
bool     mc97_get_rx_mute(void);
void     mc97_set_rx_mute(bool mute);
uint8_t  mc97_get_tx_attenuation(void);
void     mc97_set_tx_attenuation(uint8_t attenuation);
bool     mc97_get_tx_mute(void);
void     mc97_set_tx_mute(bool mute);

void     mc97_flow_rx_reset(void);
void     mc97_flow_rx_start(void);
void     mc97_flow_rx_stop(void);
int      mc97_flow_rx_pull(int16_t *data, int n);
int      mc97_flow_rx_level(void);
bool     mc97_flow_rx_active(void);

void     mc97_flow_tx_reset(void);
void     mc97_flow_tx_start(void);
void     mc97_flow_tx_stop(void);
int      mc97_flow_tx_push(int16_t *data, int n);
int      mc97_flow_tx_level(void);
bool     mc97_flow_tx_active(void);
