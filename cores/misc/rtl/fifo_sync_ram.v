/*
 * fifo_sync_ram.v
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

module fifo_sync_ram #(
	parameter integer DEPTH = 256,
	parameter integer WIDTH = 16
)(
	input  wire [WIDTH-1:0] wr_data,
	input  wire wr_ena,
	output wire wr_full,

	output wire [WIDTH-1:0] rd_data,
	input  wire rd_ena,
	output wire rd_empty,

	input  wire clk,
	input  wire rst
);

	localparam AWIDTH = $clog2(DEPTH);


	// Signals
	// -------

	// RAM
	reg  [AWIDTH-1:0] ram_wr_addr;
	wire [ WIDTH-1:0] ram_wr_data;
	wire ram_wr_ena;

	reg  [AWIDTH-1:0] ram_rd_addr;
	wire [ WIDTH-1:0] ram_rd_data;
	wire ram_rd_ena;

	// Fill-level
	reg  [AWIDTH:0] level;
	(* keep="true" *) wire lvl_dec;
	(* keep="true" *) wire lvl_mov;
	wire lvl_empty;

	// Full
	wire full_nxt;
	reg  full;

	// Read logic
	reg  rd_valid;


	// Fill level counter
	// ------------------
	// (counts the number of used words - 1)

	always @(posedge clk or posedge rst)
		if (rst)
			level <= {(AWIDTH+1){1'b1}};
		else
			level <= level + { {AWIDTH{lvl_dec}}, lvl_mov };

	assign lvl_dec = ram_rd_ena & ~ram_wr_ena;
	assign lvl_mov = ram_rd_ena ^  ram_wr_ena;
	assign lvl_empty = level[AWIDTH];


	// Full flag generation
	// --------------------

	assign full_nxt = level == { 1'b0, {(AWIDTH-2){1'b1}}, 2'b01 };

	always @(posedge clk or posedge rst)
		if (rst)
			full <= 1'b0;
		else
			full <= (full | (wr_ena & ~rd_ena & full_nxt)) & ~(rd_ena & ~wr_ena);

	assign wr_full = full;


	// Write
	// -----

	always @(posedge clk or posedge rst)
		if (rst)
			ram_wr_addr <= 0;
		else if (ram_wr_ena)
			ram_wr_addr <= ram_wr_addr + 1;

	assign ram_wr_data = wr_data;
	assign ram_wr_ena  = wr_ena;


	// Read
	// ----

	always @(posedge clk or posedge rst)
		if (rst)
			ram_rd_addr <= 0;
		else if (ram_rd_ena)
			ram_rd_addr <= ram_rd_addr + 1;

	assign ram_rd_ena = (rd_ena | ~rd_valid) & ~lvl_empty;

	always @(posedge clk or posedge rst)
		if (rst)
			rd_valid <= 1'b0;
		else if (rd_ena | ~rd_valid)
			rd_valid <= ~lvl_empty;

	assign rd_data = ram_rd_data;
	assign rd_empty = ~rd_valid;


	// RAM
	// ---

	ram_sdp #(
		.AWIDTH(AWIDTH),
		.DWIDTH(WIDTH)
	) ram_I (
		.wr_addr(ram_wr_addr),
		.wr_data(ram_wr_data),
		.wr_ena(ram_wr_ena),
		.rd_addr(ram_rd_addr),
		.rd_data(ram_rd_data),
		.rd_ena(ram_rd_ena),
		.clk(clk)
	);

endmodule // fifo_sync_ram
