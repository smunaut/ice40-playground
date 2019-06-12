/*
 * hub75_top_tb.v
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
`timescale 1ns / 100ps

module hub75_top_tb;

	// Params
	localparam integer N_BANKS  = 2;
	localparam integer N_ROWS   = 32;
	localparam integer N_COLS   = 64;
	localparam integer N_CHANS  = 3;
	localparam integer N_PLANES = 8;
	localparam integer BITDEPTH = 24;

	localparam integer LOG_N_BANKS = $clog2(N_BANKS);
	localparam integer LOG_N_ROWS  = $clog2(N_ROWS);
	localparam integer LOG_N_COLS  = $clog2(N_COLS);

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;
	reg clk_2x = 1'b0;

	wire [$clog2(N_ROWS)-1:0] hub75_addr;
	wire [(N_BANKS*N_CHANS)-1:0] hub75_data;
	wire hub75_clk;
	wire hub75_le;
	wire hub75_blank;

	wire [LOG_N_BANKS-1:0] fbw_bank_addr;
	wire [LOG_N_ROWS-1:0]  fbw_row_addr;
	wire fbw_row_store;
	wire fbw_row_rdy;
	wire fbw_row_swap;

	wire [BITDEPTH-1:0] fbw_data;
	wire [LOG_N_COLS-1:0] fbw_col_addr;
	wire fbw_wren;

	wire frame_swap;
	wire frame_rdy;

	// SPI Reader
`ifndef PATTERN
	wire spi_mosi;
	wire spi_miso;
	wire spi_cs_n;
	wire spi_clk;

	wire [23:0] sr_addr;
	wire [15:0] sr_len;
	wire sr_go;
	wire sr_rdy;

	wire [7:0] sr_data;
	wire sr_valid;
`endif

	// Setup recording
	initial begin
		$dumpfile("hub75_top_tb.vcd");
		$dumpvars(0,hub75_top_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 10000000 $finish;
	end

	// Clocks
	always #33 clk = !clk;			// ~ 30 MHz
	always #16.5 clk_2x = !clk_2x;	// ~ 60 MHz

	// DUT
	hub75_top #(
		.N_BANKS(N_BANKS),
		.N_ROWS(N_ROWS),
		.N_COLS(N_COLS),
		.N_CHANS(N_CHANS),
		.N_PLANES(N_PLANES),
		.BITDEPTH(BITDEPTH)
	) dut_I (
		.hub75_addr(hub75_addr),
		.hub75_data(hub75_data),
		.hub75_clk(hub75_clk),
		.hub75_le(hub75_le),
		.hub75_blank(hub75_blank),
		.fbw_bank_addr(fbw_bank_addr),
		.fbw_row_addr(fbw_row_addr),
		.fbw_row_store(fbw_row_store),
		.fbw_row_rdy(fbw_row_rdy),
		.fbw_row_swap(fbw_row_swap),
		.fbw_data(fbw_data),
		.fbw_col_addr(fbw_col_addr),
		.fbw_wren(fbw_wren),
		.frame_swap(frame_swap),
		.frame_rdy(frame_rdy),
		.ctrl_run(1'b1),
		.cfg_pre_latch_len(8'h80),
		.cfg_latch_len(8'h80),
		.cfg_post_latch_len(8'h80),
		.cfg_bcm_bit_len(8'h06),
		.clk(clk),
		.clk_2x(clk_2x),
		.rst(rst)
	);

`ifdef PATTERN
	pgen #(
		.N_ROWS(N_BANKS * N_ROWS),
		.N_COLS(N_COLS),
		.BITDEPTH(BITDEPTH)
	) pgen_I (
		.fbw_row_addr({fbw_bank_addr, fbw_row_addr}),
		.fbw_row_store(fbw_row_store),
		.fbw_row_rdy(fbw_row_rdy),
		.fbw_row_swap(fbw_row_swap),
		.fbw_data(fbw_data),
		.fbw_col_addr(fbw_col_addr),
		.fbw_wren(fbw_wren),
		.frame_swap(frame_swap),
		.frame_rdy(frame_rdy),
		.clk(clk),
		.rst(rst)
	);
`else
	vgen #(
		.ADDR_BASE(24'h040000),
		.N_FRAMES(30),
		.N_ROWS(N_BANKS * N_ROWS),
		.N_COLS(N_COLS),
		.BITDEPTH(BITDEPTH)
	) vgen_I (
		.sr_addr(sr_addr),
		.sr_len(sr_len),
		.sr_go(sr_go),
		.sr_rdy(sr_rdy),
		.sr_data(sr_data),
		.sr_valid(sr_valid),
		.fbw_row_addr({fbw_bank_addr, fbw_row_addr}),
		.fbw_row_store(fbw_row_store),
		.fbw_row_rdy(fbw_row_rdy),
		.fbw_row_swap(fbw_row_swap),
		.fbw_data(fbw_data),
		.fbw_col_addr(fbw_col_addr),
		.fbw_wren(fbw_wren),
		.frame_swap(frame_swap),
		.frame_rdy(frame_rdy),
		.ui_up(1'b0),
		.ui_mode(1'b0),
		.ui_down(1'b0),
		.clk(clk),
		.rst(rst)
	);

	spi_flash_reader spi_reader_I (
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.spi_cs_n(spi_cs_n),
		.spi_clk(spi_clk),
		.addr(sr_addr),
		.len(sr_len),
		.go(sr_go),
		.rdy(sr_rdy),
		.data(sr_data),
		.valid(sr_valid),
		.clk(clk),
		.rst(rst)
	);
`endif

endmodule // hub75_top_tb
