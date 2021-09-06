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
	output wire clk_1x,
	output wire clk_2x,
	output wire clk_4x,
	output wire clk_rd,
	output wire sync_4x,
	output wire sync_rd,
	output wire rst
);

	wire       pll_lock;

	SB_PLL40_2F_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),

	// 48
//		.DIVF(7'b0111111),
//		.DIVQ(3'b100),

	// 96
//		.DIVF(7'b0111111),
//		.DIVQ(3'b011),

	// 144
//		.DIVF(7'b0101111),
//		.DIVQ(3'b010),

	// 147
		.DIVF(7'b0110000),
		.DIVQ(3'b010),

	// 200
//		.DIVF(7'b1000010),
//		.DIVQ(3'b010),

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
		.PLLOUTGLOBALB(clk_4x),
		.RESETB(1'b1),
		.LOCK(pll_lock)
	);

	ice40_serdes_crg #(
		.NO_CLOCK_2X(0)
	) crg_I (
		.clk_4x(clk_4x),
		.pll_lock(pll_lock),
		.clk_1x(clk_1x),
		.clk_2x(clk_2x),
		.rst(rst)
	);

`ifdef MEM_spi
	ice40_serdes_sync #(
		.PHASE(2),
		.NEG_EDGE(0),
`ifdef VIDEO_none
		.GLOBAL_BUF(0),
		.LOCAL_BUF(0),
		.BEL_COL("X22"),
		.BEL_ROW("Y4"),
`else
		.GLOBAL_BUF(0),
		.LOCAL_BUF(1),
		.BEL_COL("X15")
`endif
	) sync_4x_I (
		.clk_slow(clk_1x),
		.clk_fast(clk_4x),
		.rst(rst),
		.sync(sync_4x)
	);

	assign sync_rd = 1'b0;
`endif

`ifdef MEM_hyperram
	ice40_serdes_sync #(
		.PHASE(2),
		.NEG_EDGE(0),
		.GLOBAL_BUF(0),
		.LOCAL_BUF(1),
		.BEL_COL("X12"),
		.BEL_ROW("Y15")
	) sync_4x_I (
		.clk_slow(clk_1x),
		.clk_fast(clk_4x),
		.rst(rst),
		.sync(sync_4x)
	);

	ice40_serdes_sync #(
		.PHASE(2),
		.NEG_EDGE(0),
		.GLOBAL_BUF(0),
		.LOCAL_BUF(1),
		.BEL_COL("X13"),
		.BEL_ROW("Y15")
	) sync_rd_I (
		.clk_slow(clk_1x),
		.clk_fast(clk_rd),
		.rst(rst),
		.sync(sync_rd)
	);
`endif

endmodule // sysmgr
