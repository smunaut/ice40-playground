/*
 * soc_bram.v
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

module soc_bram #(
	parameter integer AW = 8,
	parameter INIT_FILE = ""
)(
	input  wire [AW-1:0] addr,
	output reg  [31:0] rdata,
	input  wire [31:0] wdata,
	input  wire [ 3:0] wmsk,
	input  wire we,
	input  wire clk
);

	reg [31:0] mem [0:(1<<AW)-1];

	initial
		if (INIT_FILE != "")
			$readmemh(INIT_FILE, mem);

	always @(posedge clk) begin
		rdata <= mem[addr];
		if (we & ~wmsk[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
		if (we & ~wmsk[1]) mem[addr][15: 8] <= wdata[15: 8];
		if (we & ~wmsk[2]) mem[addr][23:16] <= wdata[23:16];
		if (we & ~wmsk[3]) mem[addr][31:24] <= wdata[31:24];
	end

endmodule // soc_bram
