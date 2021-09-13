/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module sysmgr (
	input  wire clk_in,
	output wire clk_1x,
	output wire clk_4x,
	output wire sync_4x,
	output wire rst_sys,
	output wire clk_usb,
	output wire rst_usb
);

	// Signals
	// -------

	wire      pll_lock;

	wire      clk_usb_i;
	wire      rst_usb_i;
	reg [3:0] rst_usb_cnt;


	// PLL 12M -> 48M / 120M
	// ---

	SB_PLL40_2F_PAD #(
		.FEEDBACK_PATH      ("SIMPLE"),
		.DIVR               (4'b0000),
		.DIVF               (7'b1001111),
		.DIVQ               (3'b010),
		.FILTER_RANGE       (3'b001),
		.SHIFTREG_DIV_MODE  (2'b11),
		.PLLOUT_SELECT_PORTA("GENCLK_HALF"),
		.PLLOUT_SELECT_PORTB("SHIFTREG_0deg")
	) pll_I (
		.PACKAGEPIN    (clk_in),
		.PLLOUTGLOBALA (clk_4x),
		.PLLOUTCOREB   (clk_usb_i),
		.RESETB        (1'b1),
		.LOCK          (pll_lock)
	);

	// We use PLLOUTCORE and then a SB_GB so that it doesn't
	// use global network 2 (which we need for a reset line)
	SB_GB clk_usb_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (clk_usb_i),
		.GLOBAL_BUFFER_OUTPUT         (clk_usb)
	);


	// Fabric derived clocks
	// ---------------------

	ice40_serdes_crg #(
		.NO_CLOCK_2X(1)
	) subcrg_I (
		.clk_4x   (clk_4x),
		.pll_lock (pll_lock),
		.clk_1x   (clk_1x),
		.rst      (rst_sys)
	);


	// Sync for SERDES
	// ---------------

	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (0),
		.BEL_COL    ("X21"),
		.BEL_ROW    ("Y4")
	) sync_4x_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_4x),
		.rst      (rst_sys),
		.sync     (sync_4x)
	);


	// USB Reset
	// ---------

	always @(posedge clk_usb or negedge pll_lock)
		if (~pll_lock)
			rst_usb_cnt <= 4'h8;
		else if (rst_usb_i)
			rst_usb_cnt <= rst_usb_cnt + 1;

	assign rst_usb_i = rst_usb_cnt[3];

	SB_GB rst_usb_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_usb_i),
		.GLOBAL_BUFFER_OUTPUT         (rst_usb)
	);

endmodule // sysmgr
