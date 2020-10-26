/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`include "boards.vh"

module sysmgr (
	input  wire clk_in,
	input  wire rst_in,
	output wire clk_24m,
	output wire clk_48m,
	output wire rst_out
);

	// Signals
	wire pll_lock;
	wire pll_reset_n;

	wire clk_24m_i;
	wire clk_48m_i;
	wire rst_i;
	reg [3:0] rst_cnt;

	// PLL instance
`ifdef PLL_CORE
	SB_PLL40_2F_CORE #(
`else
	SB_PLL40_2F_PAD #(
`endif
		.DIVR(`PLL_DIVR),
		.DIVF(`PLL_DIVF),
		.DIVQ(`PLL_DIVQ),
		.FILTER_RANGE(`PLL_FILTER_RANGE),
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.FDA_FEEDBACK(4'b0000),
		.SHIFTREG_DIV_MODE(2'b00),
		.PLLOUT_SELECT_PORTA("GENCLK"),
		.PLLOUT_SELECT_PORTB("GENCLK_HALF"),
		.ENABLE_ICEGATE_PORTA(1'b0),
		.ENABLE_ICEGATE_PORTB(1'b0)
	) pll_I (
`ifdef PLL_CORE
		.REFERENCECLK(clk_in),
`else
		.PACKAGEPIN(clk_in),
`endif
		.PLLOUTCOREA(),
		.PLLOUTGLOBALA(clk_48m_i),
		.PLLOUTCOREB(),
		.PLLOUTGLOBALB(clk_24m_i),
		.EXTFEEDBACK(1'b0),
		.DYNAMICDELAY(8'h00),
		.RESETB(pll_reset_n),
		.BYPASS(1'b0),
		.LATCHINPUTVALUE(1'b0),
		.LOCK(pll_lock),
		.SDI(1'b0),
		.SDO(),
		.SCLK(1'b0)
	);

	assign clk_24m = clk_24m_i;
	assign clk_48m = clk_48m_i;

	// PLL reset generation
	assign pll_reset_n = ~rst_in;

	// Logic reset generation
	always @(posedge clk_24m_i or negedge pll_lock)
		if (!pll_lock)
			rst_cnt <= 4'h0;
		else if (~rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst_i = ~rst_cnt[3];

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_i),
		.GLOBAL_BUFFER_OUTPUT(rst_out)
	);

endmodule // sysmgr
