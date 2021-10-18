/*
 * dfu_helper.v
 *
 * vim: ts=4 sw=4
 *
 * - Samples the button every 2^SAMP_TW
 *   (or every btn_tick if external ticks are used).
 *
 * - Debounces / flips state when sampled identically 4 times consecutively
 *
 * - Detect long presses if held active for more than 2^LONG_TW
 *
 * - Safety against 'boot' presses: buttons need to be inactive for
 *   2^(LONG_TW-2) before it is "armed"
 *
 * - btn_val is the current 'debounced' value of the button
 *   (possibly already inverted if 'active-low' is set)
 *
 * For application mode:
 *   When released after a long press, triggers bootloader image
 *   When released after a short press, outputs a pulse on btn_press
 *
 * For bootloader mode:
 *   Any button presses triggers reboot to application mode image
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module dfu_helper #(
	parameter integer SAMP_TW = 7,			// Sample button every 128 cycles
	parameter integer LONG_TW = 19,			// Consider long press after 2^19 sampling
	parameter integer BTN_MODE = 3,			// [2] Use btn_tick, [1] Include IO buffer, [0] Invert (active-low)
	parameter integer BOOTLOADER_MODE = 0,	// 0 = For user app, 1 = For bootloader
	parameter BOOT_IMAGE = 2'b01,			// Bootloader image
	parameter USER_IMAGE = 2'b10			// User image
)(
	// External control
	input  wire [1:0] boot_sel,
	input  wire boot_now,

	// Button
	input  wire btn_in,
	input  wire btn_tick,

	// Outputs
	output wire btn_val,
	output reg  btn_press,

	// Clock
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Input stage
	wire btn_raw;
	reg  btn_cur;

	// Sampling
	reg  [SAMP_TW:0] samp_cnt = 0;	// init only needed for sim
	wire samp_now;

	// Debounce
	reg [2:0] debounce = 0;			// init only needed for sim
	reg btn_fall;

	// Long timer
	reg  [LONG_TW:0] long_cnt;
	wire [LONG_TW:0] long_inc;
	wire [LONG_TW:0] long_msk;

	reg  armed;

	// Boot logic
	reg [1:0] wb_sel;
	reg wb_req;
	reg wb_now;


	// Button
	// ------

	// IOB
	generate
		if (BTN_MODE[1])
			SB_IO #(
				.PIN_TYPE(6'b000000),	// Reg input, no output
				.PULLUP(1'b1),
				.IO_STANDARD("SB_LVCMOS")
			) btn_iob_I (
				.PACKAGE_PIN(btn_in),
				.INPUT_CLK  (clk),
				.D_IN_0     (btn_raw)
			);
		else
			assign btn_raw = btn_in;
	endgenerate

	// Invert & Synchronize
	always @(posedge clk)
		btn_cur <= btn_raw ^ BTN_MODE[0];

	// Sampling tick
	always @(posedge clk)
		samp_cnt <= ({ 1'b0, samp_cnt[SAMP_TW-1:0] } + 1) & {(SAMP_TW+1){~samp_cnt[SAMP_TW]}};

	assign samp_now = BTN_MODE[3] ? btn_tick : samp_cnt[SAMP_TW];

	// Debounce
	always @(posedge clk or posedge rst)
		if (rst)
			debounce <= 3'b000;
		else if (samp_now)
			casez ({debounce, btn_cur})
				4'b0zz0: debounce <= 3'b000;
				4'b0001: debounce <= 3'b001;
				4'b0011: debounce <= 3'b010;
				4'b0101: debounce <= 3'b011;
				4'b0111: debounce <= 3'b111;
				4'b1zz1: debounce <= 3'b111;
				4'b1110: debounce <= 3'b110;
				4'b1100: debounce <= 3'b101;
				4'b1010: debounce <= 3'b100;
				4'b1000: debounce <= 3'b000;
				default: debounce <= 3'bxxx;
			endcase

	assign btn_val = debounce[2];

	always @(posedge clk)
		btn_fall <= (debounce == 3'b100) & ~btn_cur & samp_now;


	// Long-press / Arming
	// -------------------

	always @(posedge clk or posedge rst)
		if (rst)
			armed <= 1'b0;
		else
			armed <= armed | long_cnt[LONG_TW-2];


	assign long_inc = { {LONG_TW{1'b0}}, ~long_cnt[LONG_TW] };
	assign long_msk = { (LONG_TW+1){~(armed ^ btn_val)} };

	always @(posedge clk or posedge rst)
		if (rst)
			long_cnt <= 0;
		else if (samp_now)
			long_cnt <= (long_cnt + long_inc) & long_msk;


	// Command logic
	// -------------

	always @(posedge clk or posedge rst)
		if (rst) begin
			wb_sel    <= 2'b00;
			wb_req    <= 1'b0;
			btn_press <= 1'b0;
		end else if (~wb_req) begin
			if (boot_now) begin
				// External boot request
				wb_sel    <= boot_sel;
				wb_req    <= 1'b1;
				btn_press <= 1'b0;
			end else begin
				if (BOOTLOADER_MODE == 1) begin
					// We're in a DFU bootloader, any button press results in
					// boot to application
					wb_sel    <= USER_IMAGE;
					wb_req    <= (armed & btn_fall) | wb_req;
					btn_press <= 1'b0;
				end else begin
					// We're in user application, short press resets the
					// logic, long press triggers DFU reboot
					wb_sel    <= BOOT_IMAGE;
					wb_req    <= (armed & btn_fall &  long_cnt[LONG_TW]) | wb_req;
					btn_press <= (armed & btn_fall & ~long_cnt[LONG_TW]);
				end
			end
		end


	// Boot
	// ----

	// Ensure select bits are set before the boot pulse
	always @(posedge clk or posedge rst)
		if (rst)
			wb_now <= 1'b0;
		else
			wb_now <= wb_req;

	// IP core
	SB_WARMBOOT warmboot (
		.BOOT (wb_now),
		.S0   (wb_sel[0]),
		.S1   (wb_sel[1])
	);

endmodule // dfu_helper
