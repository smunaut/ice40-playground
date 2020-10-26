/*
 * boards.vh
 *
 * vim: ts=4 sw=4 syntax=verilog
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`ifdef BOARD_BITSY_V0
	// 1bitsquared iCEbreaker bitsy prototypes (v0.x)
	`define HAS_PSRAM
`elsif BOARD_BITSY_V1
	// 1bitsquared iCEbreaker bitsy prod (v1.x)
	`define HAS_PSRAM
`elsif BOARD_ICEBREAKER
	// 1bitsquared iCEbreaker
	`define HAS_PSRAM
`elsif BOARD_FOMU_HACKER
	// FOMU clock is 48M
	`define PLL_CORE
	`define PLL_CUSTOM
	`define PLL_DIVR 4'b0000
	`define PLL_DIVF 7'b0001111
	`define PLL_DIVQ 3'b100
	`define PLL_FILTER_RANGE 3'b100
`endif


// Defaults
	// PLL params 12M input, 48M output
`ifndef PLL_CUSTOM
	`define PLL_DIVR 4'b0000
	`define PLL_DIVF 7'b0111111
	`define PLL_DIVQ 3'b100
	`define PLL_FILTER_RANGE 3'b001
`endif
