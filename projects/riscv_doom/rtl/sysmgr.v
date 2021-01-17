/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module sysmgr (
	input  wire clk_in,
	output wire clk_1x,
	output wire clk_4x,
	output wire sync_4x,
	output wire rst
);

	wire pll_lock;

	SB_PLL40_2F_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),
		.DIVF(7'b1000010),
		.DIVQ(3'b011),
		.FILTER_RANGE(3'b001),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("DYNAMIC"),
		.FDA_RELATIVE(15),
		.SHIFTREG_DIV_MODE(0),
		.PLLOUT_SELECT_PORTA("GENCLK"),
		.PLLOUT_SELECT_PORTB("GENCLK")
	) pll_I (
		.PACKAGEPIN    (clk_in),
		.DYNAMICDELAY  (8'h0),
		.PLLOUTGLOBALA (),
		.PLLOUTGLOBALB (clk_4x),
		.RESETB        (1'b1),
		.LOCK          (pll_lock)
	);

	ice40_serdes_crg #(
		.NO_CLOCK_2X(1)
	) crg_I (
		.clk_4x   (clk_4x),
		.pll_lock (pll_lock),
		.clk_1x   (clk_1x),
		.clk_2x   (),
		.rst      (rst)
	);

	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
		.GLOBAL_BUF (0),
		.BEL_COL    ("X20"),
		.BEL_ROW    ("Y4")
	) sync_96m_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_4x),
		.rst      (rst),
		.sync     (sync_4x)
	);

endmodule
