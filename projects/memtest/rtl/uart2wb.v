/*
 * uart2wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
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

module uart2wb #(
	parameter integer WB_N = 3,

	// auto
	parameter integer DL = (32*WB_N)-1,
	parameter integer CL = WB_N-1
)(
	// UART
	input  wire        uart_rx,
	output wire        uart_tx,

	input  wire [ 7:0] uart_div,

	// Wishbone
	output reg  [31:0] wb_wdata,
	input  wire [DL:0] wb_rdata,
	output reg  [15:0] wb_addr,
	output reg         wb_we,
	output reg  [CL:0] wb_cyc,
	input  wire	[CL:0] wb_ack,

	// Aux-CSR
	output reg  [31:0] aux_csr,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam
		CMD_SYNC        = 4'h0,
		CMD_REG_ACCESS  = 4'h1,
		CMD_DATA_SET    = 4'h2,
		CMD_DATA_GET    = 4'h3,
		CMD_AUX_CSR     = 4'h4;


	// Signals
	// -------

	// UART serdes
	wire [7:0] rx_data;
	wire rx_stb;

	wire [7:0] tx_data;
	wire tx_ack;
	wire tx_valid;

	// Command RX
	reg  [39:0] rx_reg;
	reg  [ 2:0] rx_cnt;

	wire [ 3:0] cmd_code;
	wire [31:0] cmd_data;
	reg         cmd_stb;

	// Response TX
	reg  [31:0] tx_reg;
	reg  [ 2:0] tx_cnt;

	reg  [31:0] resp_data;
	reg         resp_ld;

	// Wishbone interface
	reg  [31:0] wb_rdata_i;
	wire		wb_ack_i;


	// Host interface
	// --------------

	// UART module
	uart_rx #(
		.DIV_WIDTH(8),
		.GLITCH_FILTER(0)
	) rx_I (
		.rx(uart_rx),
		.data(rx_data),
		.stb(rx_stb),
		.div(uart_div),
		.clk(clk),
		.rst(rst)
	);

	uart_tx #(
		.DIV_WIDTH(8)
	) tx_I (
		.tx(uart_tx),
		.data(tx_data),
		.valid(tx_valid),
		.ack(tx_ack),
		.div(uart_div),
		.clk(clk),
		.rst(rst)
	);

	// Command input
	always @(posedge clk or posedge rst)
		if (rst)
			rx_cnt <= 3'd0;
		else if (rx_stb)
			rx_cnt <= rx_cnt[2] ? 3'd0 : (rx_cnt + 1);

	always @(posedge clk)
		if (rx_stb)
			rx_reg <= { rx_reg[31:0], rx_data };

	assign cmd_code = rx_reg[39:36];
	assign cmd_data = rx_reg[31: 0];

	always @(posedge clk)
		cmd_stb <= rx_cnt[2] & rx_stb;

    // Response output
	always @(posedge clk or posedge rst)
		if (rst)
			tx_cnt <= 3'd0;
		else begin
			if (resp_ld)
				tx_cnt <= 3'd4;
			else if (tx_ack)
				tx_cnt <= tx_cnt - 1;
		end

	always @(posedge clk)
		if (resp_ld)
			tx_reg <= resp_data;
		else if (tx_ack)
			tx_reg <= { tx_reg[23:0], 8'h00 };

	assign tx_data  = tx_reg[31:24];
	assign tx_valid = |tx_cnt;

	// Commands
	always @(posedge clk)
	begin
		// Defaults
		resp_ld   <= 1'b0;
		resp_data <= 40'hxxxxxxxxxx;

		// Commands
		if (cmd_stb) begin
			case (cmd_code)
				CMD_SYNC: begin
					resp_data <= 432'hcafebabe;
					resp_ld   <= 1'b1;
				end

				CMD_REG_ACCESS: begin
					wb_addr  <=  cmd_data[15:0];
					wb_we    <= ~cmd_data[20];
					wb_cyc   <= (1 << cmd_data[19:16]);
				end

				CMD_DATA_SET: begin
					wb_wdata <= cmd_data;
				end

				CMD_DATA_GET: begin
					resp_ld   <= 1'b1;
					resp_data <= wb_wdata;
				end

				CMD_AUX_CSR: begin
				    aux_csr <= cmd_data;
				end
			endcase
		end

		if (wb_ack_i) begin
			// Cycle done
			wb_cyc <= 0;

			// Capture read response
			if (~wb_we)
				wb_wdata <= wb_rdata_i;
		end

		if (rst) begin
			wb_cyc   <= 0;
			aux_csr  <= 32'h00000000;
		end
	end

	// Wishbone multi-slave handling
	assign wb_ack_i = |wb_ack;

	always @(*)
	begin : rdata
		integer i;

		wb_rdata_i = 32'h00000000;

		for (i=0; i<WB_N; i=i+1)
			wb_rdata_i = wb_rdata_i | wb_rdata[32*i+:32];
	end

endmodule
