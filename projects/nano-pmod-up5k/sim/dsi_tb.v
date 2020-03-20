/*
 * dsi_tb.v
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
`timescale 1ns / 100ps

module dsi_tb;

	// Signals
	reg rst = 1'b1;
	reg clk = 1'b0;

	// PHY
	output wire clk_lp;
	output wire clk_hs_p;
	output wire clk_hs_n;
	output wire data_lp;
	output wire data_hs_p;
	output wire data_hs_n;

	// Packet interface
	wire hs_clk_req;
	wire hs_clk_rdy;
	wire hs_clk_sync;

	wire hs_start;
	wire [7:0] hs_data;
	wire hs_last;
	wire hs_ack;

	reg [7:0] cnt;
	reg in_pkt;

	// Setup recording
	initial begin
		$dumpfile("dsi_tb.vcd");
		$dumpvars(0,dsi_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10 clk = !clk;

	// DUT
	nano_dsi_clk dsi_clk_I (
		.clk_lp(clk_lp),
		.clk_hs_p(clk_hs_p),
		.clk_hs_n(clk_hs_n),
		.hs_req(hs_clk_req),
		.hs_rdy(hs_clk_rdy),
		.clk_sync(hs_clk_sync),
		.cfg_hs_prep(8'h10),
		.cfg_hs_zero(8'h10),
		.cfg_hs_trail(8'h10),
		.clk(clk),
		.rst(rst)
	);
	nano_dsi_data dsi_data_I (
		.data_lp(data_lp),
		.data_hs_p(data_hs_p),
		.data_hs_n(data_hs_n),
		.hs_start(hs_start),
		.hs_data(hs_data),
		.hs_last(hs_last),
		.hs_ack(hs_ack),
		.clk_sync(hs_clk_sync),
		.cfg_hs_prep(8'h10),
		.cfg_hs_zero(8'h10),
		.cfg_hs_trail(8'h10),
		.clk(clk),
		.rst(rst)
	);

	// Packet generator
	always @(posedge clk)
		if (rst)
			cnt <= 0;
		else
			cnt <= cnt + (!in_pkt || hs_ack);

	always @(posedge clk)
		if (rst)
			in_pkt <= 1'b0;
		else
			in_pkt <= (in_pkt | hs_start) & ~(hs_last & hs_ack);

	assign hs_clk_req = (cnt != 8'h00);
	assign hs_start   = (cnt == 8'h0f);
	assign hs_data    = cnt;
	assign hs_last    = (cnt == 8'h1f);

endmodule // dsi_tb
