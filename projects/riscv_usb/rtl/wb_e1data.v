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

	// E1 RX0 data if (write)
	input  wire [7:0] e1rx0_data,
	input  wire [4:0] e1rx0_ts,
	input  wire [3:0] e1rx0_frame,
	input  wire [MFW-1:0] e1rx0_mf,
	input  wire e1rx0_we,
	output wire e1rx0_rdy,

	// E1 RX1 data if (write)
	input  wire [7:0] e1rx1_data,
	input  wire [4:0] e1rx1_ts,
	input  wire [3:0] e1rx1_frame,
	input  wire [MFW-1:0] e1rx1_mf,
	input  wire e1rx1_we,
	output wire e1rx1_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	genvar i;

	// E1 RX0
	reg  e1rx0_pending;
	wire e1rx0_done;
	reg  [7:0] e1rx0_data_reg;
	reg  [AW+LW-1:0] e1rx0_addr_reg;

	// E1 RX1
	reg  e1rx1_pending;
	wire e1rx1_done;
	reg  [7:0] e1rx1_data_reg;
	reg  [AW+LW-1:0] e1rx1_addr_reg;

	// Transactions
	reg  [1:0] state;		// [1] = busy  [0] = RX0(0) / RX1(1)


	// E1 RX0 (write)
	// -------------

	always @(posedge clk)
		if (e1rx0_we) begin
			e1rx0_data_reg <= e1rx0_data;
			e1rx0_addr_reg <= { e1rx0_mf, e1rx0_frame, e1rx0_ts };
		end

	always @(posedge clk or posedge rst)
		if (rst)
			e1rx0_pending <= 1'b0;
		else
			e1rx0_pending <= (e1rx0_pending | e1rx0_we) & ~e1rx0_done;

	assign e1rx0_rdy = ~e1rx0_pending;


	// E1 RX1 (write)
	// -------------

	always @(posedge clk)
		if (e1rx1_we) begin
			e1rx1_data_reg <= e1rx1_data;
			e1rx1_addr_reg <= { e1rx1_mf, e1rx1_frame, e1rx1_ts };
		end

	always @(posedge clk or posedge rst)
		if (rst)
			e1rx1_pending <= 1'b0;
		else
			e1rx1_pending <= (e1rx1_pending | e1rx1_we) & ~e1rx1_done;

	assign e1rx1_rdy = ~e1rx1_pending;


	// Wishbone transactions
	// ---------------------

	always @(posedge clk or posedge rst)
		if (rst)
			state <= 2'b00;
		else
			state <= wb_ack ? 2'b00 : { e1rx0_pending | e1rx1_pending, e1rx1_pending };

	assign e1rx0_done = wb_ack & ~state[0];
	assign e1rx1_done = wb_ack &  state[0];

	assign wb_addr = state[0] ? e1rx1_addr_reg[LW+:AW] : e1rx0_addr_reg[LW+:AW];

	assign wb_cyc = state[1];
	assign wb_we  = 1'b1;

	for (i=0; i<MW; i=i+1)
	begin
		assign wb_wdata[8*i+:8] = state[0] ? e1rx1_data_reg : e1rx0_data_reg;
		assign wb_wmsk[i] = ((state[0] ? e1rx1_addr_reg[LW-1:0] : e1rx0_addr_reg[LW-1:0]) == i);
	end

endmodule // wb_e1data
