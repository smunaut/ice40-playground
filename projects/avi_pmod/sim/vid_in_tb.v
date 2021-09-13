/*
 * vid_in_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module vid_in_tb;

	// Signals
	// -------

	wire  [7:0] vi_data;

	wire [31:0] vs_data;
	wire        vs_valid;
	wire        vs_sync;
	wire  [2:0] vs_fvh;
	wire        vs_err;

	wire [23:0] vo_data;
	wire        vo_hsync;
	wire        vo_vsync;
	wire        vo_de;

	reg   [1:0] in_cnt;
	reg  [31:0] in_data;

	reg rst = 1'b1;
	reg clk = 1'b0;


	// DUTs
	// ----

	vid_in_sync sync_I (
		.vi_data  (vi_data),
		.vo_data  (vs_data),
		.vo_valid (vs_valid),
		.vo_sync  (vs_sync),
		.vo_fvh   (vs_fvh),
		.vo_err   (vs_err),
		.clk      (clk),
		.rst      (rst)
	);

	vid_render #(
		.H_ACTIVE (720),
		.H_FP     ( 48),
		.H_SYNC   ( 32),
		.V_FP     (  8),
		.V_SYNC   (  4)
	) render_I (
		.vi_data  (vs_data),
		.vi_valid (vs_valid),
		.vi_sync  (vs_sync),
		.vi_fvh   (vs_fvh),
		.vo_data  (vo_data),
		.vo_hsync (vo_hsync),
		.vo_vsync (vo_vsync),
		.vo_de    (vo_de),
		.clk      (clk),
		.rst      (rst)
	);


	// Data feed
	// ---------

	integer fh_in, rv;

	initial
		fh_in = $fopen("../data/data_c64.txt", "r");

	always @(posedge clk)
		if (rst) begin
			in_cnt  <= 2'b00;
			in_data <= 32'h00000000;
		end else begin
			in_cnt <= in_cnt + 1;

			if (in_cnt == 2'b00)
				rv = $fscanf(fh_in, "%08x", in_data);
			else
				in_data <= { 8'h00, in_data[31:8] };
		end

	assign vi_data = in_data[7:0];


	// Test bench
	// ----------

	// Setup recording
	initial begin
		$dumpfile("vid_in_tb.vcd");
		$dumpvars(0,vid_in_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk = !clk;

endmodule // vid_in_tb
