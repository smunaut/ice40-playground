/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module top (
	// Analog Video In PMOD
	input  wire  [4:0] avip_d,
	input  wire        avip_clk,

	inout  wire        avip_i2c_sda,
	output wire        avip_i2c_scl,

	// HDMI 24bpp PMOD
	output wire [11:0] hdmi_data,
	output wire        hdmi_hsync,
	output wire        hdmi_vsync,
	output wire        hdmi_de,
	output wire        hdmi_clk,

	// SPI
	inout  wire  [3:0] spi_io,
	output wire        spi_sck,
	output wire  [1:0] spi_cs_n,

	// USB
	inout  wire        usb_dp,
	inout  wire        usb_dn,
	output wire        usb_pu,

	// RGB leds
	output wire  [2:0] rgb,

	// Clock
	input  wire        clk_in
);

	// Config
	localparam integer WB_N = 3;

	localparam integer DL = (32*WB_N)-1;
	localparam integer CL = WB_N-1;


	// Signals
	// -------

	// Wishbone
	wire [31:0] wb_wdata;
	wire [DL:0] wb_rdata_flat;
	wire [31:0] wb_rdata [0:WB_N-1];
	wire [15:0] wb_addr;
	wire        wb_we;
	wire [CL:0] wb_cyc;
	wire [CL:0] wb_ack;

	// Misc
	wire [31:0] aux_csr;
	wire        bootloader;

	// I2C
	wire        i2c_scl_oe;
	wire        i2c_sda_oe;
	wire        i2c_sda_i;

	// QPI PHY
	wire [15:0] qpi_phy_io_i;
	wire [15:0] qpi_phy_io_o;
	wire [ 3:0] qpi_phy_io_oe;
	wire [ 3:0] qpi_phy_clk_o;
	wire [ 1:0] qpi_phy_cs_o;

	// QPI Memory interface
	wire [21:0] mi_addr;
	wire [ 6:0] mi_len;
	wire        mi_rw;
	wire        mi_valid;
	wire        mi_ready;

	wire [31:0] mi_wdata;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// LED driver
	wire  [2:0] rgb_pwm;

	// Clock / Reset
	wire        clk_1x;
	wire        clk_4x;
	wire        sync_4x;
	wire        rst_sys;

	wire        clk_usb;
	wire        rst_usb;

	wire        clk_pix;
	wire        rst_pix;


	// USB to Wishbone
	// ---------------

	// Core
	muacm2wb #(
		.WB_N(WB_N)
	) u2wb_I (
		.usb_dp     (usb_dp),
		.usb_dn     (usb_dn),
		.usb_pu     (usb_pu),
		.usb_clk    (clk_usb),
		.usb_rst    (rst_usb),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata_flat),
		.wb_addr    (wb_addr),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc),
		.wb_ack     (wb_ack),
		.aux_csr    (aux_csr),
		.bootloader (bootloader),
		.clk        (clk_1x),
		.rst        (rst_sys)
	);

	// wb_rdata split
	genvar i;
	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*32+:32] = wb_rdata[i];

	// Respond to DFU requests
	SB_WARMBOOT warmboot (
		.BOOT (bootloader),
		.S0   (1'b1),
		.S1   (1'b0)
	);


	// I2C [0]
	// ---

	// Core
	i2c_master_wb #(
		.DW(3)
	) i2c_I (
		.scl_oe   (i2c_scl_oe),
		.sda_oe   (i2c_sda_oe),
		.sda_i    (i2c_sda_i),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[0]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[0]),
		.wb_ack   (wb_ack[0]),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

	// IOBs
	SB_IO #(
		.PIN_TYPE    (6'b1101_01),
		.PULLUP      (1'b1),
		.IO_STANDARD ("SB_LVCMOS")
	) i2c_scl_iob (
		.PACKAGE_PIN   (avip_i2c_scl),
		.OUTPUT_CLK    (clk_1x),
		.OUTPUT_ENABLE (i2c_scl_oe),
		.D_OUT_0       (1'b0)
	);

	SB_IO #(
		.PIN_TYPE    (6'b1101_00),
		.PULLUP      (1'b1),
		.IO_STANDARD ("SB_LVCMOS")
	) i2c_sda_iob (
		.PACKAGE_PIN   (avip_i2c_sda),
		.INPUT_CLK     (clk_1x),
		.OUTPUT_CLK    (clk_1x),
		.OUTPUT_ENABLE (i2c_sda_oe),
		.D_OUT_0       (1'b0),
		.D_IN_0        (i2c_sda_i)
	);


	// QPI memory [1]
	// ----------

	// Controller
	qpi_memctrl #(
		.CMD_READ  (16'hEBEB),
		.CMD_WRITE (16'h0202),
		.DUMMY_CLK (6),
		.PAUSE_CLK (8),
		.FIFO_DEPTH(1),
		.N_CS      (2),
		.PHY_SPEED (4),
		.PHY_WIDTH (1),
		.PHY_DELAY (4)
	) memctrl_I (
		.phy_io_i   (qpi_phy_io_i),
		.phy_io_o   (qpi_phy_io_o),
		.phy_io_oe  (qpi_phy_io_oe),
		.phy_clk_o  (qpi_phy_clk_o),
		.phy_cs_o   (qpi_phy_cs_o),
		.mi_addr_cs (2'b01),
		.mi_addr    ({mi_addr[21:0], 2'b00 }),	/* 32 bits aligned */
		.mi_len     (mi_len),
		.mi_rw      (mi_rw),
		.mi_valid   (mi_valid),
		.mi_ready   (mi_ready),
		.mi_wdata   (mi_wdata),
		.mi_wack    (mi_wack),
		.mi_wlast   (mi_wlast),
		.mi_rdata   (mi_rdata),
		.mi_rstb    (mi_rstb),
		.mi_rlast   (mi_rlast),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata[1]),
		.wb_addr    (wb_addr[4:0]),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[1]),
		.wb_ack     (wb_ack[1]),
		.clk        (clk_1x),
		.rst        (rst_sys)
	);

	// PHY
	qpi_phy_ice40_4x #(
		.N_CS(2),
		.WITH_CLK(1),
	) phy_I (
		.pad_io    (spi_io),
		.pad_clk   (spi_sck),
		.pad_cs_n  (spi_cs_n),
		.phy_io_i  (qpi_phy_io_i),
		.phy_io_o  (qpi_phy_io_o),
		.phy_io_oe (qpi_phy_io_oe),
		.phy_clk_o (qpi_phy_clk_o),
		.phy_cs_o  (qpi_phy_cs_o),
		.clk_1x    (clk_1x),
		.clk_4x    (clk_4x),
		.clk_sync  (sync_4x)
	);


	// Video
	// -----

	wire  [7:0] vi_data;
	wire        vi_err;

	wire [31:0] vs_data;
	wire        vs_valid;
	wire        vs_sync;
	wire  [2:0] vs_fvh;
	wire        vs_err;

	wire [23:0] vo_data;
	wire        vo_hsync;
	wire        vo_vsync;
	wire        vo_de;

	// PHY
	vid_in_phy avip_phy_I (
		.pad_data (avip_d),
		.pad_clk  (avip_clk),
		.vid_data (vi_data),
		.vid_err  (vi_err),
		.vid_clk  (clk_pix),
		.vid_rst  (rst_pix),
		.active   (aux_csr[0])
	);

	// Synchronization
	vid_in_sync avip_sync_I (
		.vi_data (vi_data),
		.vo_data (vs_data),
		.vo_valid(vs_valid),
		.vo_sync (vs_sync),
		.vo_fvh  (vs_fvh),
		.vo_err  (vs_err),
		.clk     (clk_pix),
		.rst     (rst_pix)
	);

	// Render / doubler to HDMI
	vid_render avip_render_I (
		.vi_data  (vs_data),
		.vi_valid (vs_valid),
		.vi_sync  (vs_sync),
		.vi_fvh   (vs_fvh),
		.vo_data  (vo_data),
		.vo_hsync (vo_hsync),
		.vo_vsync (vo_vsync),
		.vo_de    (vo_de),
		.clk      (clk_pix),
		.rst      (rst_pix)
	);

	// HDMI PHY
	hdmi_phy_ddr_1x #(
		.DW  (12),
		.EDGE(1'b0)
	) hdmi_phy_I (
		.hdmi_data  (hdmi_data),
		.hdmi_hsync (hdmi_hsync),
		.hdmi_vsync (hdmi_vsync),
		.hdmi_de    (hdmi_de),
		.hdmi_clk   (hdmi_clk),
		.in_data    (vo_data),
		.in_hsync   (vo_hsync),
		.in_vsync   (vo_vsync),
		.in_de      (vo_de),
		.clk        (clk_pix)
	);

	// Capture core
	vid_cap cap_I (
		.vid_data (vi_data),
		.vid_clk  (clk_pix),
		.mi_addr  (mi_addr),
		.mi_len   (mi_len),
		.mi_rw    (mi_rw),
		.mi_valid (mi_valid),
		.mi_ready (mi_ready),
		.mi_wdata (mi_wdata),
		.mi_wack  (mi_wack),
		.mi_wlast (mi_wlast),
		.mi_rdata (mi_rdata),
		.mi_rstb  (mi_rstb),
		.mi_rlast (mi_rlast),
		.wb_addr  (wb_addr[15:0]),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[2]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[2]),
		.wb_ack   (wb_ack[2]),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

	// -----


	reg  [25:0] led_cnt;
	reg  [ 1:0] err;

	always @(posedge clk_pix)
		led_cnt <= led_cnt + 1;

	always @(posedge clk_pix)
		err <= led_cnt[25] ? 2'b00 : (err | {vs_err, vi_err});

	assign rgb_pwm[0] = led_cnt[25] & &led_cnt[2:0];
	assign rgb_pwm[1] = err[1];
	assign rgb_pwm[2] = err[0];


	// LEDs
	// ----

	// Driver
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_drv_I (
		.RGBLEDEN (1'b1),
		.RGB0PWM  (rgb_pwm[0]),
		.RGB1PWM  (rgb_pwm[1]),
		.RGB2PWM  (rgb_pwm[2]),
		.CURREN   (1'b1),
		.RGB0     (rgb[0]),
		.RGB1     (rgb[1]),
		.RGB2     (rgb[2])
	);


	// CRG
	// ---

	sysmgr crg_I (
		.clk_in  (clk_in),
		.clk_1x  (clk_1x),
		.clk_4x  (clk_4x),
		.sync_4x (sync_4x),
		.rst_sys (rst_sys),
		.clk_usb (clk_usb),
		.rst_usb (rst_usb)
	);

endmodule // top
