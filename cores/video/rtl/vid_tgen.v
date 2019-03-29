/*
 * vid_tgen.v
 *
 * vim: ts=4 sw=4
 *
 * Video Timing Generator
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
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
`define FORCE_REG		// Yosys fuckery workaround :/

module vid_tgen #(
	parameter integer H_WIDTH  = 12,
	parameter integer H_FP     =   88 / 2,
	parameter integer H_SYNC   =   44 / 2,
	parameter integer H_BP     =  148 / 2,
	parameter integer H_ACTIVE = 1920 / 2,
	parameter integer V_WIDTH  = 12,
	parameter integer V_FP     =    4,
	parameter integer V_SYNC   =    5,
	parameter integer V_BP     =   36,
	parameter integer V_ACTIVE = 1080
)(
	output reg  vid_hsync,
	output reg  vid_vsync,
	output reg  vid_active,
	output reg  vid_h_first,
	output reg  vid_h_last,
	output reg  vid_v_first,
	output reg  vid_v_last,

	input  wire clk,
	input  wire rst
);

	localparam Z_FP     = 0;
	localparam Z_SYNC   = 1;
	localparam Z_BP     = 2;
	localparam Z_ACTIVE = 3;

	// Signals
	reg  [1:0] h_zone;
	wire [H_WIDTH:0] h_dec;
	reg  [H_WIDTH:0] h_mux;
	reg  [H_WIDTH:0] h_cnt;
	reg  h_first;
	wire h_last;

	reg  [1:0] v_zone;
	wire [V_WIDTH:0] v_dec;
	reg  [V_WIDTH:0] v_mux;
`ifdef FORCE_REG
	wire [V_WIDTH:0] v_cnt;
`else
	reg  [V_WIDTH:0] v_cnt;
`endif
	reg  v_first;
	wire v_last;
	wire v_ce;
	reg  v_ce_r;

	// Horizontal Counter
	assign h_dec  = h_cnt - 1;
	assign h_last = h_cnt[H_WIDTH];

	always @(posedge clk or posedge rst)
		if (rst)
			h_first <= 1'b1;
		else
			h_first <= h_last;

	always @(posedge clk or posedge rst)
		if (rst)
			h_zone <= 2'b00;
		else
			h_zone <= h_zone + h_last;

	always @(*)
	begin
		h_mux = h_dec;

		if (h_last)
			case (h_zone)
				Z_FP:     h_mux = H_SYNC   - 2;
				Z_SYNC:   h_mux = H_BP     - 2;
				Z_BP:     h_mux = H_ACTIVE - 2;
				Z_ACTIVE: h_mux = H_FP     - 2;
			endcase
	end

	always @(posedge clk or posedge rst)
		if (rst)
			h_cnt <= 0;
		else
			h_cnt <= h_mux;

	// Vertical Counter
	assign v_dec  = v_cnt - 1;
	assign v_last = v_cnt[V_WIDTH];
	assign v_ce   = h_last & (h_zone == Z_ACTIVE);

	always @(posedge clk)
		v_ce_r <= v_ce;

	always @(posedge clk or posedge rst)
		if (rst)
			v_first <= 1'b1;
		else if (v_ce)
			v_first <= v_last;

	always @(posedge clk or posedge rst)
		if (rst)
			v_zone <= 2'b00;
		else if (v_ce)
			v_zone <= v_zone + v_last;

	always @(*)
	begin
		v_mux = v_dec;

		if (v_last)
			case (v_zone)
				Z_FP:     v_mux = V_SYNC   - 2;
				Z_SYNC:   v_mux = V_BP     - 2;
				Z_BP:     v_mux = V_ACTIVE - 2;
				Z_ACTIVE: v_mux = V_FP     - 2;
			endcase
	end

`ifdef FORCE_REG
	dffer_n #(
		.WIDTH(V_WIDTH+1)
	) v_cnt_I (
		.d(v_mux),
		.q(v_cnt),
		.ce(v_ce),
		.clk(clk),
		.rst(rst)
	);
`else
	always @(posedge clk or posedge rst)
		if (rst)
			v_cnt <= 0;
		else if (v_ce)
			v_cnt <= v_mux;
`endif

	// Active / Sync generation
	always @(posedge clk or posedge rst)
		if (rst) begin
			vid_hsync   <= 1'b0;
			vid_vsync   <= 1'b0;
			vid_active  <= 1'b0;
			vid_h_first <= 1'b0;
			vid_h_last  <= 1'b0;
			vid_v_first <= 1'b0;
			vid_v_last  <= 1'b0;
		end else begin
			vid_hsync   <= (h_zone == Z_SYNC);
			vid_vsync   <= (v_zone == Z_SYNC);
			vid_active  <= (h_zone == Z_ACTIVE) & (v_zone == Z_ACTIVE);
			vid_h_first <= (h_zone == Z_ACTIVE) & h_first;
			vid_h_last  <= (h_zone == Z_ACTIVE) & h_last;
			vid_v_first <= (v_zone == Z_ACTIVE) & v_first;
			vid_v_last  <= (v_zone == Z_ACTIVE) & v_last;
		end

endmodule // vid_tgen
