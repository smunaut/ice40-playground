/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`include "boards.vh"

module top (
	// SPI
	inout  wire spi_mosi,
	inout  wire spi_miso,
	inout  wire spi_clk,
	inout  wire spi_flash_cs_n,
`ifdef HAS_PSRAM
	inout  wire spi_ram_cs_n,
`endif

	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,

	// Debug UART
	input  wire uart_rx,
	output wire uart_tx,

	// Button
	input  wire btn,

	// LED
	output wire [2:0] rgb,

	// Clock
	input  wire clk_in
);

	localparam integer SPRAM_AW = 14; /* 14 => 64k, 15 => 128k */
	localparam integer WB_N  =  6;

	localparam integer WB_DW = 32;
	localparam integer WB_AW = 16;
	localparam integer WB_RW = WB_DW * WB_N;
	localparam integer WB_MW = WB_DW / 8;

	genvar i;


	// Signals
	// -------

	// Wishbone
	wire [WB_AW-1:0] wb_addr;
	wire [WB_DW-1:0] wb_rdata [0:WB_N-1];
	wire [WB_RW-1:0] wb_rdata_flat;
	wire [WB_DW-1:0] wb_wdata;
	wire [WB_MW-1:0] wb_wmsk;
	wire [WB_N -1:0] wb_cyc;
	wire             wb_we;
	wire [WB_N -1:0] wb_ack;

	// USB Core
		// EP Buffer
	wire [ 8:0] ep_tx_addr_0;
	wire [31:0] ep_tx_data_0;
	wire ep_tx_we_0;

	wire [ 8:0] ep_rx_addr_0;
	wire [31:0] ep_rx_data_1;
	wire ep_rx_re_0;

		// Bus interface
	wire [11:0] ub_addr;
	wire [15:0] ub_wdata;
	wire [15:0] ub_rdata;
	wire ub_cyc;
	wire ub_we;
	wire ub_ack;

	// SPI
	wire [7:0] sb_addr;
	wire [7:0] sb_di;
	wire [7:0] sb_do;
	wire sb_rw;
	wire sb_stb;
	wire sb_ack;
	wire sb_irq;
	wire sb_wkup;

	wire sio_miso_o, sio_miso_oe, sio_miso_i;
	wire sio_mosi_o, sio_mosi_oe, sio_mosi_i;
	wire sio_clk_o,  sio_clk_oe,  sio_clk_i;
	wire [3:0] sio_csn_o, sio_csn_oe;

	// LEDs
	reg  [4:0] led_ctrl;
	wire [2:0] rgb_pwm;

	// WarmBoot
	reg boot_now;
	reg [1:0] boot_sel;

	// Clock / Reset logic
	wire clk_24m;
	wire clk_48m;
	wire rst;


	// SoC
	// ---

	soc_picorv32_base #(
		.WB_N    (WB_N),
		.WB_DW   (WB_DW),
		.WB_AW   (WB_AW),
		.SPRAM_AW(SPRAM_AW)
	) base_I (
		.wb_addr (wb_addr),
		.wb_rdata(wb_rdata_flat),
		.wb_wdata(wb_wdata),
		.wb_wmsk (wb_wmsk),
		.wb_we   (wb_we),
		.wb_cyc  (wb_cyc),
		.wb_ack  (wb_ack),
		.clk     (clk_24m),
		.rst     (rst)
	);

	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*WB_DW+:WB_DW] = wb_rdata[i];



	// UART [1]
	// ----

	uart_wb #(
		.DIV_WIDTH(12),
		.DW(WB_DW)
	) uart_I (
		.uart_tx  (uart_tx),
		.uart_rx  (uart_rx),
		.wb_addr  (wb_addr[1:0]),
		.wb_rdata (wb_rdata[1]),
		.wb_we    (wb_we),
		.wb_wdata (wb_wdata),
		.wb_cyc   (wb_cyc[1]),
		.wb_ack   (wb_ack[1]),
		.clk      (clk_24m),
		.rst      (rst)
	);


	// SPI
	// ---

	// Hard-IP
`ifndef SIM
	SB_SPI #(
		.BUS_ADDR74("0b0000")
	) spi_I (
		.SBCLKI(clk_24m),
		.SBRWI(sb_rw),
		.SBSTBI(sb_stb),
		.SBADRI7(sb_addr[7]),
		.SBADRI6(sb_addr[6]),
		.SBADRI5(sb_addr[5]),
		.SBADRI4(sb_addr[4]),
		.SBADRI3(sb_addr[3]),
		.SBADRI2(sb_addr[2]),
		.SBADRI1(sb_addr[1]),
		.SBADRI0(sb_addr[0]),
		.SBDATI7(sb_di[7]),
		.SBDATI6(sb_di[6]),
		.SBDATI5(sb_di[5]),
		.SBDATI4(sb_di[4]),
		.SBDATI3(sb_di[3]),
		.SBDATI2(sb_di[2]),
		.SBDATI1(sb_di[1]),
		.SBDATI0(sb_di[0]),
		.MI(sio_miso_i),
		.SI(sio_mosi_i),
		.SCKI(sio_clk_i),
		.SCSNI(1'b1),
		.SBDATO7(sb_do[7]),
		.SBDATO6(sb_do[6]),
		.SBDATO5(sb_do[5]),
		.SBDATO4(sb_do[4]),
		.SBDATO3(sb_do[3]),
		.SBDATO2(sb_do[2]),
		.SBDATO1(sb_do[1]),
		.SBDATO0(sb_do[0]),
		.SBACKO(sb_ack),
		.SPIIRQ(sb_irq),
		.SPIWKUP(sb_wkup),
		.SO(sio_miso_o),
		.SOE(sio_miso_oe),
		.MO(sio_mosi_o),
		.MOE(sio_mosi_oe),
		.SCKO(sio_clk_o),
		.SCKOE(sio_clk_oe),
		.MCSNO3(sio_csn_o[3]),
		.MCSNO2(sio_csn_o[2]),
		.MCSNO1(sio_csn_o[1]),
		.MCSNO0(sio_csn_o[0]),
		.MCSNOE3(sio_csn_oe[3]),
		.MCSNOE2(sio_csn_oe[2]),
		.MCSNOE1(sio_csn_oe[1]),
		.MCSNOE0(sio_csn_oe[0])
	);
`else
	reg [3:0] sim;

	assign sb_ack = sb_stb;
	assign sb_do = { sim, 4'h8 };

	always @(posedge clk_24m)
		if (rst)
			sim <= 0;
		else if (sb_ack & sb_rw)
			sim <= sim + 1;
`endif

	// IO pads
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b1)
	) spi_io_I[2:0] (
		.PACKAGE_PIN  ({spi_mosi,    spi_miso,    spi_clk   }),
		.OUTPUT_ENABLE({sio_mosi_oe, sio_miso_oe, sio_clk_oe}),
		.D_OUT_0      ({sio_mosi_o,  sio_miso_o,  sio_clk_o }),
		.D_IN_0       ({sio_mosi_i,  sio_miso_i,  sio_clk_i })
	);

		// Bypass OE for CS_n lines
	assign spi_flash_cs_n = sio_csn_o[0];
`ifdef HAS_PSRAM
	assign spi_ram_cs_n   = sio_csn_o[1];
`endif

	// Bus interface
	assign sb_addr = { 4'h0, wb_addr[3:0] };
	assign sb_di   = wb_wdata[7:0];
	assign sb_rw   = wb_we;
	assign sb_stb  = wb_cyc[2];

	assign wb_rdata[2] = { {(WB_DW-8){1'b0}}, wb_cyc[2] ? sb_do : 8'h00 };
	assign wb_ack[2] = sb_ack;


	// LEDs
	// ----

	SB_LEDDA_IP led_I (
		.LEDDCS(wb_addr[4] & wb_we),
		.LEDDCLK(clk_24m),
		.LEDDDAT7(wb_wdata[7]),
		.LEDDDAT6(wb_wdata[6]),
		.LEDDDAT5(wb_wdata[5]),
		.LEDDDAT4(wb_wdata[4]),
		.LEDDDAT3(wb_wdata[3]),
		.LEDDDAT2(wb_wdata[2]),
		.LEDDDAT1(wb_wdata[1]),
		.LEDDDAT0(wb_wdata[0]),
		.LEDDADDR3(wb_addr[3]),
		.LEDDADDR2(wb_addr[2]),
		.LEDDADDR1(wb_addr[1]),
		.LEDDADDR0(wb_addr[0]),
		.LEDDDEN(wb_cyc[3]),
		.LEDDEXE(led_ctrl[1]),
		.PWMOUT0(rgb_pwm[0]),
		.PWMOUT1(rgb_pwm[1]),
		.PWMOUT2(rgb_pwm[2]),
		.LEDDON()
	);

	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_drv_I (
		.RGBLEDEN(led_ctrl[2]),
		.RGB0PWM(rgb_pwm[0]),
		.RGB1PWM(rgb_pwm[1]),
		.RGB2PWM(rgb_pwm[2]),
		.CURREN(led_ctrl[3]),
		.RGB0(rgb[0]),
		.RGB1(rgb[1]),
		.RGB2(rgb[2])
	);

	always @(posedge clk_24m or posedge rst)
		if (rst)
			led_ctrl <= 0;
		else if (wb_cyc[3] & ~wb_addr[4] & wb_we)
			led_ctrl <= wb_wdata[4:0];

	assign wb_rdata[3] = { WB_DW{1'b0} };
	assign wb_ack[3] = wb_cyc[3];


	// USB Core
	// --------

	// Core
	usb #(
		.EPDW(32)
	) usb_I (
		.pad_dp(usb_dp),
		.pad_dn(usb_dn),
		.pad_pu(usb_pu),
		.ep_tx_addr_0(ep_tx_addr_0),
		.ep_tx_data_0(ep_tx_data_0),
		.ep_tx_we_0(ep_tx_we_0),
		.ep_rx_addr_0(ep_rx_addr_0),
		.ep_rx_data_1(ep_rx_data_1),
		.ep_rx_re_0(ep_rx_re_0),
		.ep_clk(clk_24m),
		.wb_addr(ub_addr),
		.wb_rdata(ub_rdata),
		.wb_wdata(ub_wdata),
		.wb_we(ub_we),
		.wb_cyc(ub_cyc),
		.wb_ack(ub_ack),
		.clk(clk_48m),
		.rst(rst)
	);

	// Cross clock bridge
	xclk_wb #(
		.DW(16),
		.AW(12)
	)  wb_48m_xclk_I (
		.s_addr(wb_addr[11:0]),
		.s_wdata(wb_wdata[15:0]),
		.s_rdata(wb_rdata[4][15:0]),
		.s_cyc(wb_cyc[4]),
		.s_ack(wb_ack[4]),
		.s_we(wb_we),
		.s_clk(clk_24m),
		.m_addr(ub_addr),
		.m_wdata(ub_wdata),
		.m_rdata(ub_rdata),
		.m_cyc(ub_cyc),
		.m_ack(ub_ack),
		.m_we(ub_we),
		.m_clk(clk_48m),
		.rst(rst)
	);

	assign wb_rdata[4][31:16] = 16'h0000;

	// EP buffer interface
	reg wb_ack_ep;

	always @(posedge clk_24m)
		wb_ack_ep <= wb_cyc[5] & ~wb_ack_ep;

	assign wb_ack[5] = wb_ack_ep;

	assign ep_tx_addr_0 = wb_addr[8:0];
	assign ep_tx_data_0 = wb_wdata;
	assign ep_tx_we_0   = wb_cyc[5] & ~wb_ack[5] & wb_we;

	assign ep_rx_addr_0 = wb_addr[8:0];
	assign ep_rx_re_0   = 1'b1;

	assign wb_rdata[5] = wb_cyc[5] ? ep_rx_data_1 : 32'h00000000;


	// Warm Boot
	// ---------

	// Bus interface
	always @(posedge clk_24m or posedge rst)
		if (rst) begin
			boot_now <= 1'b0;
			boot_sel <= 2'b00;
		end else if (wb_cyc[0] & wb_we & (wb_addr[2:0] == 3'b000)) begin
			boot_now <= wb_wdata[2];
			boot_sel <= wb_wdata[1:0];
		end

	assign wb_rdata[0] = 0;
	assign wb_ack[0] = wb_cyc[0];

	// Helper
	dfu_helper #(
		.TIMER_WIDTH(24),
		.BTN_MODE(3),
		.DFU_MODE(0)
	) dfu_helper_I (
		.boot_now(boot_now),
		.boot_sel(boot_sel),
		.btn_pad(btn),
		.btn_val(),
		.rst_req(),
		.clk(clk_24m),
		.rst(rst)
	);


	// Clock / Reset
	// -------------

`ifdef SIM
	reg clk_48m_s = 1'b0;
	reg clk_24m_s = 1'b0;
	reg rst_s = 1'b1;

	always #10.42 clk_48m_s <= !clk_48m_s;
	always #20.84 clk_24m_s <= !clk_24m_s;

	initial begin
		#200 rst_s = 0;
	end

	assign clk_48m = clk_48m_s;
	assign clk_24m = clk_24m_s;
	assign rst = rst_s;
`else
	sysmgr sys_mgr_I (
		.clk_in(clk_in),
		.rst_in(1'b0),
		.clk_48m(clk_48m),
		.clk_24m(clk_24m),
		.rst_out(rst)
	);
`endif

endmodule // top
