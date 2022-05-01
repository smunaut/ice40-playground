/*
 * boot.S
 *
 * SPI boot code
 *
 * Copyright (C) 2019-2022 Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: MIT
 */

// #define BOOT_DEBUG

#ifndef FLASH_APP_ADDR
#define FLASH_APP_ADDR 0x00100000
#endif

	.equ    UART_BASE, 0x81000000

	.section .text.start
	.global _start
_start:

#ifdef BOOT_DEBUG
	// Set UART divisor
	li	a0, UART_BASE
	li	a1, 22
	sw	a1, 4(a0)

	// Output 'a'
	li	a1, 97
	sw	a1, 0(a0)
#endif

	// SPI init
	jal	spi_init

#ifdef BOOT_DEBUG
	// Output 'b'
	li	a0, UART_BASE
	li	a1, 98
	sw	a1, 0(a0)
#endif

	li	a0, 0x00020000
#ifdef SPRAM128K
	li	a1, 0x00020000
#else
	li	a1, 0x00010000
#endif
	li	a2, FLASH_APP_ADDR
	jal	spi_flash_read

#ifdef BOOT_DEBUG
	// Output 'c'
	li	a0, UART_BASE
	li	a1, 99
	sw	a1, 0(a0)
#endif

	// Setup reboot code
	li	t0, 0x0002006f
	sw	t0, 0(zero)

	// Jump to main code
	j	0x00020000


// ---------------------------------------------------------------------------
// SPI code
// ---------------------------------------------------------------------------

// Register definitions

	.equ    SPI_BASE, 0x82000000
	.equ    SPICR0,  4 * 0x08
	.equ    SPICR1,  4 * 0x09
	.equ    SPICR2,  4 * 0x0a
	.equ    SPIBR,   4 * 0x0b
	.equ    SPISR,   4 * 0x0c
	.equ    SPITXDR, 4 * 0x0d
	.equ    SPIRXDR, 4 * 0x0e
	.equ    SPICSR,  4 * 0x0f

// Initializes te SPI hardware
//
// Clobbers a0, a1
spi_init:
	li	a0, SPI_BASE

	li	a1, 0xff
	sw	a1, SPICR0(a0)

	li	a1, 0x80
	sw	a1, SPICR1(a0)

	li	a1, 0xc0
	sw	a1, SPICR2(a0)

	li	a1, 0x03
	sw	a1, SPIBR(a0)

	li	a1, 0x0f
	sw	a1, SPICSR(a0)

	ret

// Reads a block of memory from SPI flash
//
// Params:
//  a0 - destination pointer
//  a1 - length (bytes)
//  a2 - flash offset
// Clobbers t0, t1, s0, s1, s2

spi_flash_read:
	// Save params
	mv	s0, a0
	mv	s1, a1
	mv	s2, ra

	// Setup CS
	li	t0, SPI_BASE
	li	t1, 0x0e
	sw	t1, SPICSR(t0)

	// Send command
	li	a0, 0x03
	jal	_spi_do_one

	srli	a0, a2, 16
	and	a0, a0, 0xff
	jal	_spi_do_one

	srli	a0, a2, 8
	and	a0, a0, 0xff
	jal	_spi_do_one

	and	a0, a2, 0xff
	jal	_spi_do_one

	// Read loop
_spi_loop:
	li	a0, 0x00
	jal	_spi_do_one
	sb	a0, 0(s0)
	addi	s0, s0,  1
	addi	s1, s1, -1
	bne	s1, zero, _spi_loop

	// Release CS
	li	t0, SPI_BASE
	li	t1, 0x0f
	sw	t1, SPICSR(t0)

	// Done
	jr	s2


// Performs a single 8 bit SPI xfer
//
// Params:  a0 - Data to TX
// Returns: a0 - RX data
// Clobbers t0, t1

_spi_do_one:
	li	t0, SPI_BASE
	li	t1, 0x08

	// Write TX data
	sw	a0, SPITXDR(t0)

	// Wait for RXRDY
1:
	lw	a0, SPISR(t0)
	and	a0, a0, t1
	bne	a0, t1, 1b

	// Read RX data
	lw	a0, SPIRXDR(t0)

	// Done
	ret
