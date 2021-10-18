/*
 * hdmi_out.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module hdmi_out #(
	parameter integer DW = 4,
)(
	// HDMI pads
	output wire [DW-1:0] hdmi_data,
	output wire          hdmi_hsync,
	output wire          hdmi_vsync,
	output wire          hdmi_de,
	output wire          hdmi_clk,

	// Memory interface
	output wire [31:0] mi_addr,
	output wire [ 6:0] mi_len,
	output wire        mi_rw,
	output wire        mi_valid,
	input  wire        mi_ready,

	output wire [31:0] mi_wdata,	// Not used
	input  wire        mi_wack,		// Not used
	input  wire        mi_wlast,	// Not used

	input  wire [31:0] mi_rdata,
	input  wire        mi_rstb,
	input  wire        mi_rlast,

	// Wishbone interface
	input  wire [31:0] wb_wdata,
	output wire [31:0] wb_rdata,
	input  wire [ 6:0] wb_addr,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clocks / Sync / Reset
	input  wire clk_1x,
	input  wire clk_4x,
	input  wire sync_4x,
	input  wire rst
);

	genvar i;


	// Signals
	// -------

	// Timing Generator
	wire vt_hsync;
	wire vt_vsync;
	wire vt_de;
	wire vt_hfirst;
	wire vt_vfirst;
	wire vt_vlast;

	wire vt_trig;

	// DMA config
	reg  [31:0] dma_cfg_base;
	reg  [ 6:0] dma_cfg_bn_cnt;
	reg  [ 6:0] dma_cfg_bn_len;
	reg  [ 6:0] dma_cfg_bl_len;
	reg  [ 7:0] dma_cfg_bl_inc;

	reg         dma_run;

	// DMA runtime
	reg  [31:0] dma_addr;
	reg  [ 7:0] dma_cnt;
	reg         dma_last;
	wire        dma_valid;

	// Video Buffer
	reg         vb_pingpong;
	reg  [ 7:0] vb_waddr;
	wire [31:0] vb_wdata;
	wire        vb_wren;
	reg  [ 8:0] vb_raddr;
	wire [15:0] vb_rdata;

	// Palette
	wire [DW-1:0] pal_wdata;
	wire [   5:0] pal_waddr;
	reg           pal_wren;

	// Video Out
	reg  [   1:0] frame_cnt;

	wire [DW-1:0] vo_data[0:3];
	wire          vo_hsync;
	wire          vo_vsync;
	wire          vo_de;


	// Wishbone interface
	// ------------------

	// Ack
	always @(posedge clk_1x)
		wb_ack <= wb_cyc & ~wb_ack;

	// Register Write
	always @(posedge clk_1x or posedge rst)
		if (rst) begin
			dma_run <= 1'b0;
			dma_cfg_base   <= 0;
			dma_cfg_bn_cnt <= 0;
			dma_cfg_bn_len <= 0;
			dma_cfg_bl_len <= 0;
			dma_cfg_bl_inc <= 0;
		end else if (wb_cyc & ~wb_ack & ~wb_addr[6]) begin
			if (wb_addr[0])
				dma_cfg_base <= wb_wdata;
			else begin
				dma_run        <= wb_wdata[31];
				dma_cfg_bn_cnt <= wb_wdata[30:24];
				dma_cfg_bn_len <= wb_wdata[22:16];
				dma_cfg_bl_len <= wb_wdata[14: 8];
				dma_cfg_bl_inc <= wb_wdata[ 7: 0];
			end
		end

	// Palette write
	assign pal_wdata = wb_wdata[DW-1:0];
	assign pal_waddr = wb_addr[5:0];

	always @(posedge clk_1x)
		pal_wren <= wb_cyc & ~wb_ack & wb_addr[6];

	// No read support
	assign wb_rdata = 32'h00000000;


	// Timing generator
	// ----------------

		// Standard 1080p60
	vid_tgen #(
		.H_WIDTH  (12),
		.V_WIDTH  (12),
		.H_FP     (  88 / 4),
		.H_SYNC   (  44 / 4),
		.H_BP     ( 148 / 4),
		.H_ACTIVE (1920 / 4),
		.V_FP     (   4),
		.V_SYNC   (   5),
		.V_BP     (  36),
		.V_ACTIVE (1080)
	) hdmi_tgen_I (
		.vid_hsync   (vt_hsync),
		.vid_vsync   (vt_vsync),
		.vid_active  (vt_de),
		.vid_h_first (vt_hfirst),
		.vid_h_last  (),
		.vid_v_first (vt_vfirst),
		.vid_v_last  (vt_vlast),
		.clk         (clk_1x),
		.rst         (rst)
	);

	assign vt_trig = vt_de & vt_hfirst;


	// DMA
	// ---

	// DMA requests
	always @(posedge clk_1x)
	begin
		if (~dma_run)
			dma_cnt <= 8'h00;
		else if (vt_trig)
			dma_cnt <= { 1'b1, dma_cfg_bn_cnt };
		else if (mi_ready & mi_valid)
			dma_cnt <= dma_cnt - 1;
	end

	always @(posedge clk_1x)
		if (vt_trig)
			dma_last <= (dma_cfg_bn_cnt[6:0] == 6'h00);
		else if (mi_ready & mi_valid)
			dma_last <= (dma_cnt[6:0] == 6'h01);

	assign dma_valid = dma_cnt[7];

	always @(posedge clk_1x)
		if (vt_trig & vt_vlast)
			dma_addr <= dma_cfg_base;
		else if (mi_ready & mi_valid)
			dma_addr <= dma_addr + (dma_last ? dma_cfg_bl_inc : dma_cfg_bn_len) + 1;

	// DMA Memory interface
	assign mi_addr  = dma_addr;
	assign mi_len   = dma_last ? dma_cfg_bl_len : dma_cfg_bn_len;
	assign mi_rw    = 1'b1;
	assign mi_valid = dma_valid;

	assign mi_wdata = 32'hxxxxxxxx;

	// Buffer write path
	always @(posedge clk_1x)
		if (vt_trig)
			vb_waddr <= 8'h00;
		else
			vb_waddr <= vb_waddr + mi_rstb;

	assign vb_wdata = mi_rdata;
	assign vb_wren  = mi_rstb;


	// Video Buffer
	// ------------

	// Ping-Pong
	always @(posedge clk_1x)
		if (rst)
			vb_pingpong <= 1'b0;
		else
			vb_pingpong <= vb_pingpong ^ vt_trig;

	// Memory
	hdmi_buf line_I (
		.waddr ({vb_pingpong, vb_waddr}),
		.wdata (vb_wdata),
		.wren  (vb_wren),
		.raddr ({~vb_pingpong, vb_raddr}),
		.rdata (vb_rdata),
		.clk   (clk_1x)
	);


	// Output
	// ------

	// Frame counter (for temporal dither)
	always @(posedge clk_1x)
		if (vt_trig & vt_vfirst)
			frame_cnt <= frame_cnt + 1;

	// Buffer read
	always @(posedge clk_1x)
		if (vt_trig)
			vb_raddr <= 9'h000;
		else
			vb_raddr <= vb_raddr + vt_de;

	// Palette lookup
	generate
		for (i=0; i<4; i=i+1)
			ram_sdp #(
				.AWIDTH(6),
				.DWIDTH(DW)
			) pal_I (
				.wr_addr (pal_waddr),
				.wr_data (pal_wdata),
				.wr_ena  (pal_wren),
				.rd_addr ({frame_cnt, vb_rdata[(3-i)*4+:4]}),
				.rd_data (vo_data[i]),
				.rd_ena  (1'b1),
				.clk     (clk_1x)
			);
	endgenerate

	// Control delay
	delay_bus #(3, 3) dly_vs_I (
		.d   ({vt_hsync, vt_vsync, vt_de}),
		.q   ({vo_hsync, vo_vsync, vo_de}),
		.clk (clk_1x)
	);

	// PHY
	hdmi_phy_4x #(
		.DW(DW)
	) phy_I (
		.hdmi_data  (hdmi_data),
		.hdmi_hsync (hdmi_hsync),
		.hdmi_vsync (hdmi_vsync),
		.hdmi_de    (hdmi_de),
		.hdmi_clk   (hdmi_clk),
		.in_data0   (vo_data[0]),
		.in_data1   (vo_data[1]),
		.in_data2   (vo_data[2]),
		.in_data3   (vo_data[3]),
		.in_hsync   (vo_hsync),
		.in_vsync   (vo_vsync),
		.in_de      (vo_de),
		.clk_1x     (clk_1x),
		.clk_4x     (clk_4x),
		.clk_sync   (sync_4x)
	);

endmodule
