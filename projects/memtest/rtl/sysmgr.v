/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`include "boards.vh"

module sysmgr (
	// Memory clocks
	input  wire [3:0] delay,
	input  wire       clk_in,
	output wire       clk_1x,
	output wire       clk_2x,
	output wire       clk_4x,
	output wire       clk_rd,
	output wire       sync_4x,
	output wire       sync_rd,
	output wire       rst,

	// USB
	output wire       clk_usb,
	output wire       rst_usb
);

	// Memory clocks / reset
	// ---------------------

	// Signals
	wire       pll_lock;

	// PLL
`ifdef PLL_CORE
	SB_PLL40_2F_CORE #(
`else
	SB_PLL40_2F_PAD #(
`endif
		.FEEDBACK_PATH                  ("SIMPLE"),
		.FILTER_RANGE                   (`PLL_FILTER_RANGE),
		.DIVR                           (`PLL_DIVR),
		.DIVF                           (`PLL_DIVF),
		.DIVQ                           (`PLL_DIVQ),
		.DELAY_ADJUSTMENT_MODE_RELATIVE ("DYNAMIC"),
		.FDA_RELATIVE                   (15),
		.SHIFTREG_DIV_MODE              (0),
		.PLLOUT_SELECT_PORTA            ("GENCLK"),
		.PLLOUT_SELECT_PORTB            ("GENCLK")
	) pll_I (
`ifdef PLL_CORE
		.REFERENCECLK  (clk_in),
`else
		.PACKAGEPIN    (clk_in),
`endif
		.DYNAMICDELAY  ({delay, 4'h0}),
		.PLLOUTGLOBALA (clk_rd),
		.PLLOUTGLOBALB (clk_4x),
		.RESETB        (1'b1),
		.LOCK          (pll_lock)
	);

	// Fabric derived clocks
	ice40_serdes_crg #(
		.NO_CLOCK_2X(0)
	) crg_I (
		.clk_4x   (clk_4x),
		.pll_lock (pll_lock),
		.clk_1x   (clk_1x),
		.clk_2x   (clk_2x),
		.rst      (rst)
	);

	// SPI - Sync signals
`ifdef MEM_spi
	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
`ifdef VIDEO_none
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (0),
		.BEL_COL    ("X21"),
		.BEL_ROW    ("Y4"),
`else
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (1),
		.BEL_COL    ("X15")
`endif
	) sync_4x_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_4x),
		.rst      (rst),
		.sync     (sync_4x)
	);

	assign sync_rd = 1'b0;
`endif

	// HyperRAM - Sync signals
`ifdef MEM_hyperram
	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (1),
		.BEL_COL    ("X12"),
		.BEL_ROW    ("Y15")
	) sync_4x_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_4x),
		.rst      (rst),
		.sync     (sync_4x)
	);

	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (1),
		.BEL_COL    ("X13"),
		.BEL_ROW    ("Y15")
	) sync_rd_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_rd),
		.rst      (rst),
		.sync     (sync_rd)
	);
`endif


	// USB clock / reset
	// -----------------

	// Signals
	wire      rst_usb_i;
	reg [3:0] rst_usb_cnt;

	// 48 MHz source
	SB_HFOSC #(
		.TRIM_EN   ("0b0"),
		.CLKHF_DIV ("0b00")	// 48 MHz
	) osc_I (
		.CLKHFPU (1'b1),
		.CLKHFEN (1'b1),
		.CLKHF   (clk_usb)
	);

	// Logic reset generation
	always @(posedge clk_usb or negedge pll_lock)
		if (~pll_lock)
			rst_usb_cnt <= 4'h8;
		else if (rst_usb_i)
			rst_usb_cnt <= rst_usb_cnt + 1;

	assign rst_usb_i = rst_usb_cnt[3];

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_usb_i),
		.GLOBAL_BUFFER_OUTPUT         (rst_usb)
	);

endmodule // sysmgr
