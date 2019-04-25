/*
 * start.S
 *
 * Startup code taken from picosoc/picorv32 and adapted for use here
 *
 * Copyright (C) 2017 Clifford Wolf <clifford@clifford.at>
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

	.section .text.start
	.global _start
_start:

	// zero-initialize register file
	addi x1, zero, 0
	// x2 (sp) is initialized by reset
	addi x3, zero, 0
	addi x4, zero, 0
	addi x5, zero, 0
	addi x6, zero, 0
	addi x7, zero, 0
	addi x8, zero, 0
	addi x9, zero, 0
	addi x10, zero, 0
	addi x11, zero, 0
	addi x12, zero, 0
	addi x13, zero, 0
	addi x14, zero, 0
	addi x15, zero, 0
	addi x16, zero, 0
	addi x17, zero, 0
	addi x18, zero, 0
	addi x19, zero, 0
	addi x20, zero, 0
	addi x21, zero, 0
	addi x22, zero, 0
	addi x23, zero, 0
	addi x24, zero, 0
	addi x25, zero, 0
	addi x26, zero, 0
	addi x27, zero, 0
	addi x28, zero, 0
	addi x29, zero, 0
	addi x30, zero, 0
	addi x31, zero, 0

#ifdef BOOT_DEBUG
	// Set UART divisor
	li a0, 0x81000000
	li a1, 29
	sw a1, 4(a0)

	// Output '1'
	li a1, 49
	sw a1, 0(a0)
#endif

	// zero initialize entire scratchpad memory
	li a0, 0x0001c000
	li a1, 0
setmemloop:
	sw a1, 0(a0)
	addi a0, a0, 4
	blt a0, sp, setmemloop

#ifdef BOOT_DEBUG
	// Output '2'
	li a0, 0x81000000
	li a1, 50
	sw a1, 0(a0)
#endif

	// copy data section
	la a0, _sidata
	la a1, _sdata
	la a2, _edata
	bge a1, a2, end_init_data
loop_init_data:
	lw a3, 0(a0)
	sw a3, 0(a1)
	addi a0, a0, 4
	addi a1, a1, 4
	blt a1, a2, loop_init_data
end_init_data:

#ifdef BOOT_DEBUG
	// Output '3'
	li a0, 0x81000000
	li a1, 51
	sw a1, 0(a0)
#endif

	// zero-init bss section
	la a0, _sbss
	la a1, _ebss
	bge a0, a1, end_init_bss
loop_init_bss:
	sw zero, 0(a0)
	addi a0, a0, 4
	blt a0, a1, loop_init_bss
end_init_bss:

#ifdef BOOT_DEBUG
	// Output '4'
	li a0, 0x81000000
	li a1, 52
	sw a1, 0(a0)
#endif

	// call main
	call main
loop:
	j loop
