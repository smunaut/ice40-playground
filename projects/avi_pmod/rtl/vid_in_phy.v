/*
 * vid_in_phy.v
 *
 * vim: ts=4 sw=4
 *
 * Physical layer interface to the Analog Video In PMOD
 * Recovers clock, reset and pixel data
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_in_phy (
	// Pad
	input  wire  [4:0] pad_data,
	input  wire        pad_clk,

	// Output
	output reg   [7:0] vid_data,
	output wire        vid_err,		// Parity error detect
	output wire        vid_clk,
	output wire        vid_rst,

	// Control
	input  wire        active		// Async. When set to 0, force reset
);

	// Signals
	// -------

	// Reset
	reg  [3:0] rst_cnt;
	wire       rst_i;

	// IOB capture
	wire [4:0] vid_data_rise;
	wire [4:0] vid_data_fall;

	// Resync
	reg  [7:0] avip_data;

	// Error
	reg        err_rise;
	reg        err_fall;


	// Clock buffer
	// ------------

	SB_GB_IO #(
		.PIN_TYPE(6'b 0000_01),
		.PULLUP(1'b1),
		.IO_STANDARD("SB_LVCMOS")
	) clk_gb_I (
		.PACKAGE_PIN          (pad_clk),
		.GLOBAL_BUFFER_OUTPUT (vid_clk)
	);


	// Reset
	// -----

	always @(posedge vid_clk or negedge active)
		if (~active)
			rst_cnt <= 4'h8;
		else if (rst_i)
			rst_cnt <= rst_cnt + 1;

	assign rst_i = rst_cnt[3];

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_i),
		.GLOBAL_BUFFER_OUTPUT         (vid_rst)
	);


	// Data capture
	// ------------

	// IOBs (DDR)
	SB_IO #(
		.PIN_TYPE    (6'b0000_00),
		.PULLUP      (1'b0),
		.IO_STANDARD ("SB_LVCMOS")
	) data_iob_I[4:0] (
		.PACKAGE_PIN (pad_data),
		.INPUT_CLK   (vid_clk),
		.D_IN_1      (vid_data_fall),
		.D_IN_0      (vid_data_rise)
	);

	// Internal resync
	always @(posedge vid_clk)
		vid_data <= { vid_data_fall[3:0], vid_data_rise[3:0] };

	// Parity checking
	always @(posedge vid_clk)
		err_rise <= ^vid_data_rise;

	always @(negedge vid_clk)
		err_fall <= ^vid_data_fall;

	assign vid_err = err_rise | err_fall;

endmodule // vid_in_phy
