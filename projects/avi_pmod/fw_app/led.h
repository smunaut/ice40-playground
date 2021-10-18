/*
 * led.h
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>

void led_init(void);
void led_color(uint8_t r, uint8_t g, uint8_t b);
void led_state(bool on);
void led_blink(bool enabled, int on_time_ms, int off_time_ms);
void led_breathe(bool enabled, int rise_time_ms, int fall_time_ms);
