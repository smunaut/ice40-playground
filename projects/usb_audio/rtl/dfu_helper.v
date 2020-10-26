/*
 * dfu_helper.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module dfu_helper #(
	parameter integer TIMER_WIDTH = 24,
	parameter integer BTN_MODE = 3,		// [2] Use btn_tick, [1] Include IO buffer, [0] Invert (active-low)
	parameter integer DFU_MODE = 0		// 0 = For user app, 1 = For bootloader
)(
	// External control
	input  wire [1:0] boot_sel,
	input  wire boot_now,

	// Button
	input  wire btn_pad,
	input  wire btn_tick,

	// Outputs
	output wire btn_val,
	output reg  rst_req,

	// Clock
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Button
	wire btn_iob;
	wire btn_v;
	wire btn_r;
	wire btn_f;

	// Timer and arming logic
	reg armed;
	reg [TIMER_WIDTH-1:0] timer;
	(* keep="true" *) wire timer_act;

	// Boot logic
	reg [1:0] wb_sel;
	reg wb_req;
	reg wb_now;


	// Button logic
	// ------------

	// IOB
	generate
		if (BTN_MODE[1])
			SB_IO #(
				.PIN_TYPE(6'b000000),	// Reg input, no output
				.PULLUP(1'b1),
				.IO_STANDARD("SB_LVCMOS")
			) btn_iob_I (
				.PACKAGE_PIN(btn_pad),
				.INPUT_CLK  (clk),
				.D_IN_0     (btn_iob)
			);
		else
			assign btn_iob = btn_pad;
	endgenerate

	// Deglitch
	glitch_filter #(
		.L(BTN_MODE[2] ? 2 : 4),
		.RST_VAL(BTN_MODE[0]),
		.WITH_SYNCHRONIZER(1),
		.WITH_SAMP_COND(BTN_MODE[2])
	) btn_flt_I (
		.in       (btn_iob ^ BTN_MODE[0]),
		.samp_cond(btn_tick),
		.val      (btn_v),
		.rise     (btn_r),
		.fall     (btn_f),
		.clk      (clk),
`ifdef SIM
		.rst      (rst)
`else
		// Don't reset so we let the filter settle before
		// the rest of the logic engages
		.rst      (1'b0)
`endif
	);

	assign btn_val = btn_v;


	// Arming & Timer
	// --------------

	assign timer_act = btn_v ^ armed;

	always @(posedge clk or posedge rst)
		if (rst)
			armed <= 1'b0;
		else
			armed <= armed | timer[TIMER_WIDTH-2];

	always @(posedge clk or posedge rst)
		if (rst)
			timer <= 0;
		else
			timer <= timer_act ? { TIMER_WIDTH{1'b0} } : (timer + { { (TIMER_WIDTH-1){1'b0} }, ~timer[TIMER_WIDTH-1] });


	// Boot Logic
	// ----------

	// Decision
	always @(posedge clk or posedge rst)
		if (rst) begin
			wb_sel  <= 2'b00;
			wb_req  <= 1'b0;
			rst_req <= 1'b0;
		end else if (~wb_req) begin
			if (boot_now) begin
				// External boot request
				wb_sel  <= boot_sel;
				wb_req  <= 1'b1;
				rst_req <= 1'b0;
			end else begin
				if (DFU_MODE == 1) begin
					// We're in a DFU bootloader, any button press results in
					// boot to application
					wb_sel  <= 2'b10;
					wb_req  <= wb_now | (armed & btn_f);
					rst_req <= 1'b0;
				end else begin
					// We're in user application, short press resets the
					// logic, long press triggers DFU reboot
					wb_sel  <= 2'b01;
					wb_req  <= wb_now  | (armed & btn_f &  timer[TIMER_WIDTH-1]);
					rst_req <= rst_req | (armed & btn_f & ~timer[TIMER_WIDTH-1]);
				end
			end
		end

	// Ensure select bits are set before the boot pulse
	always @(posedge clk or posedge rst)
		if (rst)
			wb_now <= 1'b0;
		else
			wb_now <= wb_req;

	// IP core
	SB_WARMBOOT warmboot (
		.BOOT(wb_now),
		.S0(wb_sel[0]),
		.S1(wb_sel[1])
	);

endmodule // dfu_helper
