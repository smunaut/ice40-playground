/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
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

	// Button
	input  wire        btn,

	// Clock
	input  wire        clk_in
);

	// Config
	localparam integer WB_N = 8;

	localparam integer DL = (32*WB_N)-1;
	localparam integer CL = WB_N-1;


	// Signals
	// -------

	// Video pipeline
		// Control
	wire        vid_run;

		// Ingress
	wire  [7:0] vi_data;
	wire        vi_err;

		// Sync
	wire [31:0] vs_data;
	wire        vs_valid;
	wire        vs_sync;
	wire  [2:0] vs_fvh;
	wire        vs_err;

		// Output
	wire [23:0] vo_data;
	wire        vo_hsync;
	wire        vo_vsync;
	wire        vo_de;

	// Wishbone
	wire [31:0] wb_wdata;
	wire [ 3:0] wb_wmsk;
	wire [DL:0] wb_rdata_flat;
	wire [31:0] wb_rdata [0:WB_N-1];
	wire [15:0] wb_addr;
	wire        wb_we;
	wire [CL:0] wb_cyc;
	wire [CL:0] wb_ack;

	// Misc / Platform
	reg  [15:0] timer_ms;
	reg  [15:0] timer_div;

	wire        misc_btn_press;
	reg         misc_btn_latch;
	reg         misc_bootloader;

	reg         misc_bus_ack;
	wire        misc_bus_clr;
	reg  [31:0] misc_bus_rdata;
	reg         misc_bus_we_csr;

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

	// QPI Memory interface (controller)
	wire [21:0] miu_addr;
	wire [ 6:0] miu_len;
	wire        miu_rw;
	wire        miu_valid;
	wire        miu_ready;

	wire [31:0] miu_wdata;
	wire        miu_wack;
	wire        miu_wlast;

	wire [31:0] miu_rdata;
	wire        miu_rstb;
	wire        miu_rlast;

	// QPI Memory interface (device 0)
	wire [21:0] mi0_addr;
	wire [ 6:0] mi0_len;
	wire        mi0_rw;
	wire        mi0_valid;
	wire        mi0_ready;

	wire [31:0] mi0_wdata;
	wire        mi0_wack;
	wire        mi0_wlast;

	wire [31:0] mi0_rdata;
	wire        mi0_rstb;
	wire        mi0_rlast;

	// QPI Memory interface (device 1)
	wire [21:0] mi1_addr;
	wire [ 6:0] mi1_len;
	wire        mi1_rw;
	wire        mi1_valid;
	wire        mi1_ready;

	wire [31:0] mi1_wdata;
	wire        mi1_wack;
	wire        mi1_wlast;

	wire [31:0] mi1_rdata;
	wire        mi1_rstb;
	wire        mi1_rlast;

	// DMA
	wire        dma_req;
	wire        dma_gnt;
	wire [15:0] dma_addr;
	wire [31:0] dma_data;
	wire        dma_we;

	// USB Core
		// Wishbone in 48 MHz domain
	wire [11:0] ub_addr;
	wire [15:0] ub_wdata;
	wire [15:0] ub_rdata;
	wire        ub_cyc;
	wire        ub_we;
	wire        ub_ack;

		// EP Buffer
	wire [ 8:0] ep_tx_addr_0;
	wire [31:0] ep_tx_data_0;
	wire        ep_tx_we_0;

	wire [ 8:0] ep_rx_addr_0;
	wire [31:0] ep_rx_data_1;
	wire        ep_rx_re_0;

	// Clock / Reset
	wire        clk_1x;
	wire        clk_4x;
	wire        sync_4x;
	wire        rst_sys;

	wire        clk_usb;
	wire        rst_usb;

	wire        clk_pix;
	wire        rst_pix;


	// Video pipeline
	// --------------

	// PHY
	vid_in_phy avip_phy_I (
		.pad_data (avip_d),
		.pad_clk  (avip_clk),
		.vid_data (vi_data),
		.vid_err  (vi_err),
		.vid_clk  (clk_pix),
		.vid_rst  (rst_pix),
		.active   (vid_run)
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


	// SoC
	// ---

	// Base SoC
	soc_picorv32_base #(
		.WB_N     (WB_N),
		.WB_DW    (32),
		.WB_AW    (16),
		.SPRAM_AW (14)	// 64k
	) soc_I (
		.wb_addr  (wb_addr),
		.wb_rdata (wb_rdata_flat),
		.wb_wdata (wb_wdata),
		.wb_wmsk  (wb_wmsk),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

	// Wishbone un-flatten
	genvar i;
	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*32+:32] = wb_rdata[i];


	// Misc / Platform [0]
	// ---------------

	// DFU helper
	dfu_helper #(
		.SAMP_TW    ( 7),
		.LONG_TW    (19),
		.BTN_MODE   ( 3)
	) dfu_I (
		.boot_sel  (2'b01),
		.boot_now  (misc_bootloader),
		.btn_in    (btn),
		.btn_tick  (1'b0),
		.btn_val   (),
		.btn_press (misc_btn_press),
		.clk       (clk_1x),
		.rst       (rst_sys)
	);

	// 1 ms timer
	always @(posedge clk_1x)
		timer_div <= timer_div[15] ? 16'd29999 : (timer_div - 1);

	always @(posedge clk_1x or posedge rst_sys)
		if (rst_sys)
			timer_ms <= 0;
		else
			timer_ms <= timer_ms + timer_div[15];

	// Bus interface
		// Ack
	always @(posedge clk_1x)
		misc_bus_ack <= wb_cyc[0] & ~misc_bus_ack;

	assign wb_ack[0] = misc_bus_ack;

		// Read Mux
	assign misc_bus_clr = ~wb_cyc[0] | misc_bus_ack;

	always @(posedge clk_1x)
		if (misc_bus_clr)
			misc_bus_rdata <= 32'h00000000;
		else
			misc_bus_rdata <= { 15'd0, misc_btn_latch, timer_ms };

	assign wb_rdata[0] = misc_bus_rdata;

		// Writes
	always @(posedge clk_1x)
		misc_bus_we_csr <= wb_cyc[0] & ~misc_bus_ack & wb_we;

		// Button
	always @(posedge clk_1x)
		if (rst_sys)
			misc_btn_latch <= 1'b0;
		else
			misc_btn_latch <= (misc_btn_latch & ~(misc_bus_we_csr & wb_wdata[0])) | misc_btn_press;

		// Bootloader
	always @(posedge clk_1x)
		if (rst_sys)
			misc_bootloader <= 1'b0;
		else
			misc_bootloader <= misc_bootloader | (misc_bus_we_csr & wb_wdata[31]);


	// I2C [1]
	// ---

	// Core
	i2c_master_wb #(
		.DW(3),
		.FIFO_DEPTH(4)
	) i2c_I (
		.scl_oe   (i2c_scl_oe),
		.sda_oe   (i2c_sda_oe),
		.sda_i    (i2c_sda_i),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[1]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[1]),
		.wb_ack   (wb_ack[1]),
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


	// QPI memory [2]
	// ----------

	// Arbiter
	memif_arb #(
		.AW(22),
		.DW(32)
	) qpi_arb_I (
		.u_addr   (miu_addr),
		.u_len    (miu_len),
		.u_rw     (miu_rw),
		.u_valid  (miu_valid),
		.u_ready  (miu_ready),
		.u_wdata  (miu_wdata),
		.u_wack   (miu_wack),
		.u_wlast  (miu_wlast),
		.u_rdata  (miu_rdata),
		.u_rstb   (miu_rstb),
		.u_rlast  (miu_rlast),
		.d0_addr  (mi0_addr),
		.d0_len   (mi0_len),
		.d0_rw    (mi0_rw),
		.d0_valid (mi0_valid),
		.d0_ready (mi0_ready),
		.d0_wdata (mi0_wdata),
		.d0_wack  (mi0_wack),
		.d0_wlast (mi0_wlast),
		.d0_rdata (mi0_rdata),
		.d0_rstb  (mi0_rstb),
		.d0_rlast (mi0_rlast),
		.d1_addr  (mi1_addr),
		.d1_len   (mi1_len),
		.d1_rw    (mi1_rw),
		.d1_valid (mi1_valid),
		.d1_ready (mi1_ready),
		.d1_wdata (mi1_wdata),
		.d1_wack  (mi1_wack),
		.d1_wlast (mi1_wlast),
		.d1_rdata (mi1_rdata),
		.d1_rstb  (mi1_rstb),
		.d1_rlast (mi1_rlast),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

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
		.mi_addr    ({miu_addr[21:0], 2'b00 }),	/* 32 bits aligned */
		.mi_len     (miu_len),
		.mi_rw      (miu_rw),
		.mi_valid   (miu_valid),
		.mi_ready   (miu_ready),
		.mi_wdata   (miu_wdata),
		.mi_wack    (miu_wack),
		.mi_wlast   (miu_wlast),
		.mi_rdata   (miu_rdata),
		.mi_rstb    (miu_rstb),
		.mi_rlast   (miu_rlast),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata[2]),
		.wb_addr    (wb_addr[4:0]),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[2]),
		.wb_ack     (wb_ack[2]),
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


	// DMA [3]
	// ---

	soc_dma dma_I (
		.wb_addr  (wb_addr[1:0]),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[3]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[3]),
		.wb_ack   (wb_ack[3]),
		.dma_req  (dma_req),
		.dma_gnt  (dma_gnt),
		.dma_addr (dma_addr),
		.dma_data (dma_data),
		.dma_we   (dma_we),
		.mi_addr  (mi1_addr),
		.mi_len   (mi1_len),
		.mi_rw    (mi1_rw),
		.mi_valid (mi1_valid),
		.mi_ready (mi1_ready),
		.mi_wdata (mi1_wdata),
		.mi_wack  (mi1_wack),
		.mi_wlast (mi1_wlast),
		.mi_rdata (mi1_rdata),
		.mi_rstb  (mi1_rstb),
		.mi_rlast (mi1_rlast),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);


	// USB Buffer [4]
	// ----------

	soc_usb_buf_bridge usb_buf_I (
		.wb_addr      (wb_addr),
		.wb_rdata     (wb_rdata[4]),
		.wb_wdata     (wb_wdata),
		.wb_wmsk      (wb_wmsk),
		.wb_we        (wb_we),
		.wb_cyc       (wb_cyc[4]),
		.wb_ack       (wb_ack[4]),
		.dma_req      (dma_req),
		.dma_gnt      (dma_gnt),
		.dma_addr     (dma_addr),
		.dma_data     (dma_data),
		.dma_we       (dma_we),
		.ep_tx_addr_0 (ep_tx_addr_0),
		.ep_tx_data_0 (ep_tx_data_0),
		.ep_tx_we_0   (ep_tx_we_0),
		.ep_rx_addr_0 (ep_rx_addr_0),
		.ep_rx_data_1 (ep_rx_data_1),
		.ep_rx_re_0   (ep_rx_re_0),
		.clk          (clk_1x),
		.rst          (rst_sys)
	);


	// USB core [5]
	// --------

	// Cross-clock
	xclk_wb #(
		.DW(16),
		.AW(12)
	)  wb_48m_xclk_I (
		.s_addr  (wb_addr[11:0]),
		.s_wdata (wb_wdata[15:0]),
		.s_rdata (wb_rdata[5][15:0]),
		.s_cyc   (wb_cyc[5]),
		.s_ack   (wb_ack[5]),
		.s_we    (wb_we),
		.s_clk   (clk_1x),
		.m_addr  (ub_addr),
		.m_wdata (ub_wdata),
		.m_rdata (ub_rdata),
		.m_cyc   (ub_cyc),
		.m_ack   (ub_ack),
		.m_we    (ub_we),
		.m_clk   (clk_usb),
		.rst     (rst_sys)
	);

	assign wb_rdata[5][31:16] = 0;

	// Core
	usb #(
		.EPDW(32)
	) usb_I (
		.pad_dp       (usb_dp),
		.pad_dn       (usb_dn),
		.pad_pu       (usb_pu),
		.ep_tx_addr_0 (ep_tx_addr_0),
		.ep_tx_data_0 (ep_tx_data_0),
		.ep_tx_we_0   (ep_tx_we_0),
		.ep_rx_addr_0 (ep_rx_addr_0),
		.ep_rx_data_1 (ep_rx_data_1),
		.ep_rx_re_0   (ep_rx_re_0),
		.ep_clk       (clk_1x),
		.wb_addr      (ub_addr),
		.wb_rdata     (ub_rdata),
		.wb_wdata     (ub_wdata),
		.wb_we        (ub_we),
		.wb_cyc       (ub_cyc),
		.wb_ack       (ub_ack),
		.clk          (clk_usb),
		.rst          (rst_usb)
	);


	// Frame grabber [6]
	// -------------

	vid_frame_grab grab_I (
		.vid_data     (vs_data),
		.vid_valid    (vs_valid),
		.vid_clk      (clk_pix),
		.vid_rst      (rst_pix),
		.mi_addr      (mi0_addr),
		.mi_len       (mi0_len),
		.mi_rw        (mi0_rw),
		.mi_valid     (mi0_valid),
		.mi_ready     (mi0_ready),
		.mi_wdata     (mi0_wdata),
		.mi_wack      (mi0_wack),
		.mi_wlast     (mi0_wlast),
		.mi_rdata     (mi0_rdata),
		.mi_rstb      (mi0_rstb),
		.mi_rlast     (mi0_rlast),
		.wb_addr      (wb_addr),
		.wb_wdata     (wb_wdata),
		.wb_rdata     (wb_rdata[6]),
		.wb_we        (wb_we),
		.wb_cyc       (wb_cyc[6]),
		.wb_ack       (wb_ack[6]),
		.ctrl_vid_run (vid_run),
		.clk          (clk_1x),
		.rst          (rst_sys)
	);


	// RGB LEDs [7]
	// --------

	ice40_rgb_wb #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_I (
		.pad_rgb    (rgb),
		.wb_addr    (wb_addr[4:0]),
		.wb_rdata   (wb_rdata[7]),
		.wb_wdata   (wb_wdata),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[7]),
		.wb_ack     (wb_ack[7]),
		.clk        (clk_1x),
		.rst        (rst_sys)
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
