/*
 * wb_epbuf.v
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

module wb_epbuf #(
	parameter integer AW = 9,
	parameter integer DW = 32
)(
	// Wishbone slave
	input  wire [AW-1:0] wb_addr,
	output wire [DW-1:0] wb_rdata,
	input  wire [DW-1:0] wb_wdata,
	input  wire wb_cyc,
	input  wire wb_we,
	output wire wb_ack,

	// USB EP-Buf master
    output wire [AW-1:0] ep_tx_addr_0,
    output wire [DW-1:0] ep_tx_data_0,
    output wire ep_tx_we_0,

    output wire [AW-1:0] ep_rx_addr_0,
    input  wire [DW-1:0] ep_rx_data_1,
    output wire ep_rx_re_0,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	reg ack_i;

	assign ep_tx_addr_0 = wb_addr;
	assign ep_rx_addr_0 = wb_addr;

	assign ep_tx_data_0 = wb_wdata;
	assign wb_rdata = ep_rx_data_1;

	assign ep_tx_we_0 = wb_cyc & wb_we & ~ack_i;
	assign ep_rx_re_0 = 1'b1;

	assign wb_ack = ack_i;

	always @(posedge clk or posedge rst)
		if (rst)
			ack_i <= 1'b0;
		else
			ack_i <= wb_cyc & ~ack_i;

endmodule // wb_epbuf
