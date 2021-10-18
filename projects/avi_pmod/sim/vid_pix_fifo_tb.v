/*
 * vid_pix_fifo_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module vid_pix_fifo_tb;

	// Signals
	reg rst = 1'b1;

	wire [31:0] wr_data;
	wire        wr_ena;
	reg         wr_clk = 1'b0;
	reg         wr_allow;

	wire [31:0] rd_data;
	wire        rd_ena;
	wire        rd_aempty;
	wire        rd_empty;
	reg  [ 4:0] rd_rwd_words;
	reg         rd_rwd_stb;
	reg         rd_clk = 1'b0;
	reg         rd_allow;


	// Setup recording
	initial begin
		$dumpfile("vid_pix_fifo_tb.vcd");
		$dumpvars(0,vid_pix_fifo_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #14 wr_clk = !wr_clk;
	always #10 rd_clk = !rd_clk;

	// DUT
	vid_pix_fifo dut_I (
		.w_data     (wr_data),
		.w_ena      (wr_ena),
		.w_clk      (wr_clk),
		.r_data     (rd_data),
		.r_ena      (rd_ena),
		.r_aempty   (rd_aempty),
		.r_empty    (rd_empty),
		.r_rwd_words(rd_rwd_words),
		.r_rwd_stb  (rd_rwd_stb),
		.r_clk      (rd_clk),
		.rst        (rst)
	);

	// Data generateion
	reg [31:0] cnt;
	reg        rnd_rd;
	reg        rnd_wr;

	always @(posedge wr_clk)
		if (rst) begin
			cnt <= 32'h00000000;
			rnd_wr <= 1'b0;
		end else begin
			cnt <= cnt + wr_ena;
			rnd_wr <= $random;
		end

	always @(posedge rd_clk)
		if (rst) begin
			rnd_rd <= 1'b0;
		end else begin
			rnd_rd <= $random;
		end

	assign wr_data = wr_ena ? cnt : 8'hxx;
	assign wr_ena = wr_allow & rnd_wr;
	assign rd_ena = rd_allow & rnd_rd & ~rd_empty;

	initial
	begin
		rd_rwd_stb <= 1'b0;
		rd_allow   <= 1'b1;
		wr_allow   <= 1'b1;

		#10000 wr_allow <= 1'b0;
		#1000  wr_allow <= 1'b1;

		#10000 rd_allow <= 1'b0;

		#3000
		@(posedge rd_clk);
		rd_rwd_words <= 5'd31;
		rd_rwd_stb   <= 1'b1;
		@(posedge rd_clk);
		rd_rwd_words <= 6'd0;
		rd_rwd_stb   <= 1'b0;

		#1000  rd_allow <= 1'b1;
	end

endmodule // vid_pix_fifo_tb
