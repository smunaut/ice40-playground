/*
 * xclk_wb.v
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

module xclk_wb #(
	parameter integer DW = 16,
	parameter integer AW = 16
)(
	// Slave bus interface
	input  wire [AW-1:0] s_addr,
	input  wire [DW-1:0] s_wdata,
	output reg  [DW-1:0] s_rdata,
	input  wire s_cyc,
	output wire s_ack,
	input  wire s_we,
	input  wire s_clk,

	// Master bus interface
	output wire [AW-1:0] m_addr,
	output wire [DW-1:0] m_wdata,
	input  wire [DW-1:0] m_rdata,
	output wire m_cyc,
	input  wire m_ack,
	output wire m_we,
	input  wire m_clk,

	// Reset
	input  wire rst
);

	// Signals
	// -------

	reg  s_cyc_d;
	reg  m_cyc_i;

	wire s_req_i;
	wire m_req_i;

	wire s_ack_i;
	reg  s_ack_d;
	reg  m_ack_i;

	reg [DW-1:0] m_rdata_i;


	// Data and address
	// ----------------

		// These will have settled down for some time while we pass around
		// the handshake signals, so we can just connect them
		// Ideally we'd still need a maxdelay constraint between clock domains

	assign m_addr = s_addr;
	assign m_wdata  = s_wdata;
	assign m_we   = s_we;

		// Still need to capture data during ack
	always @(posedge m_clk)
		if (m_ack)
			m_rdata_i <= m_rdata;

		// ... and ensure its zero cycle-accurately
	always @(posedge s_clk)
		if (s_ack_i || ~s_cyc)
			s_rdata <= 0;
		else
			s_rdata <= m_rdata_i;


	// Handshake
	// ---------

	always @(posedge s_clk)
	begin
		s_cyc_d <= s_cyc;
		s_ack_d <= s_ack_i;
	end

	assign s_req_i = s_cyc & (~s_cyc_d | s_ack_d);

	xclk_strobe xclk_req (
		.in_stb(s_req_i),
		.in_clk(s_clk),
		.out_stb(m_req_i),
		.out_clk(m_clk),
		.rst(rst)
	);

	always @(posedge m_clk or posedge rst)
		if (rst)
			m_cyc_i <= 1'b0;
		else
			m_cyc_i <= (m_cyc_i | m_req_i) & ~m_ack;

	assign m_cyc = m_cyc_i;

	xclk_strobe xclk_ack (
		.in_stb(m_ack),
		.in_clk(m_clk),
		.out_stb(s_ack_i),
		.out_clk(s_clk),
		.rst(rst)
	);

	assign s_ack = s_ack_i;

endmodule
