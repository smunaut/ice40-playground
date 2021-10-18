/*
 * config.h
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

#pragma once

#define _IO_BASE(n)	(0x80000000 | ((n) << 24))

#define MISC_BASE	_IO_BASE(0)
#define I2C_BASE	_IO_BASE(1)
#define QPI_BASE	_IO_BASE(2)
#define DMA_BASE	_IO_BASE(3)
#define USB_DATA_BASE	_IO_BASE(4)
#define USB_CORE_BASE	_IO_BASE(5)
#define FRAMEGRAB_BASE	_IO_BASE(6)
#define LED_BASE	_IO_BASE(7)
