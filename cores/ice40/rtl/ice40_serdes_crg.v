/*
 * ice40_serdes_crg.v
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

module ice40_serdes_crg #(
	parameter integer NO_CLOCK_2X = 0
)(
	// Input from PLL
	input  wire clk_4x,
	input  wire pll_lock,

	// Outputs
	output wire clk_1x,
	output wire clk_2x,
	output wire rst
);

	// Signals
	// -------

	// Reset
	reg  [3:0] rst_cnt_nxt[0:15];
	reg  [3:0] rst_cnt = 4'h8;
	reg        rst_i;

	// Clock Divider
	reg  [1:0] clk_div;
	wire       clk_sync_i;


	// Reset
	// -----

	// Counter
	initial begin : rst_init
		integer i;
		for (i=0; i<16; i=i+1)
			rst_cnt_nxt[i] = i==15 ? i : (i+1);
	end

	always @(posedge clk_4x or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h0;
		else
			rst_cnt <= rst_cnt_nxt[rst_cnt];

	// Final FF
	always @(posedge clk_4x or negedge pll_lock)
		if (~pll_lock)
			rst_i <= 1'b1;
		else
			rst_i <= (rst_cnt != 4'hf);

	// Buffer reset
	SB_GB gbuf_rst_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_i),
		.GLOBAL_BUFFER_OUTPUT(rst)
	);


	// Clock Divider & Sync
	// --------------------

	// Simple counter to generate the edges
	always @(posedge clk_4x or negedge pll_lock)
		if (~pll_lock)
			clk_div <= 2'b00;
		else
			clk_div <= clk_div + rst_cnt[3];

	// Buffer clk_2x
	generate
		if (NO_CLOCK_2X)
			assign clk_2x = 1'b0;
		else
			(* BEL="X13/Y0/gb" *)
			SB_GB gbuf_2x_I (
				.USER_SIGNAL_TO_GLOBAL_BUFFER(clk_div[0]),
				.GLOBAL_BUFFER_OUTPUT(clk_2x)
			);
	endgenerate

	// Buffer clk_1x
	(* BEL="X12/Y0/gb" *)
	SB_GB gbuf_1x_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(clk_div[1]),
		.GLOBAL_BUFFER_OUTPUT(clk_1x)
	);

endmodule
