/*
 * e1_spy_wb.v
 *
 * vim: ts=4 sw=4
 *
 * E1 spy/dual-rx wishbone top-level
 *
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */


`default_nettype none

module e1_spy_wb #(
	parameter integer MFW = 7
)(
	// IO pads
	input  wire pad_rx0_data,
	input  wire pad_rx0_clk,
	input  wire pad_rx1_data,
	input  wire pad_rx1_clk,

	// Buffer interface
		// E1 RX0 (write)
	output wire [7:0] buf_rx0_data,
	output wire [4:0] buf_rx0_ts,
	output wire [3:0] buf_rx0_frame,
	output wire [MFW-1:0] buf_rx0_mf,
	output wire buf_rx0_we,
	input  wire buf_rx0_rdy,

	output wire [7:0] buf_rx1_data,
	output wire [4:0] buf_rx1_ts,
	output wire [3:0] buf_rx1_frame,
	output wire [MFW-1:0] buf_rx1_mf,
	output wire buf_rx1_we,
	input  wire buf_rx1_rdy,

	// Wishbone slave
	input  wire [ 3:0] bus_addr,
	input  wire [15:0] bus_wdata,
	output reg  [15:0] bus_rdata,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// External strobes
	output reg  irq,
	output wire tick_rx0,
	output wire tick_rx1,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// CSRs and bus access
	wire bus_clr;
	reg  bus_ack_i;

	reg  crx0_wren;
	reg  crx0_clear;
	reg  crx1_wren;
	reg  crx1_clear;

	wire [15:0] bus_rd_rx0_status;
	wire [15:0] bus_rd_rx0_bdout;
	wire [15:0] bus_rd_rx1_status;
	wire [15:0] bus_rd_rx1_bdout;

	// FIFOs
		// BD RX0 In
	wire [MFW-1:0] br0i_di;
	wire [MFW-1:0] br0i_do;
	reg  br0i_wren;
	wire br0i_rden;
	wire br0i_full;
	wire br0i_empty;

		// BD RX0 Out
	wire [MFW+1:0] br0o_di;
	wire [MFW+1:0] br0o_do;
	wire br0o_wren;
	reg  br0o_rden;
	wire br0o_full;
	wire br0o_empty;

		// BD RX1 In
	wire [MFW-1:0] br1i_di;
	wire [MFW-1:0] br1i_do;
	reg  br1i_wren;
	wire br1i_rden;
	wire br1i_full;
	wire br1i_empty;

		// BD RX1 Out
	wire [MFW+1:0] br1o_di;
	wire [MFW+1:0] br1o_do;
	wire br1o_wren;
	reg  br1o_rden;
	wire br1o_full;
	wire br1o_empty;

	// RX0
		// Control
	reg  rx0_rst;
	reg  rx0_enabled;
	reg  [1:0] rx0_mode;
	wire rx0_aligned;
	reg  rx0_overflow;

		// BD interface
	wire [MFW-1:0] bdrx0_mf;
	wire [1:0] bdrx0_crc_e;
	wire bdrx0_valid;
	wire bdrx0_done;
	wire bdrx0_miss;

	// RX1
		// Control
	reg  rx1_rst;
	reg  rx1_enabled;
	reg  [1:0] rx1_mode;
	wire rx1_aligned;
	reg  rx1_overflow;

		// BD interface
	wire [MFW-1:0] bdrx1_mf;
	wire [1:0] bdrx1_crc_e;
	wire bdrx1_valid;
	wire bdrx1_done;
	wire bdrx1_miss;


	// CSRs & FIFO bus access
	// ----------------------

	// Ack is always 1 cycle after access
	always @(posedge clk)
		bus_ack_i <= bus_cyc & ~bus_ack_i;

	assign bus_ack = bus_ack_i;
	assign bus_clr = ~bus_cyc | bus_ack_i;

	// Control WrEn
	always @(posedge clk)
		if (bus_clr | ~bus_we) begin
			crx0_wren  <= 1'b0;
			crx0_clear <= 1'b0;
			crx1_wren  <= 1'b0;
			crx1_clear <= 1'b0;
		end else begin
			crx0_wren  <= (bus_addr == 4'h0);
			crx0_clear <= (bus_addr == 4'h0) & bus_wdata[12];
			crx1_wren  <= (bus_addr == 4'h4);
			crx1_clear <= (bus_addr == 4'h4) & bus_wdata[12];
		end

	// Control regs
	always @(posedge clk or posedge rst)
		if (rst) begin
			rx0_mode    <= 2'b00;
			rx0_enabled <= 1'b0;
			rx1_mode    <= 2'b00;
			rx1_enabled <= 1'b0;
		end else begin
			if (crx0_wren) begin
				rx0_mode    <= bus_wdata[2:1];
				rx0_enabled <= bus_wdata[0];
			end
			if (crx1_wren) begin
				rx1_mode    <= bus_wdata[2:1];
				rx1_enabled <= bus_wdata[0];
			end
		end

	// Status data
	assign bus_rd_rx0_status = {
		3'b000,
		rx0_overflow,
		br0o_full,
		br0o_empty,
		br0i_full,
		br0i_empty,
		6'b000000,
		rx0_aligned,
		rx0_enabled
	};

	assign bus_rd_rx1_status = {
		3'b000,
		rx1_overflow,
		br1o_full,
		br1o_empty,
		br1i_full,
		br1i_empty,
		6'b000000,
		rx1_aligned,
		rx1_enabled
	};

	// BD FIFO WrEn / RdEn
		// (note we must mask on full/empty here to be consistent with what we
		//  return in the data !)
	always @(posedge clk)
		if (bus_clr) begin
			br0i_wren <= 1'b0;
			br1i_wren <= 1'b0;
			br0o_rden <= 1'b0;
			br1o_rden <= 1'b0;
		end else begin
			br0i_wren <=  bus_we & ~br0i_full  & (bus_addr == 4'h2);
			br1i_wren <=  bus_we & ~br1i_full  & (bus_addr == 4'h6);
			br0o_rden <= ~bus_we & ~br0o_empty & (bus_addr == 4'h2);
			br1o_rden <= ~bus_we & ~br1o_empty & (bus_addr == 4'h6);
		end

	// BD FIFO Data
	assign br0i_di = bus_wdata[MFW-1:0];
	assign br1i_di = bus_wdata[MFW-1:0];

	assign bus_rd_rx0_bdout = { ~br0o_empty, br0o_do[MFW+1:MFW], {(13-MFW){1'b0}}, br0o_do[MFW-1:0] };
	assign bus_rd_rx1_bdout = { ~br1o_empty, br1o_do[MFW+1:MFW], {(13-MFW){1'b0}}, br1o_do[MFW-1:0] };

	// Read MUX
	always @(posedge clk)
		if (bus_clr)
			bus_rdata <= 16'h0000;
		else
			case (bus_addr[3:0])
				4'h0:    bus_rdata <= bus_rd_rx0_status;	// RX0 Status
				4'h2:    bus_rdata <= bus_rd_rx0_bdout;		// RX0 BD Out
				4'h4:    bus_rdata <= bus_rd_rx1_status;	// RX1 Status
				4'h6:    bus_rdata <= bus_rd_rx1_bdout;		// RX1 BD Out
				default: bus_rdata <= 16'h0000;
			endcase


	// BD fifos
	// --------

	// BD RX0 In
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW)
	) bd_rx0_in_I (
    	.wr_data(br0i_di),
    	.wr_ena(br0i_wren),
    	.wr_full(br0i_full),
    	.rd_data(br0i_do),
    	.rd_ena(br0i_rden),
    	.rd_empty(br0i_empty),
    	.clk(clk),
    	.rst(rst_rx0)
	);

	// BD RX0 Out
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW+2)
	) bd_rx0_out_I (
    	.wr_data(br0o_di),
    	.wr_ena(br0o_wren),
    	.wr_full(br0o_full),
    	.rd_data(br0o_do),
    	.rd_ena(br0o_rden),
    	.rd_empty(br0o_empty),
    	.clk(clk),
    	.rst(rst_rx0)
	);

	// BD RX1 In
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW)
	) bd_rx1_in_I (
    	.wr_data(br1i_di),
    	.wr_ena(br1i_wren),
    	.wr_full(br1i_full),
    	.rd_data(br1i_do),
    	.rd_ena(br1i_rden),
    	.rd_empty(br1i_empty),
    	.clk(clk),
    	.rst(rst_rx1)
	);

	// BD RX1 Out
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW+2)
	) bd_rx1_out_I (
    	.wr_data(br1o_di),
    	.wr_ena(br1o_wren),
    	.wr_full(br1o_full),
    	.rd_data(br1o_do),
    	.rd_ena(br1o_rden),
    	.rd_empty(br1o_empty),
    	.clk(clk),
    	.rst(rst_rx1)
	);


	// RX0 submodule
	// ------------

	// RX core
	e1_rx #(
		.LIU(1),
		.MFW(MFW)
	) rx0_I (
		.pad_rx_data(pad_rx0_data),
		.pad_rx_clk(pad_rx0_clk),
		.buf_data(buf_rx0_data),
		.buf_ts(buf_rx0_ts),
		.buf_frame(buf_rx0_frame),
		.buf_mf(buf_rx0_mf),
		.buf_we(buf_rx0_we),
		.buf_rdy(buf_rx0_rdy),
		.bd_mf(bdrx0_mf),
		.bd_crc_e(bdrx0_crc_e),
		.bd_valid(bdrx0_valid),
		.bd_done(bdrx0_done),
		.bd_miss(bdrx0_miss),
		.lb_valid(tick_rx0),
		.status_aligned(rx0_aligned),
		.clk(clk),
		.rst(rx0_rst)
	);

	// BD FIFO interface
	assign bdrx0_mf    =  br0i_do;
	assign bdrx0_valid = ~br0i_empty;

	assign br0i_rden = bdrx0_done;

	assign br0o_di   = { bdrx0_crc_e, bdrx0_mf };
	assign br0o_wren = ~br0o_full & bdrx0_done;

	// Control logic
		// Local reset
	always @(posedge clk or posedge rst)
		if (rst)
			rx0_rst <= 1'b1;
		else
			rx0_rst <= ~rx0_enabled;

		// Overflow
	always @(posedge clk or posedge rst)
		if (rst)
			rx0_overflow <= 1'b0;
		else
			rx0_overflow <= (rx0_overflow & ~crx0_clear) | bdrx0_miss;


	// RX1 submodule
	// ------------

	// RX core
	e1_rx #(
		.LIU(1),
		.MFW(MFW)
	) rx1_I (
		.pad_rx_data(pad_rx1_data),
		.pad_rx_clk(pad_rx1_clk),
		.buf_data(buf_rx1_data),
		.buf_ts(buf_rx1_ts),
		.buf_frame(buf_rx1_frame),
		.buf_mf(buf_rx1_mf),
		.buf_we(buf_rx1_we),
		.buf_rdy(buf_rx1_rdy),
		.bd_mf(bdrx1_mf),
		.bd_crc_e(bdrx1_crc_e),
		.bd_valid(bdrx1_valid),
		.bd_done(bdrx1_done),
		.bd_miss(bdrx1_miss),
		.lb_valid(tick_rx1),
		.status_aligned(rx1_aligned),
		.clk(clk),
		.rst(rx1_rst)
	);

	// BD FIFO interface
	assign bdrx1_mf    =  br1i_do;
	assign bdrx1_valid = ~br1i_empty;

	assign br1i_rden = bdrx1_done;

	assign br1o_di   = { bdrx1_crc_e, bdrx1_mf };
	assign br1o_wren = ~br1o_full & bdrx1_done;

	// Control logic
		// Local reset
	always @(posedge clk or posedge rst)
		if (rst)
			rx1_rst <= 1'b1;
		else
			rx1_rst <= ~rx1_enabled;

		// Overflow
	always @(posedge clk or posedge rst)
		if (rst)
			rx1_overflow <= 1'b0;
		else
			rx1_overflow <= (rx1_overflow & ~crx1_clear) | bdrx1_miss;


	// External strobes
	// ----------------

	always @(posedge clk or posedge rst)
		if (rst)
			irq <= 1'b0;
		else
			irq <= ~br0o_empty | rx0_overflow | ~br1o_empty | rx1_overflow;

endmodule // e1_spy_wb
