/*
 * hdmi_phy_2x.v
 *
 * vim: ts=4 sw=4
 *
 * HDMI PHY using DDR output to push 2 pixels at once allowing FPGA code
 * to run at half the pixel clock.
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

module hdmi_phy_2x #(
	parameter integer DW = 4
)(
	// HDMI pads
	output wire [DW-1:0] hdmi_data,
	output wire hdmi_hsync,
	output wire hdmi_vsync,
	output wire hdmi_de,
	output wire hdmi_clk,

	// Input from fabric
	input  wire [DW-1:0] in_data0,
	input  wire [DW-1:0] in_data1,
	input  wire in_hsync,
	input  wire in_vsync,
	input  wire in_de,

	// Clocks
	input  wire clk_1x,
	input  wire clk_2x
);
	reg [DW-1:0] in_data1d;

	// Delay second pixel (falling edge one)
	always @(posedge clk_1x)
		in_data1d <= in_data1;

	// Data bits
	SB_IO #(
		.PIN_TYPE    (6'b0100_11),
		.PULLUP      (1'b0),
		.NEG_TRIGGER (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_hdmi_data_I[DW-1:0] (
		.PACKAGE_PIN (hdmi_data),
		.OUTPUT_CLK  (clk_1x),
		.D_OUT_0     (in_data0),
		.D_OUT_1     (in_data1d)
	);

	// H-Sync / V-Sync / DE
	SB_IO #(
		.PIN_TYPE    (6'b0101_11),
		.PULLUP      (1'b0),
		.NEG_TRIGGER (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_hdmi_ctrl_I (
		.PACKAGE_PIN ({hdmi_hsync, hdmi_vsync, hdmi_de}),
		.OUTPUT_CLK  (clk_1x),
		.D_OUT_0     ({in_hsync,   in_vsync,   in_de})
	);

	// Clock
	SB_IO #(
		.PIN_TYPE    (6'b0100_11),
		.PULLUP      (1'b0),
		.NEG_TRIGGER (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_hdmi_clk_I (
		.PACKAGE_PIN (hdmi_clk),
		.OUTPUT_CLK  (clk_2x),
		.D_OUT_0     (1'b0),
		.D_OUT_1     (1'b1)
	);

endmodule // hdmi_phy_2x
