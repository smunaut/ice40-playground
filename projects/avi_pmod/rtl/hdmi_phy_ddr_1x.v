/*
 * hdmi_phy_ddr_1x.v
 *
 * vim: ts=4 sw=4
 *
 * Simple HDMI DDR PHY, registering all signals in IO
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module hdmi_phy_ddr_1x #(
	parameter integer DW = 12,
	parameter         EDGE = 1'b0,

	// auto-set
	parameter integer EL =   DW - 1,
	parameter integer IL = 2*DW - 1
)(
	// HDMI pads
	output wire [EL:0] hdmi_data,
	output wire        hdmi_hsync,
	output wire        hdmi_vsync,
	output wire        hdmi_de,
	output wire        hdmi_clk,

	// Input from fabric
	input  wire [IL:0] in_data,
	input  wire        in_hsync,
	input  wire        in_vsync,
	input  wire        in_de,

	// Clock
	input  wire clk
);

	// Data bits
	SB_IO #(
		.PIN_TYPE    (6'b0100_11),
		.PULLUP      (1'b0),
		.NEG_TRIGGER (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_hdmi_data_I[DW-1:0] (
		.PACKAGE_PIN (hdmi_data),
		.OUTPUT_CLK  (clk),
		.D_OUT_1     (in_data[  DW-1: 0]),
		.D_OUT_0     (in_data[2*DW-1:DW])
	);

	// H-Sync / V-Sync / DE
	SB_IO #(
		.PIN_TYPE    (6'b0100_11),
		.PULLUP      (1'b0),
		.NEG_TRIGGER (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) iob_hdmi_ctrl_I[2:0] (
		.PACKAGE_PIN ({hdmi_hsync, hdmi_vsync, hdmi_de}),
		.OUTPUT_CLK  (clk),
		.D_OUT_1     ({in_hsync,   in_vsync,   in_de}),
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
		.OUTPUT_CLK  (clk),
		.D_OUT_1     ( EDGE),
		.D_OUT_0     (~EDGE)
	);

endmodule // hdmi_phy_ddr_1x
