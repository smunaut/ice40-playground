/*
 * hdmi_phy_4x.v
 *
 * vim: ts=4 sw=4
 *
 * HDMI PHY using 4x serdes to push 4 pixels at once allowing FPGA code
 * to run at a quarter of the pixel clock.
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

module hdmi_phy_4x #(
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
	input  wire [DW-1:0] in_data2,
	input  wire [DW-1:0] in_data3,
	input  wire in_hsync,
	input  wire in_vsync,
	input  wire in_de,

	// Clocks
	input  wire clk_1x,
	input  wire clk_4x,
	input  wire clk_sync
);

	genvar i;


	// Clock
	// -----

	SB_IO #(
		.PIN_TYPE(6'b0100_11)
	) io_clk_I (
		.PACKAGE_PIN(hdmi_clk),
		.D_OUT_0(1'b0),
		.D_OUT_1(1'b1),
		.OUTPUT_CLK(clk_4x)
	);


	// Control signals
	// ---------------

	wire [11:0] ctrl_d;
	wire [ 2:0] ctrl_iob_o;
	wire [ 2:0] ctrl_pad;

	assign ctrl_d = {
		{ 4{in_hsync} },
		{ 4{in_vsync} },
		{ 4{in_de}    }
	};

	generate
		for (i=0; i<3; i=i+1)
		begin
			wire dummy;

			ice40_oserdes #(
				.MODE("DATA"),
				.SERDES_GRP(1024 + (i<<4))
			) oserdes_ctrl_I (
				.d(ctrl_d[4*i+:4]),
				.q({dummy, ctrl_iob_o[i]}),
				.sync(clk_sync),
				.clk_1x(clk_1x),
				.clk_4x(clk_4x)
			);
		end
	endgenerate

	SB_IO #(
		.PIN_TYPE(6'b0101_11)
	) io_ctrl_I[2:0] (
		.PACKAGE_PIN(ctrl_pad),
		.D_OUT_0(ctrl_iob_o),
		.OUTPUT_CLK(clk_4x)
	);

	assign hdmi_hsync = ctrl_pad[2];
	assign hdmi_vsync = ctrl_pad[1];
	assign hdmi_de    = ctrl_pad[0];


	// Data signals
	// ------------

	wire [4*DW-1:0] data_d;
	wire [  DW-1:0] data_iob_o;
	wire [  DW-1:0] data_pad;

	generate
		for (i=0; i<DW; i=i+1)
		begin
			wire dummy;

			assign data_d[4*i+:4] = {
				in_data0[i],
				in_data1[i],
				in_data2[i],
				in_data3[i]
			};

			ice40_oserdes #(
				.MODE("DATA"),
				.SERDES_GRP(1024 + 64 + (i<<4))
			) oserdes_data_I (
				.d(data_d[4*i+:4]),
				.q({dummy, data_iob_o[i]}),
				.sync(clk_sync),
				.clk_1x(clk_1x),
				.clk_4x(clk_4x)
			);
		end
	endgenerate

	SB_IO #(
		.PIN_TYPE(6'b 0101_11)
	) io_data_I[DW-1:0] (
		.PACKAGE_PIN(data_pad),
		.D_OUT_0(data_iob_o),
		.OUTPUT_CLK(clk_4x)
	);

	assign hdmi_data = data_pad;

endmodule
