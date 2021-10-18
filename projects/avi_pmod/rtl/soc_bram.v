/*
 * soc_bram.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module soc_bram #(
	parameter integer AW = 8,
	parameter INIT_FILE = ""
)(
	input  wire [AW-1:0] addr,
	output reg    [31:0] rdata,
	input  wire   [31:0] wdata,
	input  wire   [ 3:0] wmsk,
	input  wire          we,
	input  wire          clk
);

	reg [31:0] mem [0:(1<<AW)-1];

	initial
		if (INIT_FILE != "")
			$readmemh(INIT_FILE, mem);

	always @(posedge clk) begin
		rdata <= mem[addr];
		if (we & ~wmsk[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
		if (we & ~wmsk[1]) mem[addr][15: 8] <= wdata[15: 8];
		if (we & ~wmsk[2]) mem[addr][23:16] <= wdata[23:16];
		if (we & ~wmsk[3]) mem[addr][31:24] <= wdata[31:24];
	end

endmodule // soc_bram
