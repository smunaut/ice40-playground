/*
 * memtest.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module memtest #(
	parameter integer ADDR_WIDTH = 32,

	// auto
	parameter integer AL = ADDR_WIDTH - 1
)(
	// Memory interface
	output wire [AL:0] mi_addr,
	output wire [ 6:0] mi_len,
	output wire        mi_rw,
	output wire        mi_valid,
	input  wire        mi_ready,

	output wire [31:0] mi_wdata,
	output wire [ 3:0] mi_wmsk,
	input  wire        mi_wack,

	input  wire [31:0] mi_rdata,
	input  wire        mi_rstb,

	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output wire [31:0] wb_rdata,
	input  wire [ 8:0] wb_addr,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output wire        wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Buffers
	wire [ 7:0] bw_waddr;
	wire [31:0] bw_wdata;
	wire        bw_wren;

	reg  [ 7:0] bw_raddr;
	wire [31:0] bw_rdata;
	wire        bw_rden;

	reg  [ 7:0] br_waddr;
	wire [31:0] br_wdata;
	wire        br_wren;

	wire [ 7:0] br_raddr;
	wire [31:0] br_rdata;
	wire        br_rden;

	// Wishbone
	reg wb_ack_i;
	reg wb_we_cmd;
	reg wb_we_addr;

	// Commands
	reg         cmd_valid;
	reg         cmd_start;
	reg         cmd_read;
	reg  [ 6:0] cmd_len;
	reg  [AL:0] cmd_addr;
	reg         cmd_dual;

	// Validate
	reg val_ok;


	// Buffers
	// -------

	ram_sdp #(
		.AWIDTH(8),
		.DWIDTH(32)
	) buf_wr_I (
		.wr_addr (bw_waddr),
		.wr_data (bw_wdata),
		.wr_ena  (bw_wren),
		.rd_addr (bw_raddr),
		.rd_data (bw_rdata),
		.rd_ena  (bw_rden),
		.clk     (clk)
	);

	ram_sdp #(
		.AWIDTH(8),
		.DWIDTH(32)
	) buf_rd_I (
		.wr_addr (br_waddr),
		.wr_data (br_wdata),
		.wr_ena  (br_wren),
		.rd_addr (br_raddr),
		.rd_data (br_rdata),
		.rd_ena  (br_rden),
		.clk     (clk)
	);


	// Wishbone interface
	// ------------------

	// Ack
	always @(posedge clk)
		wb_ack_i <= wb_cyc & ~wb_ack_i;

	assign wb_ack = wb_ack_i;

	// Read Mux
	assign wb_rdata = wb_ack_i ?
		(wb_addr[8] ? br_rdata : { 30'h00000000, val_ok, mi_ready }) :
		32'h00000000;

	// Buffer accesses
	assign bw_waddr = wb_addr[7:0];
	assign bw_wdata = wb_wdata;
	assign bw_wren  = wb_ack_i & wb_we & wb_addr[8];

	assign br_raddr = wb_addr[7:0];
	assign br_rden  = 1'b1;

	// Write Strobes
	always @(posedge clk)
		if (wb_ack_i) begin
			wb_we_cmd  <= 1'b0;
			wb_we_addr <= 1'b0;
		end else begin
			wb_we_cmd  <= wb_cyc & wb_we & ~wb_addr[8] & ~wb_addr[0];
			wb_we_addr <= wb_cyc & wb_we & ~wb_addr[8] &  wb_addr[0];
		end

	always @(posedge clk)
		cmd_start <= wb_we_cmd;

	always @(posedge clk)
		if (rst)
			cmd_valid <= 1'b0;
		else
			cmd_valid <= (cmd_valid & (~mi_ready | cmd_dual)) | cmd_start;

	always @(posedge clk)
		if (wb_we_cmd)
			cmd_dual <= wb_wdata[18];
		else if (mi_ready & mi_valid)
			cmd_dual <= 1'b0;

	always @(posedge clk)
		if (wb_we_cmd) begin
			cmd_read <= wb_wdata[   16];
			cmd_len  <= wb_wdata[ 6: 0];
		end

	always @(posedge clk)
		if (wb_we_addr)
			cmd_addr <= wb_wdata[ADDR_WIDTH-1:0];
		else if (mi_ready & mi_valid)
			cmd_addr <= cmd_addr + cmd_len + 1;


	// Memory interface
	// ----------------

	// Requests
	assign mi_addr    = cmd_addr;
	assign mi_len     = cmd_len;
	assign mi_rw      = cmd_read;
	assign mi_valid   = cmd_valid;

	// Write data (and read-validate)
	always @(posedge clk)
		if (wb_we_cmd)
			bw_raddr <= wb_wdata[15:8];
		else
			bw_raddr <= bw_raddr + bw_rden;

	assign mi_wdata = bw_rdata;
	assign mi_wmsk  = 4'h0;

	assign bw_rden = (cmd_read ? mi_rstb : mi_wack) | cmd_start;

	// Read data
	assign br_wdata = mi_rdata;
	assign br_wren  = mi_rstb;

	always @(posedge clk)
		if (wb_we_cmd)
			br_waddr <= wb_wdata[15:8];
		else
			br_waddr <= br_waddr + mi_rstb;

	// Data validation
	always @(posedge clk)
		if (wb_we_cmd)
			val_ok <= val_ok | wb_wdata[17];
		else
			val_ok <= val_ok & (~mi_rstb | (mi_rdata == bw_rdata));

endmodule
