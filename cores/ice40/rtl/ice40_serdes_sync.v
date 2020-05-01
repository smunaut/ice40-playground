/*
 * ice40_serdes_sync.v
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

module ice40_serdes_sync #(
	parameter integer PHASE = 0,
	parameter integer NEG_EDGE = 0,
	parameter integer GLOBAL_BUF = 0,
	parameter integer LOCAL_BUF = 0,
	parameter BEL_COL = "X12",
	parameter BEL_ROW = "Y15",		// Ignored if using LOCAL_BUF, Y15 used in that case
	parameter BEL_GB  = ""
)(
	input  wire clk_slow,
	input  wire clk_fast,
	input  wire rst,
	output wire sync
);
	localparam BEL_BASE  = LOCAL_BUF ? { BEL_COL, "/Y15" } : { BEL_COL, "/", BEL_ROW };
	localparam PHASE_CMP = LOCAL_BUF ? ((PHASE + 3) % 4) : PHASE;

	wire [1:0] clk_samp;
	wire [1:0] edge_det;
	wire [1:0] edge_found;
	wire [1:0] cnt_next;
	wire [1:0] cnt_val;

	wire [1:0] sync_next;
	wire [1:0] sync_i;

	// Double sample of the slow clock
	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc7"})
	) ff_samp0_I (
		.d(clk_slow),
		.q(clk_samp[0]),
		.c(clk_fast),
		.r(rst)
	);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc6"})
	) ff_samp1_I (
		.d(clk_samp[0]),
		.q(clk_samp[1]),
		.c(clk_fast),
		.r(rst)
	);

	// Detect falling edge, then rising edge
	assign edge_det[0] = edge_found[0] | (clk_samp[1] & ~clk_samp[0]);
	assign edge_det[1] = edge_found[1] | (clk_samp[0] & ~clk_samp[1] & edge_found[0]);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc5"})
	) ff_edge0_I (
		.d(edge_det[0]),
		.q(edge_found[0]),
		.c(clk_fast),
		.r(rst)
	);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc4"})
	) ff_edge1_I (
		.d(edge_det[1]),
		.q(edge_found[1]),
		.c(clk_fast),
		.r(rst)
	);

	// 2 bit upcounter
	assign cnt_next[0] = cnt_val[0] ^ edge_found[1];
	assign cnt_next[1] = cnt_val[1] ^ (cnt_val[0] & edge_found[1]);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc2"})
	) ff_cnt1_I (
		.d(cnt_next[1]),
		.q(cnt_val[1]),
		.c(clk_fast),
		.r(rst)
	);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc1"})
	) ff_cnt0_I (
		.d(cnt_next[0]),
		.q(cnt_val[0]),
		.c(clk_fast),
		.r(rst)
	);

	// Final comparator
	SB_LUT4 #(
		.LUT_INIT(1 << ((4*PHASE_CMP)+2))
	) lut_sync_I[1:0] (
		.I0(1'b0),
		.I1(edge_found[1]),
		.I2(cnt_val[0]),
		.I3(cnt_val[1]),
		.O(sync_next)
	);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc3"})
	) ff_sync1_I (
		.d(sync_next[1]),
		.q(sync_i[1]),
		.c(clk_fast),
		.r(rst)
	);

	ice40_serdes_dff #(
		.NEG(NEG_EDGE),
		.RST(1),
		.BEL({BEL_BASE, "/lc0"})
	) ff_sync0_I (
		.d(sync_next[0]),
		.q(sync_i[0]),
		.c(clk_fast),
		.r(rst)
	);

	// Buffer ?
	generate
		if (GLOBAL_BUF)
			(* BEL=BEL_GB *)
			SB_GB gbuf_sync_I (
				.USER_SIGNAL_TO_GLOBAL_BUFFER(sync_i[0]),
				.GLOBAL_BUFFER_OUTPUT(sync)
			);
		else
			assign sync = sync_i[0];

		if (LOCAL_BUF) begin
			ice40_serdes_dff #(
				.NEG(NEG_EDGE),
				.BEL({BEL_COL, "/Y4/lc1"}),
				.SERDES_ATTR("sync_lbuf_bot")
			) sync_bot (
				.d(sync_i[0]),
				.q(), // Output will be wired by the script
				.c(clk_fast)
			);

			ice40_serdes_dff #(
				.NEG(NEG_EDGE),
				.BEL({BEL_COL, "/Y26/lc1"}),
				.SERDES_ATTR("sync_lbuf_top")
			) sync_top (
				.d(sync_i[1]),
				.q(),
				.c(clk_fast)
			);
		end
	endgenerate

endmodule
