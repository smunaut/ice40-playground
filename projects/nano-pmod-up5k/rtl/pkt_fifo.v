/*
 * pkt_fifo.v
 *
 * vim: ts=4 sw=4
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

module pkt_fifo #(
	parameter integer AWIDTH = 9
)(
	input  wire [7:0] wr_data,
	input  wire wr_last,
	input  wire wr_ena,
	output wire full,

	output wire [7:0] rd_data,
	output wire rd_last,
	input  wire rd_ena,
	output wire empty,

	input  wire clk,
	input  wire rst
);
	// Signals
	reg  [AWIDTH-1:0] ram_waddr;
	wire [7:0] ram_wdata;
	wire ram_wen;

	reg  [AWIDTH-1:0] ram_raddr;
	wire [7:0] ram_rdata;
	wire ram_ren;

	(* keep="true" *) wire [1:0] ln_mod;
	wire [AWIDTH:0] ln_mod_ext;
	reg  [AWIDTH:0] len_nxt;	// Length with next packet
	reg  [AWIDTH:0] len_cur;	// Length current - 1
	wire rd_ce;

	wire valid_nxt;
	reg  valid_out;

	// Storage element
	ram_sdp #(
		.AWIDTH(AWIDTH),
		.DWIDTH(8)
	) ram_I (
		.wr_addr(ram_waddr),
		.wr_data(ram_wdata),
		.wr_ena(ram_wen),
		.rd_addr(ram_raddr),
		.rd_data(ram_rdata),
		.rd_ena(ram_ren),
		.clk(clk)
	);

	// Write pointer
	always @(posedge clk or posedge rst)
		if (rst)
			ram_waddr <= 0;
		else if (wr_ena)
			ram_waddr <= ram_waddr + 1;

	// Read pointer
	always @(posedge clk or posedge rst)
		if (rst)
			ram_raddr <= 0;
		else if (rd_ce)
			ram_raddr <= ram_raddr + 1;

	// Next Length counter
	assign ln_mod = { rd_ce & ~wr_ena, rd_ce ^ wr_ena };
	assign ln_mod_ext = { {(AWIDTH){ln_mod[1]}}, ln_mod[0] };

	always @(posedge clk or posedge rst)
		if (rst)
			len_nxt <= 0;
		else
			len_nxt <= len_nxt + ln_mod_ext;

	// Length counter (readable length minus 1)
	always @(posedge clk)
		if (rst)
			len_cur <= { (AWIDTH+1){1'b1} };
		else
			len_cur <= ((wr_ena & wr_last) ? len_nxt : len_cur) - rd_ce;

	// Write logic
	assign ram_wdata = wr_data;
	assign ram_wen   = wr_ena;
	assign full      = len_nxt[AWIDTH];

	// Read logic
	assign rd_data = ram_rdata;
	assign rd_last = ~valid_nxt;
	assign empty   = ~valid_out;

	assign valid_nxt = ~len_cur[AWIDTH];

	always @(posedge clk or posedge rst)
		if (rst)
			valid_out <= 1'b0;
		else if (rd_ena | ~valid_out)
			valid_out <= valid_nxt;

	assign rd_ce = valid_nxt & (rd_ena | ~valid_out);
	assign ram_ren = rd_ce;

endmodule // pkt_fifo
