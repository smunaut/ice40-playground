/*
 * vid_line_mem.v
 *
 * vim: ts=4 sw=4
 *
 * Dual buffer memory to store lines.
 * - Accesses 2 pixels at a time in 4:2:2 mode ( Cb Y0 Cr Y1 )
 * - For 720 pixels
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_line_mem (
	// Write port
	input  wire        w_clk,
	input  wire        w_buf,
	input  wire  [8:0] w_pix,	// 0-767
	input  wire        w_ena,
	input  wire [31:0] w_data,

	// Read port
	input  wire        r_clk,
	input  wire        r_buf_0,
	input  wire  [8:0] r_pix_0,	// 0-767
	output wire [31:0] r_data_1
);

	// Signals
	// -------

	// Lower memory block (pixels 0-512)
	reg  [31:0] lmb_mem[0:511];

	(* keep *)
	wire        lmb_we;
	wire [ 8:0] lmb_waddr;
	wire [31:0] lmb_wdata;

	wire [ 8:0] lmb_raddr;
	reg  [31:0] lmb_rdata;

	// Upper memory block (pixels 512-768)
	reg  [31:0] umb_mem[0:255];

	(* keep *)
	wire        umb_we;
	wire [ 7:0] umb_waddr;
	wire [31:0] umb_wdata;

	wire [ 7:0] umb_raddr;
	reg  [31:0] umb_rdata;

	// Save UMB/LMB selection
	reg         umb_sel_1;


	// Memories
	// --------

	// Lower memory block
	always @(posedge w_clk)
		if (lmb_we)
			lmb_mem[lmb_waddr] <= lmb_wdata;

	always @(posedge r_clk)
		lmb_rdata <= lmb_mem[lmb_raddr];

	// Upper memory block
	always @(posedge w_clk)
		if (umb_we)
			umb_mem[umb_waddr] <= umb_wdata;

	always @(posedge r_clk)
		umb_rdata <= umb_mem[umb_raddr];


	// Map to external requests
	// ------------------------

	// Write
	assign lmb_wdata = w_data;
	assign umb_wdata = w_data;

	assign lmb_waddr = { w_buf, w_pix[7:0] };
	assign umb_waddr = { w_buf, w_pix[6:0] };

	assign lmb_we = w_ena & ~w_pix[8];
	assign umb_we = w_ena &  w_pix[8];

	// Read
	always @(posedge r_clk)
		umb_sel_1 <= r_pix_0[8];

	assign lmb_raddr = { r_buf_0, r_pix_0[7:0] };
	assign umb_raddr = { r_buf_0, r_pix_0[6:0] };

	assign r_data_1 = umb_sel_1 ? umb_rdata : lmb_rdata;

endmodule // vid_line_mem
