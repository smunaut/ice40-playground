/*
 * bridge.v
 *
 * vim: ts=4 sw=4
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
 */

`default_nettype none

module bridge #(
	parameter integer WB_N  =  8,
	parameter integer WB_DW = 32,
	parameter integer WB_AW = 16,
	parameter integer WB_AI =  2
)(
	/* PicoRV32 bus */
	input  wire [31:0] pb_addr,
	output wire [31:0] pb_rdata,
	input  wire [31:0] pb_wdata,
	input  wire [ 3:0] pb_wstrb,
	input  wire pb_valid,
	output wire pb_ready,

	/* BRAM */
	output wire [ 7:0] bram_addr,
	input  wire [31:0] bram_rdata,
	output wire [31:0] bram_wdata,
	output wire [ 3:0] bram_wmsk,
	output wire        bram_we,

	/* SPRAM */
	output wire [13:0] spram_addr,
	input  wire [31:0] spram_rdata,
	output wire [31:0] spram_wdata,
	output wire [ 3:0] spram_wmsk,
	output wire        spram_we,

	/* Wishbone buses */
	output wire [WB_AW-1:0] wb_addr,
	output wire [WB_DW-1:0] wb_wdata,
	output wire [(WB_DW/8)-1:0] wb_wmsk,
	input  wire [(WB_DW*WB_N)-1:0] wb_rdata,
	output wire [WB_N-1:0] wb_cyc,
	output wire wb_we,
	input  wire [WB_N-1:0] wb_ack,

	/* Clock / Reset */
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	wire ram_sel;
	reg  ram_rdy;
	wire [31:0] ram_rdata;

	reg  [31:0] wb_rdata_or;
	wire wb_rdy;


	// RAM access
	// ----------
	// BRAM  : 0x00000000 -> 0x000003ff
	// SPRAM : 0x00010000 -> 0x0001ffff

	assign bram_addr  = pb_addr[ 9:2];
	assign spram_addr = pb_addr[15:2];

	assign bram_wdata  = pb_wdata;
	assign spram_wdata = pb_wdata;

	assign bram_wmsk  = pb_wstrb;
	assign spram_wmsk = pb_wstrb;

	assign bram_we  = pb_valid & ~pb_addr[31] & |pb_wstrb & ~pb_addr[16];
	assign spram_we = pb_valid & ~pb_addr[31] & |pb_wstrb &  pb_addr[16];

	assign ram_rdata = ~pb_addr[31] ? (pb_addr[16] ? spram_rdata : bram_rdata) : 32'h00000000;

	assign ram_sel = pb_valid & ~pb_addr[31];

	always @(posedge clk)
		ram_rdy <= ram_sel && ~ram_rdy;


	// Wishbone
	// --------
	// wb[x] = 0x8x000000 - 0x8xffffff

	genvar i;

	assign wb_addr  = pb_addr[WB_AW+WB_AI-1:WB_AI];
	assign wb_wdata = pb_wdata[WB_DW-1:0];
	assign wb_wmsk  = pb_wstrb[(WB_DW/8)-1:0];
	assign wb_we    = |pb_wstrb;

	for (i=0; i<WB_N; i=i+1)
		assign wb_cyc[i] = pb_valid & pb_addr[31] & (pb_addr[27:24] == i);

	assign wb_rdy = |wb_ack;

	always @(*)
	begin : wb_or
		integer i;
		wb_rdata_or = 0;
		for (i=0; i<WB_N; i=i+1)
			wb_rdata_or[WB_DW-1:0] = wb_rdata_or[WB_DW-1:0] | wb_rdata[WB_DW*i+:WB_DW];
	end


	// Final data combining
	// --------------------

	assign pb_rdata = ram_rdata | wb_rdata_or;
	assign pb_ready = ram_rdy | wb_rdy;

endmodule // bridge
