/*
 * e1_wb.v
 *
 * vim: ts=4 sw=4
 *
 * E1 wishbone top-level
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

module e1_wb #(
	parameter integer MFW = 7
)(
	// IO pads
	input  wire pad_rx_hi_p,
	input  wire pad_rx_hi_n,
	input  wire pad_rx_lo_p,
	input  wire pad_rx_lo_n,

	output wire pad_tx_hi,
	output wire pad_tx_lo,

	// Buffer interface
		// E1 RX (write)
	output wire [7:0] buf_rx_data,
	output wire [4:0] buf_rx_ts,
	output wire [3:0] buf_rx_frame,
	output wire [MFW-1:0] buf_rx_mf,
	output wire buf_rx_we,
	input  wire buf_rx_rdy,

		// E1 TX (read)
	input  wire [7:0] buf_tx_data,
	output wire [4:0] buf_tx_ts,
	output wire [3:0] buf_tx_frame,
	output wire [MFW-1:0] buf_tx_mf,
	output wire buf_tx_re,
	input  wire buf_tx_rdy,

	// Wishbone slave
	input  wire [ 3:0] bus_addr,
	input  wire [15:0] bus_wdata,
	output reg  [15:0] bus_rdata,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// Interrupt
	output reg  irq,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// CSRs and bus access
	wire bus_clr;
	reg  bus_ack_i;

	reg  crx_wren;
	reg  crx_clear;
	reg  ctx_wren;
	reg  ctx_clear;

	wire [15:0] bus_rd_rx_status;
	wire [15:0] bus_rd_rx_bdout;
	wire [15:0] bus_rd_tx_status;
	wire [15:0] bus_rd_tx_bdout;

	// FIFOs
		// BD RX In
	wire [MFW-1:0] bri_di;
	wire [MFW-1:0] bri_do;
	reg  bri_wren;
	wire bri_rden;
	wire bri_full;
	wire bri_empty;

		// BD RX Out
	wire [MFW+1:0] bro_di;
	wire [MFW+1:0] bro_do;
	wire bro_wren;
	reg  bro_rden;
	wire bro_full;
	wire bro_empty;

		// BD TX In
	wire [MFW+1:0] bti_di;
	wire [MFW+1:0] bti_do;
	reg  bti_wren;
	wire bti_rden;
	wire bti_full;
	wire bti_empty;

		// BD TX Out
	wire [MFW-1:0] bto_di;
	wire [MFW-1:0] bto_do;
	wire bto_wren;
	reg  bto_rden;
	wire bto_full;
	wire bto_empty;

	// RX
		// Control
	reg  rx_rst;
	reg  rx_enabled;
	reg  [1:0] rx_mode;
	wire rx_aligned;
	reg  rx_overflow;

		// BD interface
	wire [MFW-1:0] bdrx_mf;
	wire [1:0] bdrx_crc_e;
	wire bdrx_valid;
	wire bdrx_done;
	wire bdrx_miss;

	// Loopback path
	wire lb_bit;
	wire lb_valid;

	// Timing
	wire ext_tick;
	wire int_tick;

	// TX
		// Control
	reg  tx_rst;
	reg  tx_enabled;
	reg  [1:0] tx_mode;
	reg  tx_time_src;
	reg  tx_alarm;
	reg  tx_loopback;
	reg  tx_underflow;

	reg  [1:0] tx_crc_e_auto;

		// BD interface
	wire [MFW-1:0] bdtx_mf;
	wire [1:0] bdtx_crc_e;
	wire bdtx_valid;
	wire bdtx_done;
	wire bdtx_miss;


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
			crx_wren  <= 1'b0;
			crx_clear <= 1'b0;
			ctx_wren  <= 1'b0;
			ctx_clear <= 1'b0;
		end else begin
			crx_wren  <= (bus_addr == 4'h0);
			crx_clear <= (bus_addr == 4'h0) & bus_wdata[12];
			ctx_wren  <= (bus_addr == 4'h4);
			ctx_clear <= (bus_addr == 4'h4) & bus_wdata[12];
		end

	// Control regs
	always @(posedge clk or posedge rst)
		if (rst) begin
			rx_mode     <= 2'b00;
			rx_enabled  <= 1'b0;
			tx_loopback <= 1'b0;
			tx_alarm    <= 1'b0;
			tx_time_src <= 1'b0;
			tx_mode     <= 2'b00;
			tx_enabled  <= 1'b0;
		end else begin
			if (crx_wren) begin
				rx_mode     <= bus_wdata[2:1];
				rx_enabled  <= bus_wdata[0];
			end
			if (ctx_wren) begin
				tx_loopback <= bus_wdata[5];
				tx_alarm    <= bus_wdata[4];
				tx_time_src <= bus_wdata[3];
				tx_mode     <= bus_wdata[2:1];
				tx_enabled  <= bus_wdata[0];
			end
		end

	// Status data
	assign bus_rd_rx_status = {
		3'b000,
		rx_overflow,
		bro_full,
		bro_empty,
		bri_full,
		bri_empty,
		6'b000000,
		rx_aligned,
		rx_enabled
	};

	assign bus_rd_tx_status = {
		3'b000,
		tx_underflow,
		bto_full,
		bto_empty,
		bti_full,
		bti_empty,
		7'b0000000,
		tx_enabled
	};

	// BD FIFO WrEn / RdEn
		// (note we must mask on full/empty here to be consistent with what we
		//  return in the data !)
	always @(posedge clk)
		if (bus_clr) begin
			bri_wren <= 1'b0;
			bti_wren <= 1'b0;
			bro_rden <= 1'b0;
			bto_rden <= 1'b0;
		end else begin
			bri_wren <=  bus_we & ~bri_full  & (bus_addr == 4'h2);
			bti_wren <=  bus_we & ~bti_full  & (bus_addr == 4'h6);
			bro_rden <= ~bus_we & ~bro_empty & (bus_addr == 4'h2);
			bto_rden <= ~bus_we & ~bto_empty & (bus_addr == 4'h6);
		end

	// BD FIFO Data
	assign bri_di = bus_wdata[MFW-1:0];
	assign bti_di = { bus_wdata[14:13], bus_wdata[MFW-1:0] };

	assign bus_rd_rx_bdout = { ~bro_empty, bro_do[MFW+1:MFW], {(13-MFW){1'b0}}, bro_do[MFW-1:0] };
	assign bus_rd_tx_bdout = { ~bto_empty,                    {(15-MFW){1'b0}}, bto_do[MFW-1:0] };

	// Read MUX
	always @(posedge clk)
		if (bus_clr)
			bus_rdata <= 16'h0000;
		else
			case (bus_addr[3:0])
				4'h0:    bus_rdata <= bus_rd_rx_status;	// RX Status
				4'h2:    bus_rdata <= bus_rd_rx_bdout;	// RX BD Out
				4'h4:    bus_rdata <= bus_rd_tx_status;	// TX Status
				4'h6:    bus_rdata <= bus_rd_tx_bdout;	// TX BD Out
				default: bus_rdata <= 16'h0000;
			endcase


	// BD fifos
	// --------

	// BD RX In
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW)
	) bd_rx_in_I (
    	.wr_data(bri_di),
    	.wr_ena(bri_wren),
    	.wr_full(bri_full),
    	.rd_data(bri_do),
    	.rd_ena(bri_rden),
    	.rd_empty(bri_empty),
    	.clk(clk),
    	.rst(rst)
	);

	// BD RX Out
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW+2)
	) bd_rx_out_I (
    	.wr_data(bro_di),
    	.wr_ena(bro_wren),
    	.wr_full(bro_full),
    	.rd_data(bro_do),
    	.rd_ena(bro_rden),
    	.rd_empty(bro_empty),
    	.clk(clk),
    	.rst(rst)
	);

	// BD TX In
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW+2)
	) bd_tx_in_I (
    	.wr_data(bti_di),
    	.wr_ena(bti_wren),
    	.wr_full(bti_full),
    	.rd_data(bti_do),
    	.rd_ena(bti_rden),
    	.rd_empty(bti_empty),
    	.clk(clk),
    	.rst(rst)
	);

	// BD TX Out
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW)
	) bd_tx_out_I (
    	.wr_data(bto_di),
    	.wr_ena(bto_wren),
    	.wr_full(bto_full),
    	.rd_data(bto_do),
    	.rd_ena(bto_rden),
    	.rd_empty(bto_empty),
    	.clk(clk),
    	.rst(rst)
	);


	// RX submodule
	// ------------

	// RX core
	e1_rx #(
		.MFW(MFW)
	) rx_I (
		.pad_rx_hi_p(pad_rx_hi_p),
		.pad_rx_hi_n(pad_rx_hi_n),
		.pad_rx_lo_p(pad_rx_lo_p),
		.pad_rx_lo_n(pad_rx_lo_n),
		.buf_data(buf_rx_data),
		.buf_ts(buf_rx_ts),
		.buf_frame(buf_rx_frame),
		.buf_mf(buf_rx_mf),
		.buf_we(buf_rx_we),
		.buf_rdy(buf_rx_rdy),
		.bd_mf(bdrx_mf),
		.bd_crc_e(bdrx_crc_e),
		.bd_valid(bdrx_valid),
		.bd_done(bdrx_done),
		.bd_miss(bdrx_miss),
		.lb_bit(lb_bit),
		.lb_valid(lb_valid),
		.status_aligned(rx_aligned),
		.clk(clk),
		.rst(rx_rst)
	);

	// BD FIFO interface
	assign bdrx_mf    =  bri_do;
	assign bdrx_valid = ~bri_empty;

	assign bri_rden = bdrx_done;

	assign bro_di   = { bdrx_crc_e, bdrx_mf };
	assign bro_wren = ~bro_full & bdrx_done;

	// Control logic
		// Local reset
	always @(posedge clk or posedge rst)
		if (rst)
			rx_rst <= 1'b1;
		else
			rx_rst <= ~rx_enabled;

		// Overflow
	always @(posedge clk or posedge rst)
		if (rst)
			rx_overflow <= 1'b0;
		else
			rx_overflow <= (rx_overflow & ~crx_clear) | bdrx_miss;


	// TX submodule
	// ------------

	// TX core
	e1_tx #(
		.MFW(MFW)
	) tx_I (
		.pad_tx_hi(pad_tx_hi),
		.pad_tx_lo(pad_tx_lo),
		.buf_data(buf_tx_data),
		.buf_ts(buf_tx_ts),
		.buf_frame(buf_tx_frame),
		.buf_mf(buf_tx_mf),
		.buf_re(buf_tx_re),
		.buf_rdy(buf_tx_rdy),
		.bd_mf(bdtx_mf),
		.bd_crc_e(bdtx_crc_e),
		.bd_valid(bdtx_valid),
		.bd_done(bdtx_done),
		.bd_miss(bdtx_miss),
		.lb_bit(lb_bit),
		.lb_valid(lb_valid),
		.ext_tick(ext_tick),
		.int_tick(int_tick),
		.ctrl_time_src(tx_time_src),
		.ctrl_do_framing(tx_mode != 2'b00),
		.ctrl_do_crc4(tx_mode[1]),
		.ctrl_loopback(tx_loopback),
		.alarm(tx_alarm),
		.clk(clk),
		.rst(tx_rst)
	);

	assign ext_tick = lb_valid;

	// Auto E-bit tracking
	always @(posedge clk)
		tx_crc_e_auto <= (bdtx_done ? 2'b00 : tx_crc_e_auto) | (bdrx_done ? bdrx_crc_e : 2'b00);

	// BD FIFO interface
	assign bdtx_mf    =  bti_do[MFW-1:0];
	assign bdtx_crc_e = (tx_mode == 2'b11) ? tx_crc_e_auto : bti_do[MFW+1:MFW];
	assign bdtx_valid = ~bti_empty;

	assign bti_rden = bdtx_done;

	assign bto_di   =  bdtx_mf;
	assign bto_wren = ~bto_full & bdtx_done;

	// Control logic
		// Local reset
	always @(posedge clk or posedge rst)
		if (rst)
			tx_rst <= 1'b1;
		else
			tx_rst <= ~tx_enabled;

		// Underflow
	always @(posedge clk or posedge rst)
		if (rst)
			tx_underflow <= 1'b0;
		else
			tx_underflow <= (tx_underflow & ~ctx_clear) | bdtx_miss;


	// IRQ
	// ---

	always @(posedge clk or posedge rst)
		if (rst)
			irq <= 1'b0;
		else
			irq <= ~bro_empty | rx_overflow | ~bto_empty | tx_underflow;

endmodule // e1_wb
