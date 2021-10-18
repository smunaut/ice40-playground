/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`include "boards.vh"

module top (
	// SPI
`ifdef MEM_spi
	inout  wire [3:0] spi_io,
	output wire       spi_sck,
	output wire [1:0] spi_cs_n,
`endif

	// HyperRAM
`ifdef MEM_hyperram
	inout  wire [7:0] hram_dq,
	inout  wire       hram_rwds,
	output wire       hram_ck,
	output wire [3:0] hram_cs_n,
	output wire       hram_rst_n,
`endif

	// HDMI pads
`ifdef VIDEO_4bpp
	output wire [ 3:0] hdmi_data,
`endif

`ifdef VIDEO_12bpp
	output wire [11:0] hdmi_data,
`endif

`ifndef VIDEO_none
	output wire hdmi_hsync,
	output wire hdmi_vsync,
	output wire hdmi_de,
	output wire hdmi_clk,
`endif

`ifdef HAS_UART
	// UART
	input  wire uart_rx,
	output wire uart_tx,
`endif

`ifdef HAS_USB
	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,
`endif

	// Clock (12M)
	input  wire clk_in
);

	// Target UART baudrate
	localparam integer BAUDRATE = 2000000;


	// Signals
	// -------

	// Control
	wire [31:0] aux_csr;
	wire        dma_run;

	// Wishbone interface
	reg  [31:0] wb_wdata;
	wire [95:0] wb_rdata;
	reg  [15:0] wb_addr;
	reg         wb_we;
	reg  [ 2:0] wb_cyc;
	wire [ 2:0] wb_ack;

	// Memory interface
	wire [31:0] mi_addr;
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

	// Memory interface - Memory Tester
	wire [31:0] mi0_addr;
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

	// Memory interface - Video DMA
	wire [31:0] mi1_addr;
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

	// Clock / Reset
	wire [3:0] clk_rd_delay;
	wire clk_1x;
	wire clk_2x;
	wire clk_4x;
	wire clk_rd;
	wire sync_4x;
	wire sync_rd;
	wire rst;

	wire clk_usb;
	wire rst_usb;
	wire bootloader;


	// Host interface
	// --------------

`ifdef HAS_UART
	uart2wb #(
		.UART_DIV($rtoi((`SYS_FREQ / BAUDRATE) + 0.5)),
`elsif HAS_USB
	muacm2wb #(
`endif
		.WB_N(3)
	) if_I (
`ifdef HAS_UART
		.uart_rx  (uart_rx),
		.uart_tx  (uart_tx),
`elsif HAS_USB
		.usb_dp   (usb_dp),
		.usb_dn   (usb_dn),
		.usb_pu   (usb_pu),
		.usb_clk  (clk_usb),
		.usb_rst  (rst_usb),
		.bootloader (bootloader),
`endif
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata),
		.wb_addr  (wb_addr),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.aux_csr  (aux_csr),
		.clk      (clk_1x),
		.rst      (rst)
	);

	assign dma_run = aux_csr[0];

`ifdef HAS_USB
	SB_WARMBOOT warmboot (
		.BOOT (bootloader),
		.S0   (1'b1),
		.S1   (1'b0)
	);
`endif


	// QSPI Controller
	// ---------------

`ifdef MEM_spi
	// Config
	localparam integer PHY_SPEED = 4;
	localparam integer PL = (4 * PHY_SPEED) - 1;
	localparam integer CL = PHY_SPEED - 1;

	// Signals
	wire [PL:0] phy_io_i;
	wire [PL:0] phy_io_o;
	wire [ 3:0] phy_io_oe;
	wire [CL:0] phy_clk_o;
	wire [ 1:0] phy_cs_o;

	// Controller
	qpi_memctrl #(
		.CMD_READ   (16'hEBEB),
		.CMD_WRITE  (16'h0202),
		.DUMMY_CLK  (6),
		.PAUSE_CLK  (8),
		.FIFO_DEPTH (1),
		.N_CS       (2),
		.PHY_SPEED  (PHY_SPEED),
		.PHY_WIDTH  (1),
		.PHY_DELAY  ((PHY_SPEED == 1) ? 2 : ((PHY_SPEED == 2) ? 3 : 4))
	) memctrl_I (
		.phy_io_i   (phy_io_i),
		.phy_io_o   (phy_io_o),
		.phy_io_oe  (phy_io_oe),
		.phy_clk_o  (phy_clk_o),
		.phy_cs_o   (phy_cs_o),
		.mi_addr_cs (mi_addr[31:30]),
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
		.wb_rdata   (wb_rdata[31:0]),
		.wb_addr    (wb_addr[4:0]),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[0]),
		.wb_ack     (wb_ack[0]),
		.clk        (clk_1x),
		.rst        (rst)
	);

	// PHY
	generate
		if (PHY_SPEED == 1)
			qpi_phy_ice40_1x #(
				.N_CS     (2),
				.WITH_CLK (1),
				.NEG_IN   (0)
			) phy_I (
				.pad_io    (spi_io),
				.pad_clk   (spi_sck),
				.pad_cs_n  (spi_cs_n),
				.phy_io_i  (phy_io_i),
				.phy_io_o  (phy_io_o),
				.phy_io_oe (phy_io_oe),
				.phy_clk_o (phy_clk_o),
				.phy_cs_o  (phy_cs_o),
				.clk       (clk_1x)
			);

		else if (PHY_SPEED == 2)
			qpi_phy_ice40_2x #(
				.N_CS     (2),
				.WITH_CLK (1),
			) phy_I (
				.pad_io    (spi_io),
				.pad_clk   (spi_sck),
				.pad_cs_n  (spi_cs_n),
				.phy_io_i  (phy_io_i),
				.phy_io_o  (phy_io_o),
				.phy_io_oe (phy_io_oe),
				.phy_clk_o (phy_clk_o),
				.phy_cs_o  (phy_cs_o),
				.clk_1x    (clk_1x),
				.clk_2x    (clk_2x)
			);

		else if (PHY_SPEED == 4)
			qpi_phy_ice40_4x #(
				.N_CS     (2),
				.WITH_CLK (1),
			) phy_I (
				.pad_io    (spi_io),
				.pad_clk   (spi_sck),
				.pad_cs_n  (spi_cs_n),
				.phy_io_i  (phy_io_i),
				.phy_io_o  (phy_io_o),
				.phy_io_oe (phy_io_oe),
				.phy_clk_o (phy_clk_o),
				.phy_cs_o  (phy_cs_o),
				.clk_1x    (clk_1x),
				.clk_4x    (clk_4x),
				.clk_sync  (sync_4x)
			);
	endgenerate

	assign clk_rd_delay = 4'h0;
`endif


	// HyperRAM Controller
	// -------------------

`ifdef MEM_hyperram
	// Signals
	wire [ 1:0] phy_ck_en;

	wire [ 3:0] phy_rwds_in;
	wire [ 3:0] phy_rwds_out;
	wire [ 1:0] phy_rwds_oe;

	wire [31:0] phy_dq_in;
	wire [31:0] phy_dq_out;
	wire [ 1:0] phy_dq_oe;

	wire [ 3:0] phy_cs_n;
	wire        phy_rst_n;

	wire [ 7:0] phy_cfg_wdata;
	wire [ 7:0] phy_cfg_rdata;
	wire        phy_cfg_stb;

	// Controller
	hbus_memctrl hram_ctrl_I (
		.phy_ck_en     (phy_ck_en),
		.phy_rwds_in   (phy_rwds_in),
		.phy_rwds_out  (phy_rwds_out),
		.phy_rwds_oe   (phy_rwds_oe),
		.phy_dq_in     (phy_dq_in),
		.phy_dq_out    (phy_dq_out),
		.phy_dq_oe     (phy_dq_oe),
		.phy_cs_n      (phy_cs_n),
		.phy_rst_n     (phy_rst_n),
		.phy_cfg_wdata (phy_cfg_wdata),
		.phy_cfg_rdata (phy_cfg_rdata),
		.phy_cfg_stb   (phy_cfg_stb),
		.mi_addr_cs    (mi_addr[31:30]),
		.mi_addr       ({1'b0, mi_addr[29:0], 1'b0}),	/* 32b aligned */
		.mi_len        (mi_len),
		.mi_rw         (mi_rw),
		.mi_linear     (1'b0),
		.mi_valid      (mi_valid),
		.mi_ready      (mi_ready),
		.mi_wdata      (mi_wdata),
		.mi_wmsk       (4'h0),
		.mi_wack       (mi_wack),
		.mi_rdata      (mi_rdata),
		.mi_rstb       (mi_rstb),
		.wb_wdata      (wb_wdata),
		.wb_rdata      (wb_rdata[31:0]),
		.wb_addr       (wb_addr[3:0]),
		.wb_we         (wb_we),
		.wb_cyc        (wb_cyc[0]),
		.wb_ack        (wb_ack[0]),
		.clk           (clk_1x),
		.rst           (rst)
	);

	// PHY
	hbus_phy_ice40 hram_phy_I (
		.hbus_dq       (hram_dq),
		.hbus_rwds     (hram_rwds),
		.hbus_ck       (hram_ck),
		.hbus_cs_n     (hram_cs_n),
		.hbus_rst_n    (hram_rst_n),
		.phy_ck_en     (phy_ck_en),
		.phy_rwds_in   (phy_rwds_in),
		.phy_rwds_out  (phy_rwds_out),
		.phy_rwds_oe   (phy_rwds_oe),
		.phy_dq_in     (phy_dq_in),
		.phy_dq_out    (phy_dq_out),
		.phy_dq_oe     (phy_dq_oe),
		.phy_cs_n      (phy_cs_n),
		.phy_rst_n     (phy_rst_n),
		.phy_cfg_wdata (phy_cfg_wdata),
		.phy_cfg_rdata (phy_cfg_rdata),
		.phy_cfg_stb   (phy_cfg_stb),
		.clk_rd_delay  (clk_rd_delay),
		.clk_1x        (clk_1x),
		.clk_4x        (clk_4x),
		.clk_rd        (clk_rd),
		.sync_4x       (sync_4x),
		.sync_rd       (sync_rd)
	);
`endif


	// Memory tester
	// -------------

	memtest #(
		.ADDR_WIDTH(32)
	) memtest_I (
		.mi_addr  (mi0_addr),
		.mi_len   (mi0_len),
		.mi_rw    (mi0_rw),
		.mi_valid (mi0_valid),
		.mi_ready (mi0_ready),
		.mi_wdata (mi0_wdata),
		.mi_wack  (mi0_wack),
		.mi_rdata (mi0_rdata),
		.mi_rstb  (mi0_rstb),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[63:32]),
		.wb_addr  (wb_addr[8:0]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[1]),
		.wb_ack   (wb_ack[1]),
		.clk      (clk_1x),
		.rst      (rst)
	);


	// Memory Mux
	// ----------

	assign mi_addr    = dma_run ? mi1_addr    : mi0_addr;
	assign mi_len     = dma_run ? mi1_len     : mi0_len;
	assign mi_rw      = dma_run ? mi1_rw      : mi0_rw;
	assign mi_valid   = dma_run ? mi1_valid   : mi0_valid;
	assign mi0_ready  = mi_ready & ~dma_run;
	assign mi1_ready  = mi_ready &  dma_run;

	assign mi_wdata  = dma_run ? mi1_wdata : mi0_wdata;
	assign mi0_wack  = mi_wack & ~dma_run;
	assign mi0_wlast = mi_wlast;
	assign mi1_wack  = mi_wack &  dma_run;
	assign mi1_wlast = mi_wlast;

	assign mi0_rdata = mi_rdata;
	assign mi0_rstb  = mi_rstb & ~dma_run;
	assign mi0_rlast = mi_rlast;
	assign mi1_rdata = mi_rdata;
	assign mi1_rstb  = mi_rstb &  dma_run;
	assign mi1_rlast = mi_rlast;


	// HDMI output
	// -----------

`ifndef VIDEO_none
	hdmi_out #(
`ifdef VIDEO_4bpp
		.DW(4)
`endif
`ifdef VIDEO_12bpp
		.DW(12)
`endif
	) hdmi_I (
		.hdmi_data  (hdmi_data),
		.hdmi_hsync (hdmi_hsync),
		.hdmi_vsync (hdmi_vsync),
		.hdmi_de    (hdmi_de),
		.hdmi_clk   (hdmi_clk),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata[95:64]),
		.wb_addr    (wb_addr[6:0]),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[2]),
		.wb_ack     (wb_ack[2]),
		.mi_addr    (mi1_addr),
		.mi_len     (mi1_len),
		.mi_rw      (mi1_rw),
		.mi_valid   (mi1_valid),
		.mi_ready   (mi1_ready),
		.mi_wdata   (mi1_wdata),
		.mi_wack    (mi1_wack),
		.mi_rdata   (mi1_rdata),
		.mi_rstb    (mi1_rstb),
		.clk_1x     (clk_1x),
		.clk_4x     (clk_4x),
		.sync_4x    (sync_4x),
		.rst        (rst)
	);
`else
	// Dummy wishbone
	assign wb_ack[2]       = wb_cyc[2];
	assign wb_rdata[95:64] = 32'h00000000;

	// Dummy mem-if
	assign mi1_addr  = 32'hxxxxxxxx;
	assign mi1_len   = 7'hxx;
	assign mi1_rw    = 1'bx;
	assign mi1_valid = 1'b0;
	assign mi1_wdata = 32'hxxxxxxxx;
`endif


	// Clock / Reset
	// -------------

	sysmgr sysmgr_I (
		.delay   (clk_rd_delay),
		.clk_in  (clk_in),
		.clk_1x  (clk_1x),
		.clk_2x  (clk_2x),
		.clk_4x  (clk_4x),
		.clk_rd  (clk_rd),
		.sync_4x (sync_4x),
		.sync_rd (sync_rd),
		.rst     (rst),
		.clk_usb (clk_usb),
		.rst_usb (rst_usb)
	);

endmodule
