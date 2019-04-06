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
	output wire [AW-1:0] m_addr,
	input  wire [DW-1:0] m_rdata,
	output wire [DW-1:0] m_wdata,
	output wire [MW-1:0] m_wmsk,
	output wire m_cyc,
	output wire m_we,
	input  wire m_ack,

	/* Clock / Reset */
	input  wire clk,
	input  wire rst
);

	localparam integer SW = $clog2(N);


	// Signals
	// -------

	genvar i;

	reg [SW-1:0] sel;


	// Muxing
	// ------

	assign m_addr  = s_addr[AW*sel+:AW];
	assign m_wdata = s_wdata[DW*sel+:DW];
	assign m_wmsk  = s_wmsk[MW*sel+:MW];
	assign m_we    = s_we[sel];

	for (i=0; i<N; i=i+1)
	begin
		assign s_rdata[DW*i+:DW] = ((i == sel) & s_cyc[i]) ? m_rdata : { DW{1'b0} };
		assign s_ack[i] = ((i == sel) & s_cyc[i]) ? m_ack : 1'b0;
	end


	// Arbitration
	// -----------

	assign m_cyc = |s_cyc;

	always @(*)
	begin : prio
		integer i;
		sel <= 0;
		for (i=N-1; i>=0; i=i-1)
			if (s_cyc[i] == 1'b1)
				sel <= i;
	end

endmodule // wb_arb
