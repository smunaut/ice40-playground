/*
 * wb_spram.v
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

module wb_spram #(
	parameter integer W = 32
)(
	input  wire [13:0] addr,
	output wire [W-1:0] rdata,
	input  wire [W-1:0] wdata,
	input  wire [(W/8)-1:0] wmsk,
	input  wire cyc,
	input  wire we,
	output wire ack,
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	genvar i;

	wire we_i;
	reg  ack_i;


	// Glue
	// ----

	assign we_i = cyc & we & ~ack_i;

	always @(posedge clk or posedge rst)
		if (rst)
			ack_i <= 1'b0;
		else
			ack_i <= cyc & ~ack_i;

	assign ack = ack_i;


	// SPRAMs
	// ------

	for (i=0; i<W; i=i+16)
	begin

		wire [3:0] wmsk_i = { wmsk[i/8+1], wmsk[i/8+1], wmsk[i/8], wmsk[i/8] };

		SB_SPRAM256KA spram_I (
			.DATAIN(wdata[i+:16]),
			.ADDRESS(addr),
			.MASKWREN(wmsk_i),
			.WREN(we_i),
			.CHIPSELECT(1'b1),
			.CLOCK(clk),
			.STANDBY(1'b0),
			.SLEEP(1'b0),
			.POWEROFF(1'b1),
			.DATAOUT(rdata[i+:16])
		);

	end

endmodule // wb_spram
