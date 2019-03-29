/*
 * hdmi_text_2x.v
 *
 * vim: ts=4 sw=4
 *
 * HDMI text generator core top level running in 1:2 mode
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

module hdmi_text_2x #(
	parameter integer DW = 4
)(
	// HDMI pads
	output wire [DW-1:0] hdmi_data,
	output wire hdmi_hsync,
	output wire hdmi_vsync,
	output wire hdmi_de,
	output wire hdmi_clk,

	// Bus interface
	input  wire [15:0] bus_addr,
	input  wire [15:0] bus_din,
	output wire [15:0] bus_dout,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// Clock / Reset
	input  wire clk_1x,
	input  wire clk_2x,
	input  wire rst
);

	// Signals
	// -------

	// Timing generator
	wire tg_hsync;
	wire tg_vsync;
	wire tg_active;
	wire tg_h_first;
	wire tg_h_last;
	wire tg_v_first;
	wire tg_v_last;

	// Text generator pixels
	wire [15:0] txt_data0;
	wire [15:0] txt_data1;

	// Video output
	wire vo_hsync;
	wire vo_vsync;
	wire vo_active;
	reg  vo_toggle = 1'b0;
	reg  [ 3:0] vo_data0;
	reg  [ 3:0] vo_data1;


	// Timing generation
	// -----------------

	vid_tgen tgen_I (
		.vid_hsync(tg_hsync),
		.vid_vsync(tg_vsync),
		.vid_active(tg_active),
		.vid_h_first(tg_h_first),
		.vid_h_last(tg_h_last),
		.vid_v_first(tg_v_first),
		.vid_v_last(tg_v_last),
		.clk(clk_1x),
		.rst(rst)
	);


	// Video text mode
	// ---------------

	vid_text text_I (
		.vid_active_0(tg_active),
		.vid_h_first_0(tg_h_first),
		.vid_h_last_0(tg_h_last),
		.vid_v_first_0(tg_v_first),
		.vid_v_last_0(tg_v_last),
		.vid_pix0_11(txt_data0),
		.vid_pix1_11(txt_data1),
		.bus_addr(bus_addr),
		.bus_din(bus_din),
		.bus_dout(bus_dout),
		.bus_cyc(bus_cyc),
		.bus_we(bus_we),
		.bus_ack(bus_ack),
		.clk(clk_1x),
		.rst(rst)
	);


	// Video output
	// ------------

	// Align required sync signals
	delay_bit #(12) dly_hsync  ( .d(tg_hsync),  .q(vo_hsync),  .clk(clk_1x) );
	delay_bit #(12) dly_vsync  ( .d(tg_vsync),  .q(vo_vsync),  .clk(clk_1x) );
	delay_bit #(12) dly_active ( .d(tg_active), .q(vo_active), .clk(clk_1x) );

	// Pixel color map
	always @(posedge clk_1x)
	begin
		vo_toggle <= ~rst & (vo_toggle ^ (tg_v_first & tg_h_first));
		vo_data0  <= vo_toggle ? txt_data0[7:4] : txt_data0[3:0];
		vo_data1  <= vo_toggle ? txt_data1[7:4] : txt_data1[3:0];
	end


	// PHY
	// ---

	hdmi_phy_2x #(
		.DW(DW)
	) phy_I (
		.hdmi_data(hdmi_data),
		.hdmi_hsync(hdmi_hsync),
		.hdmi_vsync(hdmi_vsync),
		.hdmi_de(hdmi_de),
		.hdmi_clk(hdmi_clk),
		.in_data0(vo_data0),
		.in_data1(vo_data1),
		.in_hsync(vo_hsync),
		.in_vsync(vo_vsync),
		.in_de(vo_active),
		.clk_1x(clk_1x),
		.clk_2x(clk_2x)
	);

endmodule // hdmi_text_2x
