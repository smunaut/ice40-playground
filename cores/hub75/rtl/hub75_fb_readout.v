/*
 * hub75_fb_readout.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

`default_nettype none

module hub75_fb_readout #(
	parameter integer N_BANKS  = 2,
	parameter integer N_ROWS   = 32,
	parameter integer N_COLS   = 64,
	parameter integer N_CHANS  = 3,
	parameter integer N_PLANES = 8,
	parameter integer BITDEPTH = 24,
	parameter integer FB_AW    = 13,
	parameter integer FB_DW    = 16,
	parameter integer FB_DC    = 2,

	// Auto-set
	parameter integer LOG_N_BANKS = $clog2(N_BANKS),
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS),
	parameter integer LOG_N_COLS  = $clog2(N_COLS)
)(
	// Read interface - Preload
	input  wire [LOG_N_ROWS-1:0] rd_row_addr,
	input  wire rd_row_load,
	output wire rd_row_rdy,
	input  wire rd_row_swap,

	// Read interface - Access
	output wire [(N_BANKS * N_CHANS * N_PLANES)-1:0] rd_data,
	input  wire [LOG_N_COLS-1:0] rd_col_addr,
	input  wire rd_en,

	// Read Out - Control
	output wire ctrl_req,
	input  wire ctrl_gnt,
	output reg  ctrl_rel,

	// Read Out - Frame Buffer Access
	output wire [FB_AW-1:0] fb_addr,
	input  wire [FB_DW-1:0] fb_data,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Counter = [ col_addr : bank_addr : dc_idx ]
	localparam integer CS1 = $clog2(FB_DC);
	localparam integer CS2 = CS1 + LOG_N_BANKS;
	localparam integer CW  = CS2 + LOG_N_COLS;


	// Signals
	// -------

	// Read-out process
	reg  rop_buf;

	reg  rop_pending;
	reg  rop_running;
	reg  rop_ready;

	reg [LOG_N_ROWS-1:0] rop_row_addr;

	reg [CW-1:0] rop_cnt;
	reg rop_last;

	wire rop_move;
	wire rop_done;

	// Frame buffer access
	wire fb_rden;

	reg  fb_rden_r;
	reg  [FB_DW-1:0] fb_data_save;
	wire [FB_DW-1:0] fb_data_mux;
	reg  [(FB_DC*FB_DW)-1:0] fb_data_ext;

	// Color Mapper
	reg  [CW-CS1-1:0] cm_in_user_addr_pre;
	reg  cm_in_user_last_pre;
	reg  cm_in_valid_pre;

	wire [BITDEPTH-1:0] cm_in_data;
	reg  [CW-CS1-1:0] cm_in_user_addr;
	reg  cm_in_user_last;
	reg  cm_in_valid;
	wire cm_in_ready;

	wire [(N_CHANS*N_PLANES)-1:0] cm_out_data;
	wire [CW-CS1-1:0] cm_out_user_addr;
	wire cm_out_user_last;
	wire cm_out_valid;

	// Line buffer access
	wire [(N_BANKS * N_CHANS * N_PLANES)-1:0] rolb_wr_data;
	wire [N_BANKS-1:0] rolb_wr_mask;
	wire [LOG_N_COLS-1:0] rolb_wr_addr;
	wire rolb_wr_ena;


	// Control
	// -------

	// Buffer swap
	always @(posedge clk or posedge rst)
		if (rst)
			rop_buf <= 1'b0;
		else
			rop_buf <= rop_buf ^ rd_row_swap;

	// Track status and requests
	always @(posedge clk or posedge rst)
		if (rst) begin
			rop_pending <= 1'b0;
			rop_running <= 1'b0;
			rop_ready   <= 1'b0;
		end else begin
			rop_pending <= (rop_pending & ~ctrl_gnt) |  rd_row_load;
			rop_running <= (rop_running & ~rop_done) |  ctrl_gnt;
			rop_ready   <= (rop_ready   |  rop_done) & ~rd_row_load;
		end

	// Arbiter interface
	assign ctrl_req = rop_pending;

	always @(posedge clk)
		ctrl_rel <= cm_out_valid & cm_out_user_last;

	// Read interface
	assign rd_row_rdy = rop_ready;

	// Latch row address
	always @(posedge clk)
		if (rd_row_load)
			rop_row_addr <= rd_row_addr;

	// Counter
	always @(posedge clk or negedge rop_running)
		if (~rop_running) begin
			rop_cnt  <= 0;
			rop_last <= 1'b0;
		end else if (rop_move) begin
			rop_cnt  <= rop_cnt + 1;
			rop_last <= rop_cnt == ((N_COLS << CS2) - 2);
		end

	assign rop_done = rop_last & rop_move;

	// Move pipeline ahead
	assign rop_move = ~cm_in_valid | cm_in_ready;


	// Line buffer
	// -----------

	hub75_linebuffer #(
		.N_WORDS(N_BANKS),
		.WORD_WIDTH(N_CHANS * N_PLANES),
		.ADDR_WIDTH(1 + LOG_N_COLS)
	) readout_buf_I (
		.wr_addr({~rop_buf, rolb_wr_addr}),
		.wr_data(rolb_wr_data),
		.wr_mask(rolb_wr_mask),
		.wr_ena(rolb_wr_ena),
		.rd_addr({rop_buf, rd_col_addr}),
		.rd_data(rd_data),
		.rd_ena(rd_en),
		.clk(clk)
	);


	// Frame buffer -> Color mapper
	// ----------------------------

	// Frame buffer read
	assign fb_addr = { rop_row_addr, rop_cnt };
	assign fb_rden = rop_move;

	// Simulate a 'READ ENABLE' on the frame buffer by saving the previous
	// data and muxing
	always @(posedge clk)
		fb_rden_r <= fb_rden;

	always @(posedge clk)
		if (fb_rden_r)
			fb_data_save <= fb_data;

	assign fb_data_mux = fb_rden_r ? fb_data : fb_data_save;

	// Shift register of frame buffer words to reconstruct and entire
	// 'BITDEPTH' worth of bits.
	always @(posedge clk)
		if (rop_move)
			if (FB_DC > 1)
				fb_data_ext <= { fb_data_mux, fb_data_ext[(FB_DC*FB_DW)-1:FB_DW] };
			else
				fb_data_ext <= { fb_data_mux };

	// Map to the color mapper input
	assign cm_in_data = fb_data_ext[BITDEPTH-1:0];

	always @(posedge clk or posedge rst)
		if (rst) begin
			cm_in_valid_pre <= 1'b0;
			cm_in_valid <= 1'b0;
		end else if (rop_move) begin
			if (CS1 > 0)
				cm_in_valid_pre <= rop_running & &rop_cnt[CS1-1:0];
			else
				cm_in_valid_pre <= rop_running;

			cm_in_valid <= cm_in_valid_pre;
		end

	always @(posedge clk)
		if (rop_move) begin
			// This is synced with the RAM output
			cm_in_user_addr_pre <= rop_cnt[CW-1:CS1];
			cm_in_user_last_pre <= rop_last;

			// This is synced with the fb_data_ext signal
			cm_in_user_addr <= cm_in_user_addr_pre;
			cm_in_user_last <= cm_in_user_last_pre;
		end


	// Color mapping core
	// ------------------

	hub75_colormap #(
		.N_CHANS(N_CHANS),
		.N_PLANES(N_PLANES),
		.BITDEPTH(BITDEPTH),
		.USER_WIDTH(CW-CS1+1)
	) cm_I (
		.in_data(cm_in_data),
		.in_user({cm_in_user_addr, cm_in_user_last}),
		.in_valid(cm_in_valid),
		.in_ready(cm_in_ready),
		.out_data(cm_out_data),
		.out_user({cm_out_user_addr, cm_out_user_last}),
		.out_valid(cm_out_valid),
		.clk(clk),
		.rst(rst)
	);


	// Color mapper -> Line buffer
	// ---------------------------

	genvar i;

	assign rolb_wr_data = { (N_BANKS){cm_out_data} };
	assign rolb_wr_addr = cm_out_user_addr[CW-CS1-1:CS2-CS1];
	assign rolb_wr_ena  = cm_out_valid;

	generate
		if (N_BANKS > 1)
			for (i=0; i<N_BANKS; i=i+1)
				assign rolb_wr_mask[i] = (cm_out_user_addr[CS2-CS1-1:0] == i);
		else
			assign rolb_wr_mask = 1'b1;
	endgenerate

endmodule // hub75_fb_readout
