/*
 * spi_fast.v
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

module spi_fast (
	// SPI pads
	input  wire spi_mosi,
	output wire spi_miso,
	input  wire spi_cs_n,
	input  wire spi_clk,

	// Interface
	output reg  [7:0] addr,
	output reg  [7:0] data,
	output wire first,
	output wire last,
	output reg  strobe,

	input  wire [7:0] out,

	// Clock / Reset
	input  wire  clk,
	input  wire  rst
);
	// Signals
	// -------

	// Core IF
	wire [7:0] core_out_data;
	wire core_out_stb;
	wire core_out_prestb;

	wire [7:0] core_in_data;
	wire core_in_ack;

	wire csn_state;
	wire csn_rise;
	wire csn_fall;

	// "Simple Bus"
	reg rx_first;
	reg rx_second;
	reg rx_third;
	reg tx_first;

	wire addr_ce;

	reg first_i;
	reg last_i;


	// Core
	// ----

	spi_fast_core core_I (
		.spi_miso(spi_miso),
		.spi_mosi(spi_mosi),
		.spi_clk(spi_clk),
		.spi_cs_n(spi_cs_n),
		.user_out(core_out_data),
		.user_out_stb(core_out_stb),
		.user_out_prestb(core_out_prestb),
		.user_in(core_in_data),
		.user_in_ack(core_in_ack),
		.csn_state(csn_state),
		.csn_rise(csn_rise),
		.csn_fall(csn_fall),
		.clk(clk),
		.rst(rst)
	);


	// Interface to "Simple Bus"
	// -------------------------

	// Track state
	always @(posedge clk)
		tx_first <= (tx_first | csn_state) & ~core_in_ack;

	always @(posedge clk)
	begin
		rx_first  <= (rx_first  | csn_state) & ~core_out_stb;
		rx_second <= (rx_second & ~core_out_stb & ~csn_state) | (rx_first  & core_out_stb);
		rx_third  <= (rx_third  & ~core_out_stb & ~csn_state) | (rx_second & core_out_stb);
	end

	// Status sent as first word
	assign core_in_data = tx_first ? out : 8'h00;

	// Address register
	always @(posedge clk)
		if (addr_ce)
			addr <= core_out_data;

	assign addr_ce = core_out_stb & rx_first;

	// Data register
		// (this is needed because we need to be able to hold the data until
		//  we know if it's the last or not ...)
	always @(posedge clk)
		if (core_out_prestb | csn_rise)
			data <= core_out_data;

	// External strobes
	always @(posedge clk)
	begin
		first_i <= (first_i & ~core_out_stb & ~csn_rise) | rx_third;
		last_i  <= (last_i  & ~core_out_stb) | csn_rise;
		strobe  <= csn_rise | (core_out_stb & ~rx_first & ~rx_second);
	end

	assign first = first_i;
	assign last  = last_i;

endmodule // spi_fast
