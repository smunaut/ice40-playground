/*
 * wb_dma.v
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

module wb_dma #(
	parameter integer A0W = 9,
	parameter integer A1W = 9,
	parameter integer DW = 32
)(
	// Master 0
	output wire [A0W-1:0] m0_addr,
	input  wire [ DW-1:0] m0_rdata,
	output wire [ DW-1:0] m0_wdata,
	output wire m0_cyc,
	output wire m0_we,
	input  wire m0_ack,

	// Master 1
	output wire [A1W-1:0] m1_addr,
	input  wire [ DW-1:0] m1_rdata,
	output wire [ DW-1:0] m1_wdata,
	output wire m1_cyc,
	output wire m1_we,
	input  wire m1_ack,

	// Slave (control)
	input  wire [1:0] ctl_addr,
	output wire [DW-1:0] ctl_rdata,
	input  wire [DW-1:0] ctl_wdata,
	input  wire ctl_cyc,
	input  wire ctl_we,
	output wire ctl_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Control
	reg [1:0] state;	// [1] = busy [0] = phase 0(read) 1(write)
	reg [1:0] state_nxt;
	reg dir;			// 0 = M0->M1, 1 = M1->M0
	reg go;

	wire ack_rd;
	wire ack_wr;

	// Data register
	wire data_ce;
	reg  [DW-1:0] data_reg;

	// Address counters
	wire m0_addr_ce;
	wire m0_addr_ld;
	reg  [A0W-1:0] m0_addr_i;

	wire m1_addr_ce;
	wire m1_addr_ld;
	reg  [A1W-1:0] m1_addr_i;

	// Length counter
	wire len_ce;
	wire len_ld;
	reg  [12:0] len;
	wire len_last;

	// Control IF
	reg  ctl_do_write;
	reg  ctl_do_read;
	reg  ctl_ack_i;


	// Control
	// -------

	always @(posedge clk or posedge rst)
		if (rst)
			go <= 1'b0;
		else
			go <= ctl_do_write & (ctl_addr[1:0] == 2'b00) & ctl_wdata[15];

	always @(posedge clk or posedge rst)
		if (rst)
			state <= 2'b00;
		else
			state <= state_nxt;

	always @(*)
	begin
		state_nxt <= state;

		case (state)
			2'b00: begin
				if (go)
					state_nxt <= 2'b10;
			end

			2'b10: begin
				if (ack_rd)
					state_nxt <= 2'b11;
			end

			2'b11: begin
				if (ack_wr)
					state_nxt <= len_last ? 2'b00 : 2'b10;
			end

			default:
				state_nxt <= 2'b00;
		endcase
	end

	assign ack_rd = (m0_ack & ~dir) | (m1_ack &  dir);
	assign ack_wr = (m0_ack &  dir) | (m1_ack & ~dir);


	// WB transaction
	// --------------

	assign m0_cyc = state[1] & ~(state[0] ^ dir);
	assign m1_cyc = state[1] &  (state[0] ^ dir);

	assign m0_we  =  dir;
	assign m1_we  = ~dir;


	// Data register
	// -------------

	assign data_ce = ack_rd;

	always @(posedge clk)
		if (data_ce)
			data_reg <= dir ? m1_rdata : m0_rdata;

	assign m0_wdata = data_reg;
	assign m1_wdata = data_reg;


	// Address counters
	// ----------------

	always @(posedge clk)
		if (m0_addr_ce)
			m0_addr_i <= m0_addr_ld ? ctl_wdata[A0W-1:0] : (m0_addr_i + 1);

	always @(posedge clk)
		if (m1_addr_ce)
			m1_addr_i <= m1_addr_ld ? ctl_wdata[A1W-1:0] : (m1_addr_i + 1);

	assign m0_addr_ce = m0_addr_ld | ack_wr;
	assign m1_addr_ce = m1_addr_ld | ack_wr;

	assign m0_addr_ld = ctl_do_write & (ctl_addr[1:0] == 2'b10);
	assign m1_addr_ld = ctl_do_write & (ctl_addr[1:0] == 2'b11);

	assign m0_addr = m0_addr_i;
	assign m1_addr = m1_addr_i;


	// Length counter
	// --------------

	always @(posedge clk)
		if (len_ce)
			len <= len_ld ? { 1'b0, ctl_wdata[11:0] } : (len - 1);

	always @(posedge clk)
		if (len_ld)
			dir <= ctl_wdata[14];

	assign len_ce   = len_ld | ack_wr;
	assign len_ld   = ctl_do_write & (ctl_addr[1:0] == 2'b00);
	assign len_last = len[12];


	// Control IF
	// ----------

	always @(posedge clk or posedge rst)
		if (rst) begin
			ctl_do_write <= 1'b0;
			ctl_do_read  <= 1'b0;
			ctl_ack_i    <= 1'b0;
		end else begin
			ctl_do_write <= ~ctl_ack_i & ctl_cyc &  ctl_we;
			ctl_do_read  <= ~ctl_ack_i & ctl_cyc & ~ctl_we & (ctl_addr[1:0] == 2'b00);
			ctl_ack_i    <= ~ctl_ack_i & ctl_cyc;
		end

	assign ctl_ack = ctl_ack_i;

	assign ctl_rdata = {
		{(DW-16){1'b0}},
		(ctl_do_read ? { state[1], dir, 1'b0, len } : 16'h0000)
	};

endmodule // wb_dma
