/*
 * soc_picorv32_bridge.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module soc_picorv32_bridge #(
	parameter integer WB_N   =  8,
	parameter integer WB_DW  = 32,
	parameter integer WB_AW  = 16,
	parameter integer WB_AI  =  2,
	parameter integer WB_REG =  0	// [0] = cyc / [1] = addr/wdata/wstrb / [2] = ack/rdata
)(
	/* PicoRV32 bus */
	input  wire [31:0] pb_addr,
	output wire [31:0] pb_rdata,
	input  wire [31:0] pb_wdata,
	input  wire [ 3:0] pb_wstrb,
	input  wire        pb_valid,
	output wire        pb_ready,

	/* BRAM */
	output wire [ 7:0] bram_addr,
	input  wire [31:0] bram_rdata,
	output wire [31:0] bram_wdata,
	output wire [ 3:0] bram_wmsk,
	output wire        bram_we,

	/* SPRAM */
	output wire [14:0] spram_addr,
	input  wire [31:0] spram_rdata,
	output wire [31:0] spram_wdata,
	output wire [ 3:0] spram_wmsk,
	output wire        spram_we,

	/* Wishbone buses */
	output wire [WB_AW-1:0]        wb_addr,
	input  wire [(WB_DW*WB_N)-1:0] wb_rdata,
	output wire [WB_DW-1:0]        wb_wdata,
	output wire [(WB_DW/8)-1:0]    wb_wmsk,
	output wire                    wb_we,
	output wire [WB_N-1:0]         wb_cyc,
	input  wire [WB_N-1:0]         wb_ack,

	/* Clock / Reset */
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	wire ram_sel;
	reg  ram_rdy;
	wire [31:0] ram_rdata;

	(* keep *) wire [WB_N-1:0] wb_match;
	(* keep *) wire wb_cyc_rst;

	reg  [31:0] wb_rdata_or;
	wire [31:0] wb_rdata_out;
	wire wb_rdy;


	// RAM access
	// ----------
	// BRAM  : 0x00000000 -> 0x000003ff
	// SPRAM : 0x00020000 -> 0x0003ffff

	assign bram_addr  = pb_addr[ 9:2];
	assign spram_addr = pb_addr[16:2];

	assign bram_wdata  = pb_wdata;
	assign spram_wdata = pb_wdata;

	assign bram_wmsk  = ~pb_wstrb;
	assign spram_wmsk = ~pb_wstrb;

	assign bram_we  = pb_valid & ~pb_addr[31] & |pb_wstrb & ~pb_addr[17];
	assign spram_we = pb_valid & ~pb_addr[31] & |pb_wstrb &  pb_addr[17];

	assign ram_rdata = ~pb_addr[31] ? (pb_addr[17] ? spram_rdata : bram_rdata) : 32'h00000000;

	assign ram_sel = pb_valid & ~pb_addr[31];

	always @(posedge clk)
		ram_rdy <= ram_sel && ~ram_rdy;


	// Wishbone
	// --------
	// wb[x] = 0x8x000000 - 0x8xffffff

	// Access Cycle
	genvar i;
	for (i=0; i<WB_N; i=i+1)
		assign wb_match[i] = (pb_addr[27:24] == i);

	if (WB_REG & 1) begin
		// Register
		reg [WB_N-1:0] wb_cyc_reg;
		always @(posedge clk)
			if (wb_cyc_rst)
				wb_cyc_reg <= 0;
			else
				wb_cyc_reg <= wb_match & ~wb_ack;
		assign wb_cyc = wb_cyc_reg;
	end else begin
		// Direct connection
		assign wb_cyc = wb_cyc_rst ? { WB_N{1'b0} } : wb_match;
	end

	// Addr / Write-Data / Write-Mask / Write-Enable
	if (WB_REG & 2) begin
		// Register
		reg [WB_AW-1:0] wb_addr_reg;
		reg [WB_DW-1:0] wb_wdata_reg;
		reg [(WB_DW/8)-1:0] wb_wmsk_reg;
		reg wb_we_reg;

		always @(posedge clk)
		begin
			wb_addr_reg  <= pb_addr[WB_AW+WB_AI-1:WB_AI];
			wb_wdata_reg <= pb_wdata[WB_DW-1:0];
			wb_wmsk_reg  <= ~pb_wstrb[(WB_DW/8)-1:0];
			wb_we_reg    <= |pb_wstrb;
		end

		assign wb_addr  = wb_addr_reg;
		assign wb_wdata = wb_wdata_reg;
		assign wb_wmsk  = wb_wmsk_reg;
		assign wb_we    = wb_we_reg;
	end else begin
		// Direct connection
		assign wb_addr  = pb_addr[WB_AW+WB_AI-1:WB_AI];
		assign wb_wdata = pb_wdata[WB_DW-1:0];
		assign wb_wmsk  = pb_wstrb[(WB_DW/8)-1:0];
		assign wb_we    = |pb_wstrb;
	end

	// Ack / Read-Data
	always @(*)
	begin : wb_or
		integer i;
		wb_rdata_or = 0;
		for (i=0; i<WB_N; i=i+1)
			wb_rdata_or[WB_DW-1:0] = wb_rdata_or[WB_DW-1:0] | wb_rdata[WB_DW*i+:WB_DW];
	end

	if (WB_REG & 4) begin
		// Register
		reg wb_rdy_reg;
		reg [31:0] wb_rdata_reg;

		always @(posedge clk)
			wb_rdy_reg <= |wb_ack;

		always @(posedge clk)
			if (wb_cyc_rst)
				wb_rdata_reg <= 32'h00000000;
			else
				wb_rdata_reg <= wb_rdata_or;

		assign wb_cyc_rst = ~pb_valid | ~pb_addr[31] | wb_rdy_reg;
		assign wb_rdy = wb_rdy_reg;
		assign wb_rdata_out = wb_rdata_reg;
	end else begin
		// Direct connection
		assign wb_cyc_rst = ~pb_valid | ~pb_addr[31];
		assign wb_rdy = |wb_ack;
		assign wb_rdata_out = wb_rdata_or;
	end


	// Final data combining
	// --------------------

	assign pb_rdata = ram_rdata | wb_rdata_out;
	assign pb_ready = ram_rdy | wb_rdy;

endmodule // soc_picorv32_bridge
