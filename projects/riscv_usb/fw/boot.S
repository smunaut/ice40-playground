/*
 * boot.S
 *
 * SPI boot code
 *
 * Copyright (C) 2019 Sylvain Munaut <tnt@246tNt.com>
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

#ifndef FLASH_APP_ADDR
#define FLASH_APP_ADDR 0x00100000
#endif

#define BOOT_DEBUG

	.section .text.start
	.global _start
_start:

#ifdef BOOT_DEBUG
	// Set UART divisor
	li	a0, 0x82000004
	li	a1, 22
	sw	a1, 0(a0)
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

	li	ra, 0x400a0000
	lw	a0, 0(ra)
	call	print_hex

	// Jump to main code
	li	ra, 0x400a0000
	ret

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


#ifdef BOOT_DEBUG
	// Flash QSPI config
	// -----------------

	// Request external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)

	li	t0, 0x00000002
	sw	t0, SPI_CSR(t5)

	// Read command
	li	t0, 0x0b0a0000
	sw	t0, 0x7c(t5)

	// 6 dummy clk
	li	t0, 0x00000000
	sw	t0, 0x58(t5)
	lw	t0, SPI_RF(t5)

	// Read one word
	li	t0, 0x00000000
	sw	t0, 0x5c(t5)

	// Display read word
	lw	a0, SPI_RF(t5)
	call	print_hex

	// Read one word
	li	t0, 0x00000000
	sw	t0, 0x5c(t5)

	// Display read word
	lw	a0, SPI_RF(t5)
	call	print_hex

	// Release external control
	li	t0, 0x00000004
	sw	t0, SPI_CSR(t5)
#endif


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


// Agument in a0
// Clobbers a0, t0-t3
print_hex:
	li	t0, 0x82000000
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
	li	t0, 0x82000000
	li	a0, '\r'
	sw	a0, 0(t0)
	li	a0, '\n'
	sw	a0, 0(t0)

	ret

hexchar:
	.ascii	"0123456789abcdef"
