/*
 * hdmi_buf.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module hdmi_buf (
	// Write port
	input  wire [ 8:0] waddr,
	input  wire [31:0] wdata,
	input  wire        wren,

	// Read port
	input  wire [ 9:0] raddr,
	output wire [15:0] rdata,

	// Clock
	input  wire clk
);

	genvar i;

	generate
		for (i=0; i<4; i=i+1)
			ice40_ebr #(
				.READ_MODE  (2),	// 1024x4
				.WRITE_MODE (1)		//  512x8
			) ebr_wrap_I (
				.wr_addr (waddr),
				.wr_data ({wdata[i*4+:4], wdata[16+i*4+:4]}),
				.wr_mask (8'h00),
				.wr_ena  (wren),
				.wr_clk  (clk),
				.rd_addr (raddr),
				.rd_data (rdata[i*4+:4]),
				.rd_ena  (1'b1),
				.rd_clk  (clk)
			);
	endgenerate

endmodule
