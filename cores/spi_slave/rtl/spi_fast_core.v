/*
 * spi_fast_core.v
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

module spi_fast_core (
	// SPI interface
	output wire spi_miso,
	input  wire spi_mosi,
	input  wire spi_clk,
	input  wire spi_cs_n,

	// User interface
	output wire [7:0] user_out,
	output reg  user_out_stb,
	output wire user_out_prestb,

	input  wire [7:0] user_in,
	output reg  user_in_ack,

	output wire csn_state,
	output wire csn_rise,
	output wire csn_fall,

	input  wire clk,
	input  wire rst
);
	// IOs
	wire spi_clk_buf;
	wire spi_mosi_in;
	wire spi_miso_out;
	wire spi_miso_oe;

	// SPI clock domain
	reg  [3:0] bit_cnt;
	wire bit_cnt_last;

	wire [7:0] shift_in;
	wire [7:0] shift_reg;

	wire [7:0] save_in;
	wire [7:0] save_reg;

	reg xfer_toggle = 1'b0;	// init only for simulation

	reg  spi_miso_mask;

	// User clock domain
	wire [1:0] xfer_sync;
	wire xfer_now;

	wire csn_cap_i;
	wire csn_state_i;
	wire csn_rise_i;
	wire csn_fall_i;

	wire [7:0] cap_reg;
	wire [7:0] out_reg;

	wire cap_ce;
	wire out_ce;


	// SPI clock domain
	// ----------------

	// Buffer SPI clock (X19/Y0 is used by PLL out :/)
	(* BEL="X13/Y0/gb" *) SB_GB spi_clk_gb_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(spi_clk),
		.GLOBAL_BUFFER_OUTPUT(spi_clk_buf)
	);

	// MOSI IOB
	SB_IO #(
		.PIN_TYPE(6'b000001),
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) spi_mosi_iob_I (
		.PACKAGE_PIN(spi_mosi),
		.D_IN_0(spi_mosi_in)
	);

	// MISO IOB
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) spi_miso_iob_I (
		.PACKAGE_PIN(spi_miso),
		.OUTPUT_ENABLE(spi_miso_oe),
		.D_OUT_0(spi_miso_out)
	);

	// Bit counter
	always @(posedge spi_clk_buf or posedge spi_cs_n)
		if (spi_cs_n)
			bit_cnt <= 4'h1;
		else
			bit_cnt <= { 1'b0, bit_cnt[2:0] } + 1;

	assign bit_cnt_last = bit_cnt[3];

	// Shift register
	assign shift_in = bit_cnt_last ? out_reg : { shift_reg[6:0], spi_mosi_in };

	spi_fast_reg8 #(
		.BEL("X21/Y1")
	) shift_I (
		.d(shift_in),
		.q(shift_reg),
		.ce(1'b1),
		.clk(spi_clk_buf)
	);

	// Save register
	assign save_in = { shift_reg[6:0], spi_mosi_in };

	spi_fast_reg8 #(
		.BEL("X22/Y1")
	) save_I (
		.d(save_in),
		.q(save_reg),
		.ce(bit_cnt_last),
		.clk(spi_clk_buf)
	);

	// Transfer Toggle register
	always @(posedge spi_clk_buf)
		xfer_toggle <= xfer_toggle ^ bit_cnt_last;

	// Output
	assign spi_miso_oe = ~spi_cs_n;

	(* dont_touch="true", BEL="X21/Y2/lc7" *) SB_LUT4 #(
		.LUT_INIT(16'h0008)
	) miso_mux_I (
		.I0(shift_reg[7]),
		.I1(spi_miso_mask),
		.I2(1'b0),
		.I3(1'b0),
		.O(spi_miso_out)
	);

	always @(posedge spi_clk_buf or posedge spi_cs_n)
		if (spi_cs_n)
			spi_miso_mask <= 1'b0;
		else
			spi_miso_mask <= spi_miso_mask | bit_cnt_last;


	// User clock domain
	// -----------------

	// Transfer Toggle synchronizer
	(* dont_touch="true", BEL="X21/Y2/lc0" *) SB_DFF dff_xt_0_I (
		.D(xfer_toggle),
		.Q(xfer_sync[0]),
		.C(clk)
	);

	(* dont_touch="true", BEL="X21/Y2/lc1" *) SB_DFF dff_xt_1_I (
		.D(xfer_sync[0]),
		.Q(xfer_sync[1]),
		.C(clk)
	);

	(* dont_touch="true", BEL="X21/Y2/lc2" *) SB_DFF dff_xt_n_I (
		.D(xfer_sync[0] ^ xfer_sync[1]),
		.Q(xfer_now),
		.C(clk)
	);

	// Chip Select synchronizer and edge detection
	(* dont_touch="true", BEL="X21/Y2/lc3" *) SB_DFF dff_cs_c_I (
		.D(spi_cs_n),
		.Q(csn_cap_i),
		.C(clk)
	);

	(* dont_touch="true", BEL="X21/Y2/lc4" *) SB_DFF dff_cs_s_I (
		.D(csn_cap_i),
		.Q(csn_state_i),
		.C(clk)
	);

	(* dont_touch="true", BEL="X21/Y2/lc5" *) SB_DFF dff_cs_r_I (
		.D(~csn_state & csn_cap_i),
		.Q(csn_rise_i),
		.C(clk)
	);

	(* dont_touch="true", BEL="X21/Y2/lc6" *) SB_DFF dff_cs_f_I (
		.D(csn_state & ~csn_cap_i),
		.Q(csn_fall_i),
		.C(clk)
	);

	// Input Capture register
	spi_fast_reg8 #(
		.BEL("X23/Y1")
	) in_cap_I (
		.d(save_reg),
		.q(cap_reg),
		.ce(cap_ce),
		.clk(clk)
	);

	// Output Cross register
	spi_fast_reg8 #(
		.BEL("X20/Y1")
	) out_cross_I (
		.d(user_in),
		.q(out_reg),
		.ce(out_ce),
		.clk(clk)
	);

	// Control
		// Capture & Send to user
	assign cap_ce = xfer_now;

	always @(posedge clk)
		user_out_stb <= xfer_now;

	assign user_out_prestb = xfer_now;

		// Save user data and send to SPI
	assign out_ce = xfer_now | csn_fall_i;

	always @(posedge clk)
		user_in_ack <= xfer_now | csn_fall_i;

	// Send CS_n status to user
	assign csn_state = csn_state_i;
	assign csn_rise  = csn_rise_i;
	assign csn_fall  = csn_fall_i;

	// Send data to user
	assign user_out = cap_reg;

endmodule // spi_fast_core


module spi_fast_reg8 #(
	parameter BEL = "X0/Y0"
)(
	input  wire [7:0] d,
	output wire [7:0] q,
	input  wire ce,
	input wire clk
);

	(* dont_touch="true", BEL={BEL, "/lc0"} *) SB_DFFE dffe_0 (
		.D(d[0]),
		.Q(q[0]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc1"} *) SB_DFFE dffe_1 (
		.D(d[1]),
		.Q(q[1]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc2"} *) SB_DFFE dffe_2 (
		.D(d[2]),
		.Q(q[2]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc3"} *) SB_DFFE dffe_3 (
		.D(d[3]),
		.Q(q[3]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc4"} *) SB_DFFE dffe_4 (
		.D(d[4]),
		.Q(q[4]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc5"} *) SB_DFFE dffe_5 (
		.D(d[5]),
		.Q(q[5]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc6"} *) SB_DFFE dffe_6 (
		.D(d[6]),
		.Q(q[6]),
		.E(ce),
		.C(clk)
	);

	(* dont_touch="true", BEL={BEL, "/lc7"} *) SB_DFFE dffe_7 (
		.D(d[7]),
		.Q(q[7]),
		.E(ce),
		.C(clk)
	);

endmodule // spi_fast_reg8
