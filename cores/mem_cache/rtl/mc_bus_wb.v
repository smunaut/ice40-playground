/*
 * mc_bus_wb.v
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

module mc_bus_wb #(
	parameter integer ADDR_WIDTH = 24,

	// auto
	parameter integer BL = ADDR_WIDTH - 1
)(
	// Wishbone bus
	input  wire [BL:0] wb_addr,
	input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
	output wire [31:0] wb_rdata,
	input  wire        wb_cyc,
	input  wire        wb_we,
	output wire        wb_ack,

	// Request output
	output wire [BL:0] req_addr_pre,	// 1 cycle early

	output wire        req_valid,

	output wire        req_write,
	output wire [31:0] req_wdata,
	output wire [ 3:0] req_wmsk,

	// Response input
	input  wire        resp_ack,
	input  wire        resp_nak,
	input  wire [31:0] resp_rdata,

	// Common
	input  wire clk,
	input  wire rst
);
	// Control path
	reg pending;
	reg new;

	always @(posedge clk or posedge rst)
		if (rst)
			pending <= 1'b0;
		else
			pending <= (pending | wb_cyc) & ~resp_ack;

	always @(posedge clk)
		new <= wb_cyc & ~pending;

	assign req_addr_pre = wb_addr;
	assign req_valid = resp_nak | new;

	assign wb_ack = resp_ack;

	// Write path
	assign req_write = wb_we;
	assign req_wdata = wb_wdata;
	assign req_wmsk  = wb_wmsk;

	// Read path
	assign wb_rdata  = resp_rdata;

endmodule
