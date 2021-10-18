/*
 * i2c.c
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#include <stdint.h>
#include <stdbool.h>

#include "config.h"


struct i2c {
	uint32_t csr;
} __attribute__((packed,aligned(4)));

#define I2C_CMD_START	(0 << 12)
#define I2C_CMD_STOP	(1 << 12)
#define I2C_CMD_WRITE	(2 << 12)
#define I2C_CMD_READ	(3 << 12)

#define I2C_GET_RESP	(1 << 15)
#define I2C_ACK		(1 <<  8)


static volatile struct i2c * const i2c_regs = (void*)(I2C_BASE);


static inline uint32_t
_i2c_wait(void)
{
	uint32_t v;

	do {
		v = i2c_regs->csr;
	} while (!(v & (1 << 31)));

	return v & 0x1ff;
}

static void
i2c_start(void)
{
	i2c_regs->csr = I2C_CMD_START;
}

static void
i2c_stop(void)
{
	i2c_regs->csr = I2C_CMD_STOP;
}

static void
i2c_write(uint8_t data)
{
	i2c_regs->csr = I2C_CMD_WRITE | data;
}

static uint8_t
i2c_read(bool ack)
{
	i2c_regs->csr = I2C_CMD_READ | I2C_GET_RESP | (ack ? I2C_ACK : 0);
	return _i2c_wait() & 0xff;
}


void
i2c_write_reg(uint8_t dev, uint8_t reg, uint8_t val)
{
	i2c_start();
	i2c_write(dev);
	i2c_write(reg);
	i2c_write(val);
	i2c_stop();
}

uint8_t
i2c_read_reg(uint8_t dev, uint8_t reg)
{
	uint8_t v;
	i2c_start();
	i2c_write(dev);
	i2c_write(reg);
	i2c_start();
	i2c_write(dev|1);
	v = i2c_read(false);
	i2c_stop();
	return v;
}
