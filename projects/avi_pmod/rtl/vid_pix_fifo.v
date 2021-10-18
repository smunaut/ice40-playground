/*
 * vid_pix_fifo.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_pix_fifo (
	// Write port
	input  wire [31:0] w_data,
	input  wire        w_ena,
	input  wire        w_clk,

	// Output port
	output wire [31:0] r_data,
	input  wire        r_ena,
	output wire        r_aempty,
	output wire        r_empty,

	input  wire [ 4:0] r_rwd_words,
	input  wire        r_rwd_stb,

	input  wire        r_clk,

	// Reset
	input  wire        rst
);

	// Signals
	// -------

	// Memory
	reg  [31:0] mem[0:255];

	wire        mem_we;
	reg  [ 7:0] mem_waddr;
	wire [31:0] mem_wdata;

	wire        mem_re;
	reg  [ 7:0] mem_raddr;
	reg  [31:0] mem_rdata;

	// Clock-Domain crossing
	reg         xw_busy;
	reg         xw_w2r_toggle;
	reg   [1:0] xr_w2r_toggle;
	reg         xr_w2r_pulse;
	reg         xr_r2w_toggle;
	reg   [1:0] xw_r2w_toggle;

	reg   [7:0] xw_waddr;
	reg   [7:0] xr_waddr_n;

	// Level tracking
	wire [7:0] r_level;
	wire       r_level_is_zero;
	wire       r_level_is_one;
	reg        r_level_empty;
	reg        r_level_aempty;

	// Tracking BRAM output validity
	reg        r_valid;

	// Reset
	reg         w_rst;
	reg         r_rst;


	// Memory
	// ------

	always @(posedge w_clk)
		if (mem_we)
			mem[mem_waddr] <= mem_wdata;

	always @(posedge r_clk)
		if (mem_re)
			mem_rdata <= mem[mem_raddr];


	// Reset resync
	// ------------

	always @(posedge w_clk or posedge rst)
		if (rst)
			w_rst <= 1'b1;
		else
			w_rst <= 1'b0;

	always @(posedge r_clk or posedge rst)
		if (rst)
			r_rst <= 1'b1;
		else
			r_rst <= 1'b0;


	// Write
	// -----

	always @(posedge w_clk or posedge w_rst)
		if (w_rst)
			mem_waddr <= 0;
		else if (w_ena)
			mem_waddr <= mem_waddr + 1;

	assign mem_we    = w_ena;
	assign mem_wdata = w_data;


	// Clock crossing
	// --------------
		// This continuously sends the write address to the read domain

	// Write waiting ?
	always @(posedge w_clk or posedge w_rst)
		if (w_rst)
			xw_busy <= 1'b0;
		else
			xw_busy <= ~^xw_r2w_toggle;

	// Write-to-Read toggle
	always @(posedge w_clk or posedge w_rst)
		if (w_rst)
			xw_w2r_toggle <= 1'b0;
		else
			xw_w2r_toggle <= xw_w2r_toggle ^ ~xw_busy;

	// Write-to-Read toggle capture
	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			xr_w2r_toggle <= 2'b00;
		else
			xr_w2r_toggle <= { xr_w2r_toggle[0], xw_w2r_toggle };

	// Write-to-Read pulse
	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			xr_w2r_pulse <= 1'b0;
		else
			xr_w2r_pulse <= ^xr_w2r_toggle;

	// Read-to-Write toggle
	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			xr_r2w_toggle <= 1'b0;
		else
			xr_r2w_toggle <= xr_r2w_toggle ^ (^xr_w2r_toggle);

	// Read-to-Write toggle capture
	always @(posedge w_clk or posedge w_rst)
		if (w_rst)
			xw_r2w_toggle <= 2'b00;
		else
			xw_r2w_toggle <= { xw_r2w_toggle[0], xr_r2w_toggle };

	// Keep write pointer static while being sent
	always @(posedge w_clk or posedge w_rst)
		if (w_rst)
			xw_waddr <= 8'h00;
		else if (~xw_busy)
			xw_waddr <= mem_waddr;

	// Capture write pointer in read domain
	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			xr_waddr_n <= 8'hff;
		else if (xr_w2r_pulse)
			xr_waddr_n <= ~xw_waddr;


	// Read flag / Level tracking
	// --------------------------

	// Read level
	assign r_level = ~(xr_waddr_n + mem_raddr);

	// Check if read level is 0 or 1
	assign r_level_is_zero = (r_level == 8'h00);
	assign r_level_is_one  = (r_level == 8'h01);

	// Empty flag
	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			r_level_empty <= 1'b1;
		else
			r_level_empty <= r_level_is_zero | (r_level_is_one & mem_re);

	// Almost empty flag
	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			r_level_aempty <= 1'b1;
		else
			r_level_aempty <= (r_level[7:6] == 2'b00);


	// Read
	// ----

	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			mem_raddr <= 0;
		else
			mem_raddr <= mem_raddr + (r_rwd_stb ? ~r_rwd_words : 5'd0) + mem_re;

	assign mem_re = (r_ena | ~r_valid) & ~r_level_empty;

	always @(posedge r_clk or posedge r_rst)
		if (r_rst)
			r_valid <= 1'b0;
		else if (r_rwd_stb)
			r_valid <= 1'b0;
		else if (r_ena | ~r_valid)
			r_valid <= ~r_level_empty;

	assign r_data   =  mem_rdata;
	assign r_aempty =  r_level_aempty;
	assign r_empty  = ~r_valid;

endmodule // vid_pix_fifo
