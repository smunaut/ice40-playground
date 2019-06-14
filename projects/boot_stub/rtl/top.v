/*
 * top.v
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
 *
 * vim: ts=4 sw=4
 */

`default_nettype none

module top (
	// Button
	input  wire btn,

	// LED
	output wire ledr,
	output wire ledg,

	output wire [2:0] rgb,

	// USB
	output wire usb_dp,
	output wire usb_dn,
	output wire usb_pu,

	// Clock
	input  wire clk_in
);

	// FSM
	// ---

	localparam
		ST_START	= 0,
		ST_WAIT		= 1,
		ST_SEL		= 2,
		ST_SEL_WAIT = 3,
		ST_BOOT		= 4;


	// Signals
	// -------

	// Button input
	wire btn_iob;
	wire btn_v;
	wire btn_r;
	wire btn_f;

	// FSM
	reg  [2:0] state_nxt;
	reg  [2:0] state;

	// Boot selector
	wire boot_now;
	reg  [1:0] boot_sel;

	// Timer/Counter
	reg  [23:0] timer;
	wire timer_tick;
	wire timer_rst;

	// LED
	reg [3:0] dim;
	wire [2:0] rgb_pwm;

	// Clock / Reset
	wire clk;
	wire rst;


	// Button
	// ------

	SB_IO #(
		.PIN_TYPE(6'b000000),
		.PULLUP(1'b1),
		.IO_STANDARD("SB_LVCMOS")
	) btn_iob_I (
		.PACKAGE_PIN(btn),
		.INPUT_CLK(clk),
		.D_IN_0(btn_iob)
	);

	glitch_filter #(
		.L(4),
	) btn_flt_I (
		.pin_iob_reg(btn_iob),
		.cond(1'b1),
		.val(btn_v),
		.rise(btn_r),
		.fall(btn_f),
		.clk(clk),
		.rst(1'b0)	// Ensure the glitch filter has settled
					// before logic here engages
	);


	// State machine
	// -------------

	// Next state logic
	always @(*)
	begin
		// Default is to stay put
		state_nxt <= state;

		// Main case
		case (state)
			ST_START:
				// Check for immediate boot
				state_nxt <= btn_v ? ST_BOOT : ST_WAIT;

			ST_WAIT:
				// Wait for first release
				if (btn_v == 1'b1)
					state_nxt <= ST_SEL;

			ST_SEL:
				// If button press, temporarily disable it
				if (btn_f)
					state_nxt <= ST_SEL_WAIT;

				// Or wait for timeout
				else if (timer_tick)
					state_nxt <= ST_BOOT;

			ST_SEL_WAIT:
				// Wait for button to re-arm
				if (timer_tick)
					state_nxt <= ST_SEL;

			ST_BOOT:
				// Nothing to do ... will reconfigure shortly
				state_nxt <= state;
		endcase
	end

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			state <= ST_START;
		else
			state <= state_nxt;


	// Timer
	// -----

	always @(posedge clk)
		if (timer_rst)
			timer <= 24'h000000;
		else
			timer <= timer + 1;

	assign timer_rst  = (btn_v == 1'b0) | timer_tick;
	assign timer_tick = (state == ST_SEL_WAIT) ? timer[15] : timer[23];


	// Warm Boot
	// ---------

	// Boot command
	assign boot_now = (state == ST_BOOT);

	// Image select
	always @(posedge clk or posedge rst)
	begin
		if (rst)
			boot_sel <= 2'b10;	// App 1 Image by default
		else if (state == ST_WAIT)
			boot_sel <= 2'b01;	// DFU Image if in select mode
		else if (state == ST_SEL)
			boot_sel <= boot_sel + btn_f;
	end

	// IP
	SB_WARMBOOT warmboot (
		.BOOT(boot_now),
		.S0(boot_sel[0]),
		.S1(boot_sel[1])
	);


	// LED
	// ---

	assign rgb_pwm[0] = dim[3] & ~boot_now & boot_sel[0];
	assign rgb_pwm[1] = dim[3] &  boot_now;
	assign rgb_pwm[2] = dim[3] & ~boot_now & boot_sel[1];

	assign ledr = ~boot_sel[0];
	assign ledg = ~boot_sel[1];

	// Dimming
	always @(posedge clk)
		if (rst)
			dim <= 4'h0;
		else
			dim <= dim[3] ? 4'h0 : (dim + 1);

	// Driver
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_drv_I (
		.RGBLEDEN(1'b1),
		.RGB0PWM(rgb_pwm[0]),
		.RGB1PWM(rgb_pwm[1]),
		.RGB2PWM(rgb_pwm[2]),
		.CURREN(1'b1),
		.RGB0(rgb[0]),
		.RGB1(rgb[1]),
		.RGB2(rgb[2])
	);


	// Dummy USB
	// ---------
	// (to avoid pullups triggering detection)

	SB_IO #(
		.PIN_TYPE(6'b101000),
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) usb[2:0] (
		.PACKAGE_PIN({usb_dp, usb_dn, usb_pu}),
		.OUTPUT_ENABLE(1'b0),
		.D_OUT_0(1'b0)
	);


	// Clock / Reset
	// -------------

	reg [7:0] cnt_reset;

	SB_GB clk_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(clk_in),
		.GLOBAL_BUFFER_OUTPUT(clk)
	);

	assign rst = ~cnt_reset[7];

	always @(posedge clk)
		if (cnt_reset[7] == 1'b0)
			cnt_reset <= cnt_reset + 1;

endmodule // top
