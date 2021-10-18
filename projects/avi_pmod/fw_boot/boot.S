/*
 * boot.S
 *
 * Boot code
 *
 * Copyright (C) 2020 Sylvain Munaut <tnt@246tNt.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

	.section .text.start
	.global _start
_start:


#ifdef ICEBREAKER
	// Delay boot
	// (to make sure the SPI lines are clear FTDI)
	li	t0, 0x01000000
1:
	addi	t0, t0, -1
	bne	t0, zero, 1b
#endif

	.equ	LED_BASE, 0x87000000

#define LEDDPWRR (64 +  1*4)      // 0001 LEDDPWRR - Pulse Width Register Red
#define LEDDPWRG (64 +  2*4)      // 0010 LEDDPWRG - Pulse Width Register Green
#define LEDDPWRB (64 +  3*4)      // 0011 LEDDPWRB - Pulse Width Register Blue
#define LEDDBCRR (64 +  5*4)      // 0101 LEDDBCRR - Breathe Control Rise Register
#define LEDDBCFR (64 +  6*4)      // 0110 LEDDBCFR - Breathe Control Fall Register
#define LEDDCR0  (64 +  8*4)      // 1000 LEDDCR0  - Control Register 0
#define LEDDBR   (64 +  9*4)      // 1001 LEDDBR   - Pre-scale Register
#define LEDONR   (64 + 10*4)      // 1010 LEDONR   - ON  Time Register
#define LEDOFR   (64 + 11*4)      // 1011 LEDOFR   - OFF Time Register

	// LED init
	li	t0, LED_BASE
	sw	zero, 0(t0)
	sw	zero, LEDDPWRR(t0)
	sw	zero, LEDDPWRG(t0)
	sw	zero, LEDDPWRB(t0)
	sw	zero, LEDDBCRR(t0)
	sw	zero, LEDDBCFR(t0)
	sw	zero, LEDONR(t0)
	sw	zero, LEDOFR(t0)

	li	t1, 0xe0
	sw	t1, LEDDBR(t0)

	li	t1, 0xdd
	sw	t1, LEDDCR0(t0)

	li	t1, 0xe
	sw	t1, 0(t0)

	// ---
	li	t0, LED_BASE
	li	t1, 128
	sw	t1, LEDDPWRR(t0)
	// --


	// SPI init
	jal	spi_init

	// Load 64k from flash to SPRAM
	li	a0, 0x00020000
	li	a1, 0x000a0000
	li	a2, 64*1024
	jal	spi_load

	// Disable flash QPI
	jal	spi_flash_reset

	// Jump to main code in SPRAM
	li	ra, 0x00020000
	ret


// ---------------------------------------------------------------------------
// SPI
// ---------------------------------------------------------------------------

	.equ    SPI_BASE, 0x82000000
	.equ    SPI_CSR,  4 * 0x00
	.equ	SPI_RF,   4 * 0x03


spi_init:

	li	t5, SPI_BASE

	// Flash QSPI enable
	// -----------------

	// Request external control
	li	t0, 0x00000002
	sw	t0, SPI_CSR(t5)

	// Enable QSPI (0x38)
	li	t0, 0x38000000
	sw	t0, 0x40(t5)

	// Read and discard response
	lw	t0, SPI_RF(t5)

	// Release external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)


	// Flash QSPI config
	// -----------------

	// Request external control
	li	t0, 0x00000002
	sw	t0, SPI_CSR(t5)

	// Set QSPI parameters (dummy=6, wrap=64b)
	li	t0, 0xc0230000
	sw	t0, 0x74(t5)

	// Release external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)


	// PSRAM init
	// ----------

	// Request external control
	li	t0, 0x00000012
	sw	t0, SPI_CSR(t5)

	// Enable QSPI (0x35)
	li	t0, 0x35000000
	sw	t0, 0x40(t5)

	// Read and discard response
	lw	t0, SPI_RF(t5)

	// Common tail
	j	_spi_done



//
// a0	Destination address in memory
// a1	Source address in flash
// a2	Length
//
// 35:34 0 - SPI
//       1 - QPI_RD
//       2 - QPI_WR
//       3 - QPI_CMD
// 33:32 len

#define _SPI		0
#define _QPI_RD		1
#define _QPI_WR		2
#define _QPI_CMD	3

#define SPI_CMD(c,l) (0x40 | ((c) << 4) | (((l)-1) << 2))

spi_load:
	// Prepare accesses
	li	t5, SPI_BASE

	// Request external control
	li	t0, 0x00000002
	sw	t0, SPI_CSR(t5)

	// Issue QPI read command
	li	t0, 0x0b000000
	or	t0, t0, a1
	sw	t0, SPI_CMD(_QPI_CMD, 4)(t5)

	// Skip dummy cycles
	sw	zero, SPI_CMD(_QPI_RD, 3)(t5)
	lw	zero, SPI_RF(t5)

	// Read loop
1:
		// Read a word
	sw	zero, SPI_CMD(_QPI_RD, 4)(t5)
	lw	t0, SPI_RF(t5)

		// Endian swap
	slli	t1, t0, 24
	srli	t2, t0, 24
	or	t1, t1, t2
	li	t3, 0xff0000
	and	t2, t0, t3
	srli	t2, t2, 8
	or	t1, t1, t2
	slli	t2, t0, 8
	and	t2, t2, t3
	or	t1, t1, t2

		// Store it
	sw	t1, 0(a0)
	addi	a0, a0, 4

		// Done ?
	addi	a2, a2, -4
	blt	zero, a2, 1b

	// Common tail
	j	_spi_done


spi_flash_reset:
	// Prepare accesses
	li	t5, SPI_BASE

	// Request external control
	li	t0, 0x00000002
	sw	t0, SPI_CSR(t5)

	// Issue QPI disable
	li	t0, 0xff000000
	sw	t0, SPI_CMD(_QPI_CMD, 1)(t5)


_spi_done:
	// Release external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)

	// Wait for release
1:
	lw	t0, SPI_CSR(t5)
	andi	t0, t0, 4
	bne	t0, zero, 1b

	// Return
	ret
