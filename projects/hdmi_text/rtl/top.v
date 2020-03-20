/*
 * top.v
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

module top (
	// HDMI PMOD
	output wire hdmi_clk,
	output wire hdmi_hsync,
	output wire hdmi_vsync,
	output wire hdmi_de,
	output wire hdmi_r,
	output wire hdmi_g,
	output wire hdmi_b,
	output wire hdmi_i,

	// Slave SPI interface
	input  wire slave_mosi,
	output wire slave_miso,
	input  wire slave_cs_n,
	input  wire slave_clk,

	// Clock
	input  wire clk12m_in
);

	// Signals
	// -------

	// Fast Bus
	wire [15:0] fbus_addr;
	wire [15:0] fbus_din;
	wire [15:0] fbus_dout;
	wire fbus_cyc;
	wire fbus_we;
	wire fbus_ack;

	// Slow Bus
	wire [7:0] sb_addr;
	wire [7:0] sb_data;
	wire sb_first;
	wire sb_last;
	wire sb_stb;
	wire [7:0] sb_out;

	// Bridge
	reg [31:0] data;
	reg pending;

	// Clocks / Reset
	wire clk_2x;
	wire clk_1x;
	wire rst;


	// SPI interface
	// -------------

	spi_fast spi_I (
		.spi_mosi(slave_mosi),
		.spi_miso(slave_miso),
		.spi_cs_n(slave_cs_n),
		.spi_clk(slave_clk),
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.last(sb_last),
		.strobe(sb_stb),
		.out(sb_out),
		.clk(clk_1x),
		.rst(rst)
	);


	// Slow -> Fast bus bridge
	// -----------------------

	assign fbus_din  = data[15:0];
	assign fbus_addr = data[31:16];
	assign fbus_cyc  = pending;
	assign fbus_we   = 1'b1;

	always @(posedge clk_1x)
		if (rst)
			pending <= 1'b0;
		else
			pending <= (pending & ~fbus_ack) | (sb_last & sb_stb & |(data[24:22]));

	always @(posedge clk_1x)
		if (sb_stb & ~pending)
			data <= { data[24:0], sb_data };


	// HDMI text mode core
	// -------------------

	hdmi_text_2x #(
		.DW(4)
	) text_I (
		.hdmi_data({hdmi_i, hdmi_b, hdmi_g, hdmi_r}),
		.hdmi_hsync(hdmi_hsync),
		.hdmi_vsync(hdmi_vsync),
		.hdmi_de(hdmi_de),
		.hdmi_clk(hdmi_clk),
		.bus_addr(fbus_addr),
		.bus_din(fbus_din),
		.bus_dout(fbus_dout),
		.bus_cyc(fbus_cyc),
		.bus_we(fbus_we),
		.bus_ack(fbus_ack),
		.clk_1x(clk_1x),
		.clk_2x(clk_2x),
		.rst(rst)
	);


	// Clock / Reset generation
	// ------------------------

	sysmgr sysmgr_I (
		.clk_in(clk12m_in),
		.rst_in(1'b0),
		.clk_2x_out(clk_2x),
		.clk_1x_out(clk_1x),
		.rst_out(rst)
	);

endmodule // top
