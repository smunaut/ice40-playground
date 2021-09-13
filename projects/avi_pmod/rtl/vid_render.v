/*
 * vid_render.v
 *
 * vim: ts=4 sw=4
 *
 * Renders video to HDMI, doubling lines and converting to RGB
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_render #(
	parameter integer H_ACTIVE = 720,
	parameter integer H_FP     = 48,
	parameter integer H_SYNC   = 32,
	parameter integer V_FP     =  8,
	parameter integer V_SYNC   =  4
)(
	// Input
	input  wire [31:0] vi_data,
	input  wire        vi_valid,
	input  wire        vi_sync,
	input  wire  [2:0] vi_fvh,

	// Output
	output wire [23:0] vo_data,
	output wire        vo_hsync,
	output wire        vo_vsync,
	output wire        vo_de,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Signals
	// -------

	// Write control
	wire        vi_eav;
	wire        vi_sav;

	reg         w_active;

	// Buffer
	reg         mem_w_buf;
	reg   [8:0] mem_w_pix;
	wire        mem_w_ena;
	wire [31:0] mem_w_data;

	reg         mem_r_buf_0;
	wire  [8:0] mem_r_pix_0;
	wire [31:0] mem_r_data_1;

	// Mid line
	wire       mid_eav_n;
	reg [11:0] mid_line_len;
	reg [11:0] mid_dec;
	wire       mid_stb;

	// Read control
	wire       r_start;
	reg  [9:0] r_addr_0;

	// Sync zones
	localparam [1:0] Z_BP     = 2'b00;
	localparam [1:0] Z_ACTIVE = 2'b01;
	localparam [1:0] Z_FP     = 2'b10;
	localparam [1:0] Z_SYNC   = 2'b11;

	// Horizontal sync
	reg   [1:0] h_zone_0;
	reg  [10:0] h_cnt_0;
	wire [10:0] h_dec_0;
	wire        h_last_0;

	// Vertical sync
	reg   [1:0] v_zone_0;
	reg   [4:0] v_cnt_0;
	wire  [4:0] v_dec_0;
	wire        v_last_0;

	// Output
	reg         hsync_1;
	reg         vsync_1;
	reg         de_1;


	// Write control
	// -------------

	// EAV marker
	assign vi_eav = vi_sync &  vi_fvh[0];
	assign vi_sav = vi_sync & ~vi_fvh[0];

	// Track active zone
	always @(posedge clk)
		if (rst)
			w_active <= 1'b0;
		else
			w_active <= (w_active | vi_sav) & ~vi_eav;

	// Buffer swap at each start of line
	always @(posedge clk)
		if (rst)
			mem_w_buf <= 1'b0;
		else
			mem_w_buf <= mem_w_buf ^ vi_eav;

	// Address
	always @(posedge clk)
		if (vi_sav)
			mem_w_pix <= 0;
		else
			mem_w_pix <= mem_w_pix + vi_valid;

	// Write enable
	assign mem_w_ena = vi_valid & ~vi_sync & w_active;

	// Data
	assign mem_w_data = vi_data;


	// Buffer
	// ------

	vid_line_mem mem_I (
		.w_clk    (clk),
		.w_buf    (mem_w_buf),
		.w_pix    (mem_w_pix),
		.w_ena    (mem_w_ena),
		.w_data   (mem_w_data),
		.r_clk    (clk),
		.r_buf_0  (mem_r_buf_0),
		.r_pix_0  (mem_r_pix_0),
		.r_data_1 (mem_r_data_1)
	);


	// Mid-line
	// --------

	// Force signal
	buf_bb eav_n_I (mid_eav_n, ~vi_eav);

	// Line-length measurement
	always @(posedge clk)
		mid_line_len <= vi_eav ? 12'hffe : (mid_line_len + 1);

	// Generate
`ifdef NO_WORKAROUND
	always @(posedge clk)
		mid_dec <= mid_eav_n ? ({1'b0, mid_dec[10:0]} + {12{mid_eav_n}}) : {1'b0, mid_line_len[11:1] };
`else
	wire [11:0] mid_dec_nxt_i = mid_eav_n ? ({1'b0, mid_dec[10:0]} + {12{mid_eav_n}}) : {1'b0, mid_line_len[11:1] };
	wire [11:0] mid_dec_nxt_b;

	buf_bb  mid_dec_I[11:0] ( mid_dec_nxt_b, mid_dec_nxt_i );

	always @(posedge clk)
		mid_dec <= mid_dec_nxt_b;
`endif

	assign mid_stb = mid_dec[11];


	// Read control
	// ------------

	// Start either on new line or middle point
	assign r_start = vi_eav | mid_stb;

	// Buffer at each start of line is previous write buffer
	always @(posedge clk)
		mem_r_buf_0 <= vi_eav ? mem_w_buf : mem_r_buf_0;

	// Address
	always @(posedge clk)
		if (r_start)
			r_addr_0 <= 0;
		else
			r_addr_0 <= r_addr_0 + 1;

	assign mem_r_pix_0 = r_addr_0[9:1];


	// Horizontal Sync
	// ---------------

	// Track current zone
	always @(posedge clk)
		if (r_start)
			h_zone_0 <= Z_ACTIVE;
		else
			case (h_zone_0)
				Z_ACTIVE: h_zone_0 <= h_last_0 ? Z_FP   : Z_ACTIVE;
				Z_FP:     h_zone_0 <= h_last_0 ? Z_SYNC : Z_FP;
				Z_SYNC:   h_zone_0 <= h_last_0 ? Z_BP   : Z_SYNC;
				default:  h_zone_0 <= Z_BP;
			endcase

	// Decrement
	assign h_dec_0  = h_cnt_0 - 1;
	assign h_last_0 = h_cnt_0[10];

	// Next value mux and register
	always @(posedge clk)
	begin
		if (r_start)
			h_cnt_0 <= H_ACTIVE - 2;
		else
			case (h_zone_0)
				Z_ACTIVE: h_cnt_0 <= h_last_0 ? H_FP     - 2 : h_dec_0;
				Z_FP:     h_cnt_0 <= h_last_0 ? H_SYNC   - 2 : h_dec_0;
				Z_SYNC:   h_cnt_0 <= h_last_0 ? 11'h3ff      : h_dec_0;
				default:  h_cnt_0 <= 11'h3ff;
			endcase
	end


	// Vertical Sync
	// -------------

	// Track current zone
	always @(posedge clk)
		if (vi_eav) begin
			if (~vi_fvh[1])
				v_zone_0 <= Z_ACTIVE;
			else
				case (v_zone_0)
					Z_ACTIVE: v_zone_0 <= Z_FP;
					Z_FP:     v_zone_0 <= v_last_0 ? Z_SYNC : Z_FP;
					Z_SYNC:   v_zone_0 <= v_last_0 ? Z_BP   : Z_SYNC;
					default:  v_zone_0 <= Z_BP;
				endcase
		end

	// Decrement
	assign v_dec_0  = v_cnt_0 - 1;
	assign v_last_0 = v_cnt_0[4];

	// Next value mux and register
	always @(posedge clk)
		if (vi_eav) begin
			if (~vi_fvh[1])
				v_cnt_0 <= 5'h0f;
			else
				case (v_zone_0)
					Z_ACTIVE: v_cnt_0 <= V_FP;
					Z_FP:     v_cnt_0 <= v_last_0 ? V_SYNC : v_dec_0;
					Z_SYNC:   v_cnt_0 <= v_last_0 ? 5'h0f  : v_dec_0;
					default:  v_cnt_0 <= 5'h0f;
				endcase
		end


	// Output
	// ------

	// Convert to YCbCr
	vid_ycbcr2rgb colconv_I (
		.cb_0    (mem_r_data_1[31:24]),
		.y0_0    (mem_r_data_1[23:16]),
		.cr_0    (mem_r_data_1[15: 8]),
		.y1_0    (mem_r_data_1[ 7: 0]),
		.phase_0 (~r_addr_0[0]),
		.r_5     (vo_data[23:16]),
		.g_5     (vo_data[15: 8]),
		.b_5     (vo_data[ 7: 0]),
		.clk     (clk),
		.rst     (rst)
	);

	// Generate HDMI sync
	always @(posedge clk)
	begin
		hsync_1 <= (h_zone_0 == Z_SYNC);
		vsync_1 <= (v_zone_0 == Z_SYNC);;
		de_1    <= (h_zone_0 == Z_ACTIVE) & (v_zone_0 == Z_ACTIVE);
	end

	// Align HSync / VSync / DE
	delay_bus #(5,3) dly_sync (
		{ hsync_1, vsync_1, de_1 },
		{ vo_hsync, vo_vsync, vo_de },
		clk
	);

endmodule // vid_render

(* keep_hierarchy *)
module buf_bb( output wire x, input wire a );
	assign x = a;
endmodule
