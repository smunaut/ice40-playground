/*
 * boot.S
 *
 * Boot code
 *
 * Copyright (C) 2020-2022 Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: MIT
 */

// #define BOOT_DEBUG

#ifndef FLASH_APP_ADDR
#define FLASH_APP_ADDR 0x00100000
#endif

	.equ    UART_BASE, 0x82000000

	.section .text.start
	.global _start
_start:

#ifdef BOOT_DEBUG
	// Set UART divisor
	li	a0, UART_BASE
	li	a1, 23
	sw	a1, 4(a0)
#endif

	// Delay boot
	li	t0, 0x01000000
1:
	addi	t0, t0, -1
	bne	t0, zero, 1b

	// SPI init
	jal	spi_init

	// Setup reboot code
	li	t0, 0x0002006f
	sw	t0, 0(zero)

	// Jump to main code in flash
	li	ra, (0x40000000 + FLASH_APP_ADDR)
	ret


// ---------------------------------------------------------------------------
// SPI code
// ---------------------------------------------------------------------------

	.equ    SPI_BASE, 0x80000000
	.equ    SPI_CSR,  4 * 0x00
	.equ	SPI_RF,   4 * 0x03

spi_init:

	// Save return address
	// -------------------

	mv	t6, ra


	// Flash QSPI enable
	// -----------------

	li	t5, SPI_BASE

	// Request external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)

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
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)

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
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)

	li	t0, 0x00000012
	sw	t0, SPI_CSR(t5)

	// Enable QSPI (0x35)
	li	t0, 0x35000000
	sw	t0, 0x40(t5)

	// Read and discard response
	lw	t0, SPI_RF(t5)

	// Release external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)


	// Return
	// ------

	mv	ra, t6
	ret


// ---------------------------------------------------------------------------
// Debug helpers
// ---------------------------------------------------------------------------

#ifdef BOOT_DEBUG
// Agument in a0
// Clobbers a0, t0-t3
print_hex:
	li	t0, UART_BASE
	li	t1, 8
	la	t2, hexchar

1:
	srli	t3, a0, 28
	add	t3, t3, t2
	lb	t3, 0(t3)
	sw	t3, 0(t0)

	slli	a0, a0, 4

	addi	t1, t1, -1
	bne	zero, t1, 1b

print_nl:
	li	t0, UART_BASE
	li	a0, '\r'
	sw	a0, 0(t0)
	li	a0, '\n'
	sw	a0, 0(t0)

	ret

hexchar:
	.ascii	"0123456789abcdef"
#endif
