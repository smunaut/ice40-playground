/*
 * wb_e1data.v
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

module wb_e1data #(
	parameter integer AW = 14,
	parameter integer DW = 32,				// 16 or 32
	parameter integer MW = DW / 8,			// Mask Width
	parameter integer LW = $clog2(MW),		// LSB Width
	parameter integer MFW = AW + LW - 9		// Multi-Frame width
)(
	// Wishbone master
	output wire [AW-1:0] wb_addr,
	input  wire [DW-1:0] wb_rdata,
	output wire [DW-1:0] wb_wdata,
	output wire [MW-1:0] wb_wmsk,
	output wire wb_cyc,
	output wire wb_we,
	input  wire wb_ack,

	// E1 RX data if (write)
	input  wire [7:0] e1rx_data,
	input  wire [4:0] e1rx_ts,
	input  wire [3:0] e1rx_frame,
	input  wire [MFW-1:0] e1rx_mf,
	input  wire e1rx_we,
	output wire e1rx_rdy,

	// E1 TX data if (read)
	output wire [7:0] e1tx_data,
	input  wire [4:0] e1tx_ts,
	input  wire [3:0] e1tx_frame,
	input  wire [MFW-1:0] e1tx_mf,
	input  wire e1tx_re,
	output wire e1tx_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	genvar i;

	// E1 RX
	reg  e1rx_pending;
	wire e1rx_done;
	reg  [7:0] e1rx_data_reg;
	reg  [AW+LW-1:0] e1rx_addr_reg;

	// E1 TX
	reg  e1tx_pending;
	wire e1tx_done;
	reg  [7:0] e1tx_data_reg;
	reg  [AW+LW-1:0] e1tx_addr_reg;

	// Transactions
	reg  [1:0] state;		// [1] = busy  [0] = r(0) / w(1)


	// E1 RX (write)
	// -------------

	always @(posedge clk)
		if (e1rx_we) begin
			e1rx_data_reg <= e1rx_data;
			e1rx_addr_reg <= { e1rx_mf, e1rx_frame, e1rx_ts };
		end

	always @(posedge clk or posedge rst)
		if (rst)
			e1rx_pending <= 1'b0;
		else
			e1rx_pending <= (e1rx_pending | e1rx_we) & ~e1rx_done;

	assign e1rx_rdy = ~e1rx_pending;

	for (i=0; i<MW; i=i+1)
	begin
		assign wb_wdata[8*i+:8] = e1rx_data_reg;
		assign wb_wmsk[i] = (e1rx_addr_reg[LW-1:0] == i);
	end


	// E1 TX (read)
	// ------------

	always @(posedge clk)
		if (e1tx_re)
			e1tx_addr_reg <= { e1tx_mf, e1tx_frame, e1tx_ts };

	always @(posedge clk or posedge rst)
		if (rst)
			e1tx_pending <= 1'b0;
		else
			e1tx_pending <= (e1tx_pending | e1tx_re) & ~e1tx_done;

	assign e1tx_rdy = ~e1tx_pending;

	always @(posedge clk)
		if (e1tx_done)
			e1tx_data_reg <= wb_rdata[8*e1tx_addr_reg[LW-1:0]+:8];

	assign e1tx_data = e1tx_data_reg;


	// Wishbone transactions
	// ---------------------

	always @(posedge clk or posedge rst)
		if (rst)
			state <= 2'b00;
		else
			state <= wb_ack ? 2'b00 : { e1rx_pending | e1tx_pending, ~e1tx_pending };

	assign e1rx_done = wb_ack &  state[0];
	assign e1tx_done = wb_ack & ~state[0];

	assign wb_addr = state[0] ? e1rx_addr_reg[LW+:AW] : e1tx_addr_reg[LW+:AW];

	assign wb_cyc = state[1];
	assign wb_we  = state[0];

endmodule // wb_e1data
