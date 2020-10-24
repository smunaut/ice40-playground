/*
 * soc_picorv32_base.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`include "boards.vh"

module soc_picorv32_base #(
	parameter integer WB_N  =  6,
	parameter integer WB_DW = 32,
	parameter integer WB_AW = 16,
	parameter integer SPRAM_AW = 14,	/* 14 => 64k, 15 => 128k */

	/* auto */
	parameter integer WB_MW = WB_DW / 8,
	parameter integer WB_RW = WB_DW * WB_N,
	parameter integer WB_AI = $clog2(WB_MW)
)(
	// Wishbone
	output wire [WB_AW-1:0] wb_addr,
	input  wire [WB_RW-1:0] wb_rdata,
	output wire [WB_DW-1:0] wb_wdata,
	output wire [WB_MW-1:0] wb_wmsk,
	output wire             wb_we,
	output wire [WB_N -1:0] wb_cyc,
	input  wire [WB_N -1:0] wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Memory bus
	wire        mem_valid;
	wire        mem_instr;
	wire        mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_rdata;
	wire [31:0] mem_wdata;
	wire [ 3:0] mem_wstrb;

	// RAM
		// BRAM
	wire [ 7:0] bram_addr;
	wire [31:0] bram_rdata;
	wire [31:0] bram_wdata;
	wire [ 3:0] bram_wmsk;
	wire        bram_we;

		// SPRAM
	wire [14:0] spram_addr;
	wire [31:0] spram_rdata;
	wire [31:0] spram_wdata;
	wire [ 3:0] spram_wmsk;
	wire        spram_we;


	// CPU
	// ---

	picorv32 #(
		.PROGADDR_RESET(32'h 0000_0000),
		.STACKADDR(32'h 0000_0400),
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(0),
		.ENABLE_COUNTERS(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(0),
		.ENABLE_IRQ_QREGS(0),
		.CATCH_MISALIGN(0),
		.CATCH_ILLINSN(0)
	) cpu_I (
		.clk       (clk),
		.resetn    (~rst),
		.mem_valid (mem_valid),
		.mem_instr (mem_instr),
		.mem_ready (mem_ready),
		.mem_addr  (mem_addr),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),
		.mem_rdata (mem_rdata)
	);


	// Bus interface
	// -------------

	soc_picorv32_bridge #(
		.WB_N (WB_N),
		.WB_DW(WB_DW),
		.WB_AW(WB_AW),
		.WB_AI(WB_AI)
	) pb_I (
		.pb_addr     (mem_addr),
		.pb_rdata    (mem_rdata),
		.pb_wdata    (mem_wdata),
		.pb_wstrb    (mem_wstrb),
		.pb_valid    (mem_valid),
		.pb_ready    (mem_ready),
		.bram_addr   (bram_addr),
		.bram_rdata  (bram_rdata),
		.bram_wdata  (bram_wdata),
		.bram_wmsk   (bram_wmsk),
		.bram_we     (bram_we),
		.spram_addr  (spram_addr),
		.spram_rdata (spram_rdata),
		.spram_wdata (spram_wdata),
		.spram_wmsk  (spram_wmsk),
		.spram_we    (spram_we),
		.wb_addr     (wb_addr),
		.wb_wdata    (wb_wdata),
		.wb_wmsk     (wb_wmsk),
		.wb_rdata    (wb_rdata),
		.wb_cyc      (wb_cyc),
		.wb_we       (wb_we),
		.wb_ack      (wb_ack),
		.clk         (clk),
		.rst         (rst)
	);


	// Local memory
	// ------------

	// Boot memory
	soc_bram #(
		.INIT_FILE("boot.hex")
	) bram_I (
		.addr  (bram_addr),
		.rdata (bram_rdata),
		.wdata (bram_wdata),
		.wmsk  (bram_wmsk),
		.we    (bram_we),
		.clk   (clk)
	);

	// Main memory
	soc_spram #(
		.AW(SPRAM_AW)
	) spram_I (
		.addr  (spram_addr[SPRAM_AW-1:0]),
		.rdata (spram_rdata),
		.wdata (spram_wdata),
		.wmsk  (spram_wmsk),
		.we    (spram_we),
		.clk   (clk)
	);

endmodule // soc_picorv32_base
