/*
 * uart_wb.v
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

module uart_wb #(
	parameter integer DIV_WIDTH = 8,
	parameter integer DW = 16
)(
	// UART
	output wire uart_tx,
	input  wire uart_rx,

	// Bus interface
	input  wire [1:0] bus_addr,
	input  wire [DW-1:0] bus_wdata,
	output wire [DW-1:0] bus_rdata,
	input  wire bus_cyc,
	output wire bus_ack,
	input  wire bus_we,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// RX fifo
	wire [ 7:0] urf_wdata;
	wire        urf_wren;
	wire        urf_full;
	wire [ 7:0] urf_rdata;
	wire        urf_rden;
	wire        urf_empty;

	// TX fifo
	wire [ 7:0] utf_wdata;
	wire        utf_wren;
	wire        utf_full;
	wire [ 7:0] utf_rdata;
	wire        utf_rden;
	wire        utf_empty;

	// TX core
	wire [ 7:0] uart_tx_data;
	wire        uart_tx_valid;
	wire        uart_tx_ack;

	// RX core
	wire [ 7:0] uart_rx_data;
	wire        uart_rx_stb;

	// CSR
	reg  [DIV_WIDTH-1:0] uart_div;

	// Bus IF
	reg ub_rd_data;
	reg ub_wr_data;
	reg ub_wr_div;
	reg ub_ack;


	// TX Core
	// -------

	uart_tx #(
		.DIV_WIDTH(DIV_WIDTH)
	) uart_tx_I (
		.data(uart_tx_data),
		.valid(uart_tx_valid),
		.ack(uart_tx_ack),
		.tx(uart_tx),
		.div(uart_div),
		.clk(clk),
		.rst(rst)
	);


	// TX FIFO
	// -------

	fifo_sync_ram #(
		.DEPTH(512),
		.WIDTH(8)
	) uart_tx_fifo_I (
		.wr_data(utf_wdata),
		.wr_ena(utf_wren),
		.wr_full(utf_full),
		.rd_data(utf_rdata),
		.rd_ena(utf_rden),
		.rd_empty(utf_empty),
		.clk(clk),
		.rst(rst)
	);

	// TX glue
	assign uart_tx_data  =  utf_rdata;
	assign uart_tx_valid = ~utf_empty;
	assign utf_rden      =  uart_tx_ack;

	// RX Core
	// -------

	uart_rx #(
		.DIV_WIDTH(DIV_WIDTH),
		.GLITCH_FILTER(2)
	) uart_rx_I (
		.rx(uart_rx),
		.data(uart_rx_data),
		.stb(uart_rx_stb),
		.div(uart_div),
		.clk(clk),
		.rst(rst)
	);


	// RX FIFO
	// -------

	fifo_sync_ram #(
		.DEPTH(512),
		.WIDTH(8)
	) uart_rx_fifo_I (
		.wr_data(urf_wdata),
		.wr_ena(urf_wren),
		.wr_full(urf_full),
		.rd_data(urf_rdata),
		.rd_ena(urf_rden),
		.rd_empty(urf_empty),
		.clk(clk),
		.rst(rst)
	);

	// RX glue
	assign urf_wdata = uart_rx_data;
	assign urf_wren  = uart_rx_stb & ~urf_full;


	// Bus interface
	// -------------

	always @(posedge clk)
		if (ub_ack) begin
			ub_rd_data <= 1'b0;
			ub_wr_data <= 1'b0;
			ub_wr_div  <= 1'b0;
		end else begin
			ub_rd_data <= ~bus_we & bus_cyc & (bus_addr == 2'b00);
			ub_wr_data <=  bus_we & bus_cyc & (bus_addr == 2'b00) & ~utf_full;
			ub_wr_div  <=  bus_we & bus_cyc & (bus_addr == 2'b01);
		end

	always @(posedge clk)
		if (ub_ack)
			ub_ack <= 1'b0;
		else
			ub_ack <= bus_cyc & (~bus_we | (bus_addr == 2'b01) | ~utf_full);

	always @(posedge clk)
		if (ub_wr_div)
			uart_div <= bus_wdata[DIV_WIDTH-1:0];

	assign utf_wdata = bus_wdata[7:0];
	assign utf_wren  = ub_wr_data;

	assign urf_rden  = ub_rd_data & ~urf_empty;

	assign bus_rdata = ub_rd_data ? { urf_empty, { (DW-9){1'b0} }, urf_rdata } : { DW{1'b0} };
	assign bus_ack = ub_ack;

endmodule // uart_wb
