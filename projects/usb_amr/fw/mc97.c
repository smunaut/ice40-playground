/*
 * mc97.c
 *
 * MC97 controller
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

#include <stdbool.h>
#include <stdint.h>

#include "console.h"
#include "mc97.h"
#include "mc97_country.h"

#include "config.h"


struct wb_mc97 {
	uint32_t csr;
	uint32_t lls;
	uint32_t cra;
	uint32_t _rsvd;
	uint32_t gpio_in;
	uint32_t gpio_out;
	uint32_t fifo_data;
	uint32_t fifo_csr;
} __attribute__((packed,aligned(4)));

#define MC97_CSR_GPIO_ENA		(1 <<  2)
#define MC97_CSR_RESET_N		(1 <<  1)
#define MC97_CSR_RUN			(1 <<  0)

#define MC97_LLS_CODEC_READY		(1 << 31)
#define MC97_LLS_SLOT_REQ(n)		(1 << ((n)+16))
#define MC97_LLS_SLOT_VALID(n)		(1 << ((n)+16))

#define MC97_CRA_BUSY			(1 << 31)
#define MC97_CRA_WRITE			(1 << 30)
#define MC97_CRA_READ_ERR		(1 << 29)
#define MC97_CRA_ADDR(x)		(((x) >> 1) << 16)
#define MC97_CRA_VAL(x)			(x)
#define MC97_CRA_GET_VAL(x)		((x) & 0xffff)

#define MC97_FIFO_DATA_EMPTY		(1 << 31)

#define MC97_FIFO_CSR_PCM_IN_ENABLE	(1 << 31)
#define MC97_FIFO_CSR_PCM_IN_FLUSH	(1 << 30)
#define MC97_FIFO_CSR_PCM_IN_FULL	(1 << 29)
#define MC97_FIFO_CSR_PCM_IN_EMPTY	(1 << 28)
#define MC97_FIFO_CSR_PCM_IN_LEVEL(x)	(((x) >> 16) & 0xfff)

#define MC97_FIFO_CSR_PCM_OUT_ENABLE	(1 << 15)
#define MC97_FIFO_CSR_PCM_OUT_FLUSH	(1 << 14)
#define MC97_FIFO_CSR_PCM_OUT_FULL	(1 << 13)
#define MC97_FIFO_CSR_PCM_OUT_EMPTY	(1 << 12)
#define MC97_FIFO_CSR_PCM_OUT_LEVEL(x)	((x) & 0xfff)


static volatile struct wb_mc97 * const mc97_regs = (void*)(MC97_BASE);


static struct {
	uint16_t rc_46;	/* Cache of reg 0x46 */
	uint16_t rc_5c; /* Cache of reg 0x5c */
	uint16_t rc_62; /* Cache of reg 0x62 */
} g_mc97;



void
mc97_codec_reg_write(uint8_t addr, uint16_t val)
{
	/* Submit request */
	mc97_regs->cra =
		MC97_CRA_WRITE |
		MC97_CRA_ADDR(addr) |
		MC97_CRA_VAL(val);

	/* Wait until not busy */
	while (mc97_regs->cra & MC97_CRA_BUSY);
}

uint16_t
mc97_codec_reg_read(uint8_t addr)
{
	uint32_t v;

	/* Submit request */
	mc97_regs->cra = MC97_CRA_ADDR(addr);

	/* Wait until not busy */
	while ((v = mc97_regs->cra) & MC97_CRA_BUSY);

	/* Check for read errors */
	if (v & MC97_CRA_READ_ERR)
		return 0xffff; /* Not much we can do */

	/* Return result */
	return MC97_CRA_GET_VAL(v);
}


void
mc97_init(void)
{
	/* Initialize controller and reset codec */
	mc97_regs->csr = MC97_CSR_RUN;
	mc97_regs->csr = MC97_CSR_RUN | MC97_CSR_RESET_N | MC97_CSR_GPIO_ENA;

	/* Init the codec */
	mc97_codec_reg_write(0x40, 0x1f40);	/* Line 1 rate 8 kHz */
	mc97_codec_reg_write(0x3e, 0xf000);	/* Power up */
	mc97_codec_reg_write(0x46, 0x0000);	/* Mute Off, no gain/attenuation */
	mc97_codec_reg_write(0x4c, 0x002a);	/* GPIO Direction */
	mc97_codec_reg_write(0x4e, 0x002a);	/* GPIO polarity/type */

	/* Init cache */
	g_mc97.rc_46 = 0x0000;
	g_mc97.rc_5c = 0x0000;
	g_mc97.rc_62 = 0x0000;

	/* Country default */
	mc97_select_country(0);
}

void
mc97_debug(void)
{
	printf("CSR  : %08x\n", mc97_regs->csr);
	printf("LLS  : %08x\n", mc97_regs->lls);
	printf("CRA  : %08x\n", mc97_regs->cra);
	printf("GI   : %08x\n", mc97_regs->gpio_in);
	printf("GO   : %08x\n", mc97_regs->gpio_out);
	printf("Fdat : %08x\n", mc97_regs->fifo_data);
	printf("Fcsr : %08x\n", mc97_regs->fifo_csr);
}

bool
mc97_select_country(int cc)
{
	for (int i=0; country_data[i].cc >= 0; i++) {
		/* Match ? */
		if (country_data[i].cc != cc)
			continue;

#if 0
		printf("Configured for %s\n", country_data[i].name);
#endif

		/* Configure */
		g_mc97.rc_5c = (g_mc97.rc_5c & 0xff02) | country_data[i].regs[0];
		g_mc97.rc_62 = (g_mc97.rc_62 & 0xff87) | country_data[i].regs[1];

		mc97_codec_reg_write(0x5c, g_mc97.rc_5c);
		mc97_codec_reg_write(0x62, g_mc97.rc_62);

		/* Done */
		return true;
	}

	return false;
}


void
mc97_set_aux_relay(bool disconnect)
{
	mc97_regs->gpio_out = (mc97_regs->gpio_out & ~(1 << 8)) | (disconnect << 8);
}

void
mc97_set_hook(enum mc97_hook_state s)
{
	uint32_t gpio_out = mc97_regs->gpio_out & ~((1 << 4) | (1 << 6));

	switch (s) {
	case ON_HOOK:                         break;
	case CALLER_ID: gpio_out |= (1 << 6); break;
	case OFF_HOOK:  gpio_out |= (1 << 4); break;
	}

	mc97_regs->gpio_out = gpio_out;
}

bool
mc97_get_ring_detect(void)
{
	return (mc97_regs->gpio_in & (1 << 5)) ? true : false;
}

void
mc97_set_loopback(enum mc97_loopback_mode m)
{
	mc97_codec_reg_write(0x56, m);
}


uint8_t
mc97_get_rx_gain(void)
{
	return (g_mc97.rc_46 & 0xf) * 3;
}

void
mc97_set_rx_gain(uint8_t gain)
{
	gain = (gain > 45) ? 0xf : (gain / 3);
	g_mc97.rc_46 = (g_mc97.rc_46 & 0xff80) | (gain << 8);
	mc97_codec_reg_write(0x46, g_mc97.rc_46);
}

bool
mc97_get_rx_mute(void)
{
	return (g_mc97.rc_46 & 0x0080) ? true : false;
}

void
mc97_set_rx_mute(bool mute)
{
	g_mc97.rc_46 = (g_mc97.rc_46 & 0xff7f) | (mute ? 0x0080 : 0x0000);
	mc97_codec_reg_write(0x46, g_mc97.rc_46);
}

uint8_t
mc97_get_tx_attenuation(void)
{
	return ((g_mc97.rc_46 >> 8) & 0xf) * 3;
}

void
mc97_set_tx_attenuation(uint8_t attenuation)
{
	attenuation = (attenuation > 45) ? 0xf : (attenuation / 3);
	g_mc97.rc_46 = (g_mc97.rc_46 & 0x80ff) | (attenuation << 8);
	mc97_codec_reg_write(0x46, g_mc97.rc_46);
}

bool
mc97_get_tx_mute(void)
{
	return (g_mc97.rc_46 & 0x8000) ? true : false;
}

void
mc97_set_tx_mute(bool mute)
{
	g_mc97.rc_46 = (g_mc97.rc_46 & 0x7fff) | (mute ? 0x8000 : 0x0000);
	mc97_codec_reg_write(0x46, g_mc97.rc_46);
}


void
mc97_flow_rx_reset(void)
{
	mc97_regs->fifo_csr = (mc97_regs->fifo_csr & ~MC97_FIFO_CSR_PCM_IN_ENABLE) | MC97_FIFO_CSR_PCM_IN_FLUSH;
	while (mc97_regs->fifo_csr & MC97_FIFO_CSR_PCM_IN_FLUSH);
}

void
mc97_flow_rx_start(void)
{
	mc97_regs->fifo_csr |= MC97_FIFO_CSR_PCM_IN_ENABLE;
}

void
mc97_flow_rx_stop(void)
{
	mc97_regs->fifo_csr &= ~MC97_FIFO_CSR_PCM_IN_ENABLE;
}

int
mc97_flow_rx_pull(int16_t *data, int n)
{
	for (int i=0; i<n; i++) {
		uint32_t v = mc97_regs->fifo_data;
		if (v & MC97_FIFO_DATA_EMPTY)
			return i;
		data[i] = v & 0xffff;
	}

	return n;
}

int
mc97_flow_rx_level(void)
{
	return MC97_FIFO_CSR_PCM_IN_LEVEL(mc97_regs->fifo_csr);
}

bool
mc97_flow_rx_active(void)
{
	return mc97_regs->fifo_csr & MC97_FIFO_CSR_PCM_IN_ENABLE;
}


void
mc97_flow_tx_reset(void)
{
	mc97_regs->fifo_csr = (mc97_regs->fifo_csr & ~MC97_FIFO_CSR_PCM_OUT_ENABLE) | MC97_FIFO_CSR_PCM_OUT_FLUSH;
	while (mc97_regs->fifo_csr & MC97_FIFO_CSR_PCM_OUT_FLUSH);
}

void
mc97_flow_tx_start(void)
{
	mc97_regs->fifo_csr |= MC97_FIFO_CSR_PCM_OUT_ENABLE;
}

void
mc97_flow_tx_stop(void)
{
	mc97_regs->fifo_csr &= ~MC97_FIFO_CSR_PCM_OUT_ENABLE;
}

int
mc97_flow_tx_push(int16_t *data, int n)
{
	int max = MC97_FIFO_SIZE - MC97_FIFO_CSR_PCM_OUT_LEVEL(mc97_regs->fifo_csr);

	if (n > max)
		n = max;

	for (int i=0; i<n; i++)
		mc97_regs->fifo_data = data[i];

	return n;
}

int
mc97_flow_tx_level(void)
{
	return MC97_FIFO_CSR_PCM_OUT_LEVEL(mc97_regs->fifo_csr);
}

bool
mc97_flow_tx_active(void)
{
	return mc97_regs->fifo_csr & MC97_FIFO_CSR_PCM_OUT_ENABLE;
}
