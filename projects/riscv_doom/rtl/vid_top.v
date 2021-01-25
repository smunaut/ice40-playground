/*
 * vid_top.v
 *
 * Top-level for the video module
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

/* Use 640x480 60 Hz video and not original 640x400 70 Hz mode */
`define COMPAT_MODE

/* Enable dithering */
`define DITHER


module vid_top (
	// Video output
	output wire [3:0] hdmi_r,
	output wire [3:0] hdmi_g,
	output wire [3:0] hdmi_b,
	output wire       hdmi_hsync,
	output wire       hdmi_vsync,
	output wire       hdmi_de,
	output wire       hdmi_clk,

	// Wishbone
	input  wire [15:0] wb_addr,
	output reg  [31:0] wb_rdata,
	input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Signals
	// -------

	// Frame Buffer
	wire [13:0] fb_v_addr_0;
	wire [31:0] fb_v_data_1;
	wire        fb_v_re_0;
	wire [13:0] fb_a_addr_0;
	wire [31:0] fb_a_rdata_1;
	wire [31:0] fb_a_wdata_0;
	wire [ 3:0] fb_a_wmsk_0;
	wire        fb_a_we_0;
	wire        fb_a_rdy_0;

	// Palette
	wire [ 7:0] pal_w_addr;
	wire [15:0] pal_w_data;
	wire        pal_w_ena;

	wire [ 7:0] pal_r_addr_0;
	wire [15:0] pal_r_data_1;

	// Timing gen
	wire        tg_hsync_0;
	wire        tg_vsync_0;
	wire        tg_active_0;
	wire        tg_h_first_0;
	wire        tg_h_last_0;
	wire        tg_v_first_0;
	wire        tg_v_last_0;

	// Video status
	reg  [15:0] vs_frame_cnt;
	reg         vs_in_vbl;

	// Pixel pipeline
	reg         pp_active_1;
	reg         pp_ydbl_1;
	reg         pp_xdbl_1;
	reg  [15:0] pp_addr_base_1;
	reg  [15:0] pp_addr_cur_1;

	reg         pp_data_load_2;
	reg  [31:0] pp_data_3;

	wire        pp_dither_ena_4;
	wire        pp_dither_r_4;
	wire        pp_dither_g_4;
	wire        pp_dither_b_4;

	wire [11:0] pp_data_4;
	wire        pp_hsync_4;
	wire        pp_vsync_4;
	wire        pp_de_4;



	// Frame Buffer
	// ------------

	vid_framebuf fb_I (
		.v_addr_0  (fb_v_addr_0),
		.v_data_1  (fb_v_data_1),
		.v_re_0    (fb_v_re_0),
		.a_addr_0  (fb_a_addr_0),
		.a_rdata_1 (fb_a_rdata_1),
		.a_wdata_0 (fb_a_wdata_0),
		.a_wmsk_0  (fb_a_wmsk_0),
		.a_we_0    (fb_a_we_0),
		.a_rdy_0   (fb_a_rdy_0),
		.clk       (clk)
	);


	// Palette
	// -------

	vid_palette pal_I (
		.w_addr_0 (pal_w_addr),
		.w_data_0 (pal_w_data),
		.w_ena_0  (pal_w_ena),
		.r_addr_0 (pal_r_addr_0),
		.r_data_1 (pal_r_data_1),
		.clk      (clk)
	);


	// Timing Generator
	// ----------------

	vid_tgen #(
`ifndef COMPAT_MODE
		.H_WIDTH  (  10 ),
		.H_FP     (  16 ),
		.H_SYNC   (  96 ),
		.H_BP     (  48 ),
		.H_ACTIVE ( 640 ),
		.V_WIDTH  (   9 ),
		.V_FP     (  12 ),
		.V_SYNC   (   2 ),
		.V_BP     (  35 ),
		.V_ACTIVE ( 400 )
`else
		.H_WIDTH  (  10 ),
		.H_FP     (  16 ),
		.H_SYNC   (  96 ),
		.H_BP     (  48 ),
		.H_ACTIVE ( 640 ),
		.V_WIDTH  (   9 ),
		.V_FP     (  10 ),
		.V_SYNC   (   2 ),
		.V_BP     (  33 ),
		.V_ACTIVE ( 480 )
`endif
	) tgen_I (
		.vid_hsync   (tg_hsync_0),
		.vid_vsync   (tg_vsync_0),
		.vid_active  (tg_active_0),
		.vid_h_first (tg_h_first_0),
		.vid_h_last  (tg_h_last_0),
		.vid_v_first (tg_v_first_0),
		.vid_v_last  (tg_v_last_0),
		.clk         (clk),
		.rst         (rst)
	);


	// Video Status and counter
	// ------------------------

	always @(posedge clk)
		vs_in_vbl <= (vs_in_vbl & ~tg_v_first_0) | (tg_v_last_0 & tg_h_last_0);

	always @(posedge clk)
		if (rst)
			vs_frame_cnt <= 0;
		else
			vs_frame_cnt <= vs_frame_cnt + (tg_v_last_0 & tg_h_last_0);


	// Video Pipeline
	// --------------

	// Pixel fetch
`ifndef COMPAT_MODE
		// Counter control in 640x400 -> Double pixels
	always @(posedge clk) begin
		pp_active_1 <= tg_active_0;
		pp_ydbl_1   <= (pp_ydbl_1 ^ tg_h_first_0) |  tg_v_first_0;
		pp_xdbl_1   <= (pp_xdbl_1 ^ 1'b1        ) & ~tg_h_first_0;
	end
`else
		// Counter control in 640x480 -> Double X, Double-or-Triple Y
	reg [3:0] pp_yscale_state;

	always @(posedge clk)
		if (tg_h_first_0) begin
			if (tg_v_first_0) begin
				pp_yscale_state <= 4'h0;
				pp_ydbl_1       <= 1'b0;
			end else begin
				case (pp_yscale_state)
					4'h0:    { pp_ydbl_1, pp_yscale_state } <= { 1'b1, 4'h1 };
					4'h1:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h2 };
					4'h2:    { pp_ydbl_1, pp_yscale_state } <= { 1'b1, 4'h3 };
					4'h3:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h4 };
					4'h4:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h5 };
					4'h5:    { pp_ydbl_1, pp_yscale_state } <= { 1'b1, 4'h6 };
					4'h6:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h7 };
					4'h7:    { pp_ydbl_1, pp_yscale_state } <= { 1'b1, 4'h8 };
					4'h8:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h9 };
					4'h9:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'ha };
					4'ha:    { pp_ydbl_1, pp_yscale_state } <= { 1'b1, 4'hb };
					4'hb:    { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h0 };
					default: { pp_ydbl_1, pp_yscale_state } <= { 1'b0, 4'h0 };
				endcase;
			end
		end

	always @(posedge clk) begin
		pp_active_1 <= tg_active_0;
		pp_xdbl_1   <= (pp_xdbl_1 ^ 1'b1) & ~tg_h_first_0;
	end
`endif

		// Counters
	always @(posedge clk)
		if (tg_h_first_0) begin
			if (tg_v_first_0)
				pp_addr_base_1 <= 0;
			else
				pp_addr_base_1 <= pp_addr_base_1 + (pp_ydbl_1 ? 16'd320 : 16'd0);
		end

	always @(posedge clk)
		if (tg_h_first_0)
			pp_addr_cur_1 <= tg_v_first_0 ? 16'd0 : pp_addr_base_1;
		else
			pp_addr_cur_1 <= pp_addr_cur_1 + pp_xdbl_1;

		// Frame Buffer
	assign fb_v_addr_0 = pp_addr_cur_1[15:2];
	assign fb_v_re_0   = pp_active_1 & (pp_addr_cur_1[1:0] == 2'b00) & ~pp_xdbl_1;

		// Shift Reg
	always @(posedge clk)
		pp_data_load_2 <= fb_v_re_0;

	always @(posedge clk)
		if (pp_xdbl_1)
			pp_data_3 <= pp_data_load_2 ? fb_v_data_1 : { 8'h00, pp_data_3[31:8] };

	// Palette fetch
`ifdef DITHERING
	assign pp_dither_ena_4 = pp_xdbl_1 ^ pp_ydbl_1;
	assign pp_dither_r_4 = (pal_r_data_1[11] & pp_dither_ena) &~& pal_r_data_1[15:14];
	assign pp_dither_g_4 = (pal_r_data_1[ 6] & pp_dither_ena) &~& pal_r_data_1[10: 9];
	assign pp_dither_b_4 = (pal_r_data_1[ 0] & pp_dither_ena) &~& pal_r_data_1[ 4: 3];
`else
	assign pp_dither_ena_4 = 1'b0;
	assign pp_dither_r_4   = 1'b0;
	assign pp_dither_g_4   = 1'b0;
	assign pp_dither_b_4   = 1'b0;
`endif

	assign pal_r_addr_0 = pp_data_3[7:0];
	assign pp_data_4 = {
		pal_r_data_1[15:12] + pp_dither_r_4,	// R[15:11]
		pal_r_data_1[10: 7] + pp_dither_g_4,	// G[10: 5]
		pal_r_data_1[4:1]   + pp_dither_b_4		// B[ 4: 0]
	};

	// Sync signals
	delay_bit #(4) dly_hsync ( ~tg_hsync_0,  pp_hsync_4, clk );
	delay_bit #(4) dly_vsync ( ~tg_vsync_0,  pp_vsync_4, clk );
	delay_bit #(4) dly_de    (  tg_active_0, pp_de_4,    clk );

	// Output buffers
	hdmi_phy_1x #(
		.DW(12)
	) phy_I (
		.hdmi_data  ({hdmi_r, hdmi_g, hdmi_b}),
		.hdmi_hsync (hdmi_hsync),
		.hdmi_vsync (hdmi_vsync),
		.hdmi_de    (hdmi_de),
		.hdmi_clk   (hdmi_clk),
		.in_data    (pp_data_4),
		.in_hsync   (pp_hsync_4),
		.in_vsync   (pp_vsync_4),
		.in_de      (pp_de_4),
		.clk        (clk)
	);


	// Bus Interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack & (~wb_addr[15] | fb_a_rdy_0);

	// Read Mux
	always @(*)
	begin
		wb_rdata = 32'h00000000;
		if (wb_ack)
			wb_rdata = wb_addr[15] ? fb_a_rdata_1 : { 15'h0000, vs_in_vbl, vs_frame_cnt };
	end

	// Frame Buffer write
	assign fb_a_addr_0  = wb_addr[13:0];
	assign fb_a_wdata_0 = wb_wdata;
	assign fb_a_wmsk_0  = wb_wmsk;
	assign fb_a_we_0    = wb_cyc & wb_we & ~wb_ack & wb_addr[15];

	// Palette write
	assign pal_w_addr = wb_addr[7:0];
	assign pal_w_data = { wb_wdata[23:19], wb_wdata[15:10], wb_wdata[7:3] };
	assign pal_w_ena  = wb_cyc & wb_we & ~wb_ack & (wb_addr[15:14] == 2'b01);

endmodule // vid_top
