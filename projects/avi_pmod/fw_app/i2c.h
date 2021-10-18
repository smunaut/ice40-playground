/*
 * i2c.h
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

void i2c_write_reg(uint8_t dev, uint8_t reg, uint8_t val);
bool i2c_read_reg(uint8_t dev, uint8_t reg);
