/*
 * soc_spram.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module soc_spram #(
	parameter integer AW = 14
)(
	input  wire [AW-1:0] addr,
	output wire   [31:0] rdata,
	input  wire   [31:0] wdata,
	input  wire   [ 3:0] wmsk,
	input  wire          we,
	input  wire          clk
);

	wire [7:0] msk_nibble = {
		wmsk[3], wmsk[3],
		wmsk[2], wmsk[2],
		wmsk[1], wmsk[1],
		wmsk[0], wmsk[0]
	};

	ice40_spram_gen #(
		.ADDR_WIDTH(AW),
		.DATA_WIDTH(32)
	) spram_I (
		.addr(addr),
		.rd_data(rdata),
		.rd_ena(1'b1),
		.wr_data(wdata),
		.wr_mask(msk_nibble),
		.wr_ena(we),
		.clk(clk)
	);

endmodule // soc_spram
