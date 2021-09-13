/*
 * vid_ycbcr2rgb.v
 *
 * vim: ts=4 sw=4
 *
 * Converts a pair of pixel with 4:2:2 YcbCr to a pair of RGB pixels
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_ycbcr2rgb (
	// Input
	input  wire  [7:0] cb_0,
	input  wire  [7:0] y0_0,
	input  wire  [7:0] cr_0,
	input  wire  [7:0] y1_0,

	input  wire        phase_0,

	// Output
	output reg   [7:0] r_5,
	output reg   [7:0] g_5,
	output reg   [7:0] b_5,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Conversion parameters
	// ---------------------

	localparam [7:0] K_Y   = 8'd149;
	localparam [7:0] K_CB0 =  8'd51;
	localparam [7:0] K_CB1 = 8'd255;		// Should be 258 ...
	localparam [7:0] K_CR0 = 8'd104;
	localparam [7:0] K_CR1 = 8'd204;

	localparam [15:0] K_Y_OFS   = 16'hf6f0;	//  -16 * K_Y   + (1 << 6)
	localparam [15:0] K_CB0_OFS = 16'he680;	// -128 * K_CB0
	localparam [15:0] K_CR0_OFS = 16'hcc00;	// -128 * K_CR0
	localparam [15:0] K_CR1_OFS = 16'h9a00;	// -128 * K_CR1


	// Signals
	// -------

	wire  [7:0] y_0;

	reg         y_under_1;
	reg         y_under_2;

	reg  [ 7:0] cb_2;
	reg  [ 7:0] cb_3;

	wire [31:0] mult0_out_3;
	wire [31:0] mult1_out_3;

	wire [16:0] g_iadd_3;
	reg  [16:0] r_add_4;
	reg  [16:0] g_add_4;
	reg  [16:0] b_add_4;


	// DSPs
	// ----

	// top: Y
	// bot: Cr1
	SB_MAC16 #(
		.C_REG                    ( 1'b1),
		.A_REG                    ( 1'b1),
		.B_REG                    ( 1'b1),
		.D_REG                    ( 1'b1),
		.TOP_8x8_MULT_REG         ( 1'b1),
		.BOT_8x8_MULT_REG         ( 1'b1),
		.PIPELINE_16x16_MULT_REG1 ( 1'b0),
		.PIPELINE_16x16_MULT_REG2 ( 1'b0),
		.TOPOUTPUT_SELECT         (2'b01),
		.TOPADDSUB_LOWERINPUT     (2'b01),
		.TOPADDSUB_UPPERINPUT     ( 1'b1),
		.TOPADDSUB_CARRYSELECT    (2'b00),
		.BOTOUTPUT_SELECT         (2'b01),
		.BOTADDSUB_LOWERINPUT     (2'b01),
		.BOTADDSUB_UPPERINPUT     ( 1'b1),
		.BOTADDSUB_CARRYSELECT    (2'b00),
		.MODE_8x8                 ( 1'b1),
		.A_SIGNED                 ( 1'b0),
		.B_SIGNED                 ( 1'b0)
	) mult0_I (
		.O         (mult0_out_3),
		.A         ({y_0,     cr_0}),
		.B         ({K_Y,     K_CR1}),
		.C         (K_Y_OFS),
		.D         (K_CR1_OFS),
		.CLK       (clk),
		.CE        (1'b1),
		.IRSTTOP   (1'b0),
		.IRSTBOT   (1'b0),
		.ORSTTOP   (y_under_2),
		.ORSTBOT   (1'b0),
		.AHOLD     (1'b0),
		.BHOLD     (1'b0),
		.CHOLD     (1'b0),
		.DHOLD     (1'b0),
		.OHOLDTOP  (1'b0),
		.OHOLDBOT  (1'b0),
		.OLOADTOP  (1'b0),
		.OLOADBOT  (1'b0),
		.ADDSUBTOP (1'b0),
		.ADDSUBBOT (1'b0)
	);

	// top: Cb0
	// bot: Cr0
	SB_MAC16 #(
		.C_REG                    ( 1'b1),
		.A_REG                    ( 1'b1),
		.B_REG                    ( 1'b1),
		.D_REG                    ( 1'b1),
		.TOP_8x8_MULT_REG         ( 1'b1),
		.BOT_8x8_MULT_REG         ( 1'b1),
		.PIPELINE_16x16_MULT_REG1 ( 1'b0),
		.PIPELINE_16x16_MULT_REG2 ( 1'b0),
		.TOPOUTPUT_SELECT         (2'b01),
		.TOPADDSUB_LOWERINPUT     (2'b01),
		.TOPADDSUB_UPPERINPUT     ( 1'b1),
		.TOPADDSUB_CARRYSELECT    (2'b00),
		.BOTOUTPUT_SELECT         (2'b01),
		.BOTADDSUB_LOWERINPUT     (2'b01),
		.BOTADDSUB_UPPERINPUT     ( 1'b1),
		.BOTADDSUB_CARRYSELECT    (2'b00),
		.MODE_8x8                 ( 1'b1),
		.A_SIGNED                 ( 1'b0),
		.B_SIGNED                 ( 1'b0)
	) mult1_I (
		.O         (mult1_out_3),
		.A         ({cb_0,   cr_0}),
		.B         ({K_CB0, K_CR0}),
		.C         (K_CB0_OFS),
		.D         (K_CR0_OFS),
		.CLK       (clk),
		.CE        (1'b1),
		.IRSTTOP   (1'b0),
		.IRSTBOT   (1'b0),
		.ORSTTOP   (1'b0),
		.ORSTBOT   (1'b0),
		.AHOLD     (1'b0),
		.BHOLD     (1'b0),
		.CHOLD     (1'b0),
		.DHOLD     (1'b0),
		.OHOLDTOP  (1'b0),
		.OHOLDBOT  (1'b0),
		.OLOADTOP  (1'b0),
		.OLOADBOT  (1'b0),
		.ADDSUBTOP (1'b0),
		.ADDSUBBOT (1'b0)
	);


	// Fabric data path
	// ----------------

	// Mux Y0/Y1
	assign y_0 = phase_0 ? y1_0 : y0_0;

	// Detect Y underflow
	always @(posedge clk)
	begin
		y_under_1 <= ~|y_0[7:4];
		y_under_2 <= y_under_1;
	end

	// Delay match Cb (and do the -128)
	// (using the fact is only changes ever 2 clk to save one register)
	always @(posedge clk)
		if (phase_0)
			cb_2 <= cb_0;

	always @(posedge clk)
		cb_3 <= cb_2 ^ 8'h80;

	// Intermediate adder
	assign g_iadd_3 = ~( { mult1_out_3[31], mult1_out_3[31:16] } + { mult1_out_3[15], mult1_out_3[15:0] } );

	// Final Adders
	always @(posedge clk)
	begin
		r_add_4 <= { 1'b0, mult0_out_3[31:16] } + { mult0_out_3[15], mult0_out_3[15:0] };
		g_add_4 <= { 1'b0, mult0_out_3[31:16] } + g_iadd_3 + 1'b1;
		b_add_4 <= { 1'b0, mult0_out_3[31:16] } + { cb_3[7], cb_3, 8'h80 };
	end

	// Saturation stage
	always @(posedge clk)
	begin
		// Red
		casez (r_add_4[16:15])
			2'b1?:   r_5 <= 8'h00; // Underflow
			2'b01:   r_5 <= 8'hff; // Overflow
			default: r_5 <= r_add_4[14:7];
		endcase

		// Green
		casez (g_add_4[16:15])
			2'b1?:   g_5 <= 8'h00; // Underflow
			2'b01:   g_5 <= 8'hff; // Overflow
			default: g_5 <= g_add_4[14:7];
		endcase

		// Blue
		casez (b_add_4[16:15])
			2'b1?:   b_5 <= 8'h00; // Underflow
			2'b01:   b_5 <= 8'hff; // Overflow
			default: b_5 <= b_add_4[14:7];
		endcase
	end

endmodule // vid_ycbcr2rgb
