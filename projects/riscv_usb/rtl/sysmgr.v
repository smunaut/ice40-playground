/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`default_nettype none

module sysmgr (
	input  wire [3:0] delay,
	input  wire clk_in,
	output wire clk_24m,
	output wire clk_48m,
	output wire clk_96m,
	output wire clk_rd,
	output wire sync_96m,
	output wire sync_rd,
	output wire rst
);

	wire       pll_lock;

	SB_PLL40_2F_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),
		.DIVF(7'b0111111),
		.DIVQ(3'b011),
		.FILTER_RANGE(3'b001),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("DYNAMIC"),
		.FDA_RELATIVE(15),
		.SHIFTREG_DIV_MODE(0),
		.PLLOUT_SELECT_PORTA("GENCLK"),
		.PLLOUT_SELECT_PORTB("GENCLK")
	) pll_I (
		.PACKAGEPIN(clk_in),
		.DYNAMICDELAY({delay, 4'h0}),
		.PLLOUTGLOBALA(clk_rd),
		.PLLOUTGLOBALB(clk_96m),
		.RESETB(1'b1),
		.LOCK(pll_lock)
	);

	ice40_serdes_crg #(
		.NO_CLOCK_2X(0)
	) crg_I (
		.clk_4x(clk_96m),
		.pll_lock(pll_lock),
		.clk_1x(clk_24m),
		.clk_2x(clk_48m),
		.rst(rst)
	);

	ice40_serdes_sync #(
		.PHASE(2),
		.NEG_EDGE(0),
		.GLOBAL_BUF(1),
		.BEL_GB("X12/Y31/gb"),
		.BEL_COL("X12"),
		.BEL_ROW("Y26")
	) sync_96m_I (
		.clk_slow(clk_24m),
		.clk_fast(clk_96m),
		.rst(rst),
		.sync(sync_96m)
	);

	ice40_serdes_sync #(
		.PHASE(2),
		.NEG_EDGE(0),
		.GLOBAL_BUF(1),
		.BEL_GB("X13/Y31/gb"),
		.BEL_COL("X13"),
		.BEL_ROW("Y26")
	) sync_rd_I (
		.clk_slow(clk_24m),
		.clk_fast(clk_rd),
		.rst(rst),
		.sync(sync_rd)
	);

endmodule
