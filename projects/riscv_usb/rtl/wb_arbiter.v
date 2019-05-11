/*
 * wb_arbiter.v
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

module wb_arbiter #(
	parameter integer N = 3,
	parameter integer DW = 32,
	parameter integer AW = 16,
	parameter integer MW = DW / 8
)(
	/* Slave buses */
	input  wire [(N*AW)-1:0] s_addr,
	output wire [(N*DW)-1:0] s_rdata,
	input  wire [(N*DW)-1:0] s_wdata,
	input  wire [(N*MW)-1:0] s_wmsk,
	input  wire [N-1:0] s_cyc,
	input  wire [N-1:0] s_we,
	output wire [N-1:0] s_ack,

	/* Master bus */
	output reg  [AW-1:0] m_addr,
	input  wire [DW-1:0] m_rdata,
	output reg  [DW-1:0] m_wdata,
	output reg  [MW-1:0] m_wmsk,
	output wire m_cyc,
	output reg  m_we,
	input  wire m_ack,

	/* Clock / Reset */
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	genvar i;

	reg  [AW-1:0] mux_addr;
	reg  [DW-1:0] mux_wdata;
	reg  [MW-1:0] mux_wmsk;

	reg  [N-1:0] sel_nxt;
	reg  [N-1:0] sel;
	reg  busy;
	wire reselect;


	// Muxing
	// ------

	for (i=0; i<N; i=i+1)
	begin
		assign s_rdata[DW*i+:DW] = sel[i] ? m_rdata : { DW{1'b0} };
		assign s_ack[i] = sel[i] ? m_ack : 1'b0;
	end

	always @(*)
	begin : mux
		integer i;

		mux_addr  = { AW{1'b0} };
		mux_wdata = { DW{1'b0} };
		mux_wmsk  = { MW{1'b0} };

		for (i=N-1; i>=0; i=i-1) begin
			mux_addr  = mux_addr  | (sel_nxt[i] ? s_addr[AW*i+:AW]  : { AW{1'b0} });
			mux_wdata = mux_wdata | (sel_nxt[i] ? s_wdata[DW*i+:DW] : { DW{1'b0} });
			mux_wmsk  = mux_wmsk  | (sel_nxt[i] ? s_wmsk[MW*i+:MW]  : { MW{1'b0} });
		end
	end

	always @(posedge clk or posedge rst)
	begin
		if (rst) begin
			m_addr  <= { AW{1'b0} };
			m_wdata <= { DW{1'b0} };
			m_wmsk  <= { MW{1'b0} };
			m_we    <= 1'b0;
		end else if (reselect) begin
			m_addr  <= mux_addr;
			m_wdata <= mux_wdata;
			m_wmsk  <= mux_wmsk;
			m_we    <= |(s_we & sel_nxt);
		end
	end


	// Arbitration
	// -----------

	// Priority encoder for the next master
	always @(*)
	begin : prio
		integer i;

		sel_nxt <= 0;
		for (i=N-1; i>=0; i=i-1)
			if (s_cyc[i] & ~sel[i]) begin
				sel_nxt    <= 0;
				sel_nxt[i] <= 1'b1;
			end
	end

	// When to reselect
	assign reselect = m_ack | ~busy;

	// Register current master (if any)
	always @(posedge clk or posedge rst)
		if (rst) begin
			busy <= 1'b0;
			sel  <= 0;
		end else if (reselect) begin
			busy <= |(s_cyc & ~sel);
			sel  <= sel_nxt;
		end

	assign m_cyc = busy;

endmodule // wb_arb
