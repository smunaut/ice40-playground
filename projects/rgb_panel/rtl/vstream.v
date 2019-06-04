/*
 * vstream.v
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
 *
 * vim: ts=4 sw=4
 */

`default_nettype none

module vstream #(
	parameter integer N_ROWS   = 64,	// # of rows (must be power of 2!!!)
	parameter integer N_COLS   = 64,	// # of columns
	parameter integer BITDEPTH = 24,

	// Auto-set
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS),
	parameter integer LOG_N_COLS  = $clog2(N_COLS)
)(
	// SPI to the host
	input  wire spi_mosi,
	output wire spi_miso,
	input  wire spi_cs_n,
	input  wire spi_clk,

	// Frame Buffer write interface
	output wire [LOG_N_ROWS-1:0] fbw_row_addr,
	output wire fbw_row_store,
	input  wire fbw_row_rdy,
	output wire fbw_row_swap,

	output wire [BITDEPTH-1:0] fbw_data,
	output wire [LOG_N_COLS-1:0] fbw_col_addr,
	output wire fbw_wren,

	output wire frame_swap,
	input  wire frame_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam integer TW = BITDEPTH / 8;

	// Signals
	// -------

	// SPI bus
	wire [7:0] sb_addr;
	wire [7:0] sb_data;
	wire sb_first;
	wire sb_last;
	wire sb_stb;
	wire [7:0] sb_out;

	// Front Buffer write
	reg [TW-1:0] trig;
	reg [LOG_N_COLS-1:0] cnt_col;
	reg [7:0] sb_data_r[0:1];

	reg store_swap_pending;

	reg [5:0] err_cnt;
	wire err;


	// SPI interface
	// -------------

`ifdef SPI_FAST
	spi_fast spi_I (
`else
	spi_simple spi_I (
`endif
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.spi_cs_n(spi_cs_n),
		.spi_clk(spi_clk),
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.last(sb_last),
		.strobe(sb_stb),
		.out(sb_out),
		.clk(clk),
		.rst(rst)
	);

	assign sb_out = { err_cnt, frame_rdy, fbw_row_rdy };


	// Front-Buffer write
	// ------------------

	// "Trigger"
	always @(posedge clk or posedge rst)
		if (TW > 1) begin
			if (rst)
				trig <= { 1'b1, {(TW-1){1'b0}} };
			else if (sb_stb)
				trig <= sb_last ? { 1'b1, {(TW-1){1'b0}} } : { trig[0], trig[TW-1:1] };
		end else
			trig <= 1'b1;

	// Column counter
	always @(posedge clk or posedge rst)
		if (rst)
			cnt_col <= 0;
		else if (sb_stb)
			cnt_col <= sb_last ? 0 : (cnt_col + trig[0]);

	// Register data for wide writes
	always @(posedge clk)
		if (sb_stb) begin
			sb_data_r[0] <= sb_data;
			sb_data_r[1] <= sb_data_r[0];
		end

	// Write commands
	assign fbw_wren = sb_stb & sb_addr[7] & trig[0];
	assign fbw_col_addr = cnt_col;

	// Map to color
	generate
		if (BITDEPTH == 8)
			assign fbw_data = sb_data;
		else if (BITDEPTH == 16)
			assign fbw_data = { sb_data, sb_data_r[0] };
		else if (BITDEPTH == 24)
			assign fbw_data = { sb_data, sb_data_r[0], sb_data_r[1] };
	endgenerate


	// Back-Buffer store
	// -----------------

	// Direct commands
	assign fbw_row_addr  = sb_data[LOG_N_ROWS-1:0];
	assign fbw_row_store = (sb_stb & sb_first & ~sb_addr[7] & sb_addr[0]) | (fbw_row_rdy & store_swap_pending);
	assign fbw_row_swap  = (sb_stb & sb_first & ~sb_addr[7] & sb_addr[1]) | (fbw_row_rdy & store_swap_pending);

	// Delayed command
	always @(posedge clk or posedge rst)
		if (rst)
			store_swap_pending <= 1'b0;
		else
			store_swap_pending <= (store_swap_pending & ~fbw_row_rdy) | (sb_stb & sb_first & ~sb_addr[7] & sb_addr[3]);

	// Error tracking
	assign err =
		(~fbw_row_rdy & (fbw_row_store | fbw_row_swap)) |
		(store_swap_pending & fbw_wren);

	always @(posedge clk or posedge rst)
		if (rst)
			err_cnt <= 0;
		else
			err_cnt <= err_cnt + err;


	// Next frame
	// ----------

	assign frame_swap = sb_stb & sb_first & ~sb_addr[7] & sb_addr[2];

endmodule // vstream
