/*
 * top.v
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

module top (
	// IOs
	//inout  wire [5:0] io_p_a;
	//inout  wire [5:0] io_d_a;
	//inout  wire [3:0] io_p_b;
	//inout  wire [3:0] io_d_b;

	// SPI
	inout  wire spi_mosi,
	inout  wire spi_miso,
	inout  wire spi_clk,
	inout  wire spi_flash_cs_n,

	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,

	// E1
	input  wire pad_rx0_data,
	input  wire pad_rx0_clk,
	input  wire pad_rx1_data,
	input  wire pad_rx1_clk,

	// LIU control
	inout  wire liu_mosi,
	inout  wire liu_miso,
	inout  wire liu_clk,
	inout  wire [1:0] liu_cs_n,

	// Debug UART
	//input  wire uart_rx,
	output wire uart_tx,

	// Button
	input  wire btn,

	// VIO PDM
	output wire vio_pdm,

	// LED
	output wire [2:0] rgb,

	// Clock
	input  wire clk_in
);

	localparam WB_N  = 10;
	localparam WB_DW = 32;
	localparam WB_AW = 16;
	localparam WB_AI =  2;

	genvar i;


	// Signals
	// -------

	// Dummy IOs
	wire uart_rx = 1'b1;

	// Memory bus
	wire        mem_valid;
	wire        mem_instr;
	wire        mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_rdata;
	wire [31:0] mem_wdata;
	wire [ 3:0] mem_wstrb;

	// RAM
		// BRAM
	wire [ 7:0] bram_addr;
	wire [31:0] bram_rdata;
	wire [31:0] bram_wdata;
	wire [ 3:0] bram_wmsk;
	wire        bram_we;

		// SPRAM
	wire [13:0] spram_addr;
	wire [31:0] spram_rdata;
	wire [31:0] spram_wdata;
	wire [ 3:0] spram_wmsk;
	wire        spram_we;

	// Wishbone
	wire [WB_AW-1:0] wb_addr;
	wire [WB_DW-1:0] wb_wdata;
	wire [(WB_DW/8)-1:0] wb_wmsk;
	wire [WB_DW-1:0] wb_rdata [0:WB_N-1];
	wire [(WB_DW*WB_N)-1:0] wb_rdata_flat;
	wire [WB_N-1:0] wb_cyc;
	wire wb_we;
	wire [WB_N-1:0] wb_ack;

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

		// SoF
	wire sof_usb;
	wire sof_sys;

	// E1
		// Data interface
	wire [ 7:0] e1rx0_data;
	wire [ 4:0] e1rx0_ts;
	wire [ 3:0] e1rx0_frame;
	wire [ 6:0] e1rx0_mf;
	wire e1rx0_we;
	wire e1rx0_rdy;

	wire [ 7:0] e1rx1_data;
	wire [ 4:0] e1rx1_ts;
	wire [ 3:0] e1rx1_frame;
	wire [ 6:0] e1rx1_mf;
	wire e1rx1_we;
	wire e1rx1_rdy;

		// Tick
	wire e1_tick_rx0;
	wire e1_tick_rx1;

	// IObuf
	wire [31:0] iobuf_rdata;

	// LIU SPI
	wire [7:0] liu_addr;
	wire [7:0] liu_di;
	wire [7:0] liu_do;
	wire liu_rw;
	wire liu_stb;
	wire liu_ack;
	wire liu_irq;
	wire liu_wkup;

	wire liu_miso_o, liu_miso_oe, liu_miso_i;
	wire liu_mosi_o, liu_mosi_oe, liu_mosi_i;
	wire liu_clk_o,  liu_clk_oe,  liu_clk_i;
	wire [3:0] liu_csn_o, liu_csn_oe;

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

	// Tick counter
	reg [15:0] tick0_cnt;
	reg [15:0] tick0_cap;

	reg [15:0] tick1_cnt;
	reg [15:0] tick1_cap;

	// PDM
	reg [ 7:0] vio_pdm_val;

	// Clock / Reset logic
	wire clk_24m;
	wire clk_48m;
	wire rst;


	// SoC
	// ---

	// CPU
	picorv32 #(
		.PROGADDR_RESET(32'h 0000_0000),
		.STACKADDR(32'h 0000_0400),
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(0),
		.ENABLE_COUNTERS(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(0),
		.ENABLE_IRQ_QREGS(0),
		.CATCH_MISALIGN(0),
		.CATCH_ILLINSN(0)
	) cpu_I (
		.clk       (clk_24m),
		.resetn    (~rst),
		.mem_valid (mem_valid),
		.mem_instr (mem_instr),
		.mem_ready (mem_ready),
		.mem_addr  (mem_addr),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),
		.mem_rdata (mem_rdata)
	);

	// Bus interface
	bridge #(
		.WB_N(WB_N),
		.WB_DW(WB_DW),
		.WB_AW(WB_AW),
		.WB_AI(WB_AI)
	) pb_I (
		.pb_addr(mem_addr),
		.pb_rdata(mem_rdata),
		.pb_wdata(mem_wdata),
		.pb_wstrb(mem_wstrb),
		.pb_valid(mem_valid),
		.pb_ready(mem_ready),
		.bram_addr(bram_addr),
		.bram_rdata(bram_rdata),
		.bram_wdata(bram_wdata),
		.bram_wmsk(bram_wmsk),
		.bram_we(bram_we),
		.spram_addr(spram_addr),
		.spram_rdata(spram_rdata),
		.spram_wdata(spram_wdata),
		.spram_wmsk(spram_wmsk),
		.spram_we(spram_we),
		.wb_addr(wb_addr),
		.wb_wdata(wb_wdata),
		.wb_wmsk(wb_wmsk),
		.wb_rdata(wb_rdata_flat),
		.wb_cyc(wb_cyc),
		.wb_we(wb_we),
		.wb_ack(wb_ack),
		.clk(clk_24m),
		.rst(rst)
	);

	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*WB_DW+:WB_DW] = wb_rdata[i];

	// Boot memory
	soc_bram #(
		.INIT_FILE("boot.hex")
	) bram_I (
		.addr(bram_addr),
		.rdata(bram_rdata),
		.wdata(bram_wdata),
		.wmsk(bram_wmsk),
		.we(bram_we),
		.clk(clk_24m)
	);

	// Main memory
	soc_spram spram_I (
		.addr(spram_addr),
		.rdata(spram_rdata),
		.wdata(spram_wdata),
		.wmsk(spram_wmsk),
		.we(spram_we),
		.clk(clk_24m)
	);


	// UART
	// ----

	uart_wb #(
		.DIV_WIDTH(12),
		.DW(WB_DW)
	) uart_I (
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
		.bus_addr(wb_addr[1:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[1]),
		.bus_cyc(wb_cyc[1]),
		.bus_ack(wb_ack[1]),
		.bus_we(wb_we),
		.clk(clk_24m),
		.rst(rst)
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
		.bus_addr(ub_addr),
		.bus_din(ub_wdata),
		.bus_dout(ub_rdata),
		.bus_cyc(ub_cyc),
		.bus_we(ub_we),
		.bus_ack(ub_ack),
		.sof(sof_usb),
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

	// Cross clock SoF
	xclk_strobe sof_xclk_I (
		.in_stb(sof_usb),
		.in_clk(clk_48m),
		.out_stb(sof_sys),
		.out_clk(clk_24m),
		.rst(rst)
	);

	assign wb_rdata[4][31:16] = 16'h0000;


	// IO buffers / DMA
	// ----------------

	iobuf iobuf_I (
		.wb_addr(wb_addr[15:0]),
		.wb_rdata(iobuf_rdata),
		.wb_wdata(wb_wdata),
		.wb_wmsk(wb_wmsk),
		.wb_cyc(wb_cyc[7:5]),
		.wb_we(wb_we),
		.wb_ack(wb_ack[7:5]),
		.ep_tx_addr_0(ep_tx_addr_0),
		.ep_tx_data_0(ep_tx_data_0),
		.ep_tx_we_0(ep_tx_we_0),
		.ep_rx_addr_0(ep_rx_addr_0),
		.ep_rx_data_1(ep_rx_data_1),
		.ep_rx_re_0(ep_rx_re_0),
		.e1rx0_data(e1rx0_data),
		.e1rx0_ts(e1rx0_ts),
		.e1rx0_frame(e1rx0_frame),
		.e1rx0_mf(e1rx0_mf),
		.e1rx0_we(e1rx0_we),
		.e1rx0_rdy(e1rx0_rdy),
		.e1rx1_data(e1rx1_data),
		.e1rx1_ts(e1rx1_ts),
		.e1rx1_frame(e1rx1_frame),
		.e1rx1_mf(e1rx1_mf),
		.e1rx1_we(e1rx1_we),
		.e1rx1_rdy(e1rx1_rdy),
		.clk(clk_24m),
		.rst(rst)
	);

	assign wb_rdata[5] = iobuf_rdata;
	assign wb_rdata[6] = 32'h00000000;
	assign wb_rdata[7] = 32'h00000000;


	// E1
	// --

	e1_spy_wb #(
		.MFW(7)
	) e1_spy_I (
		.pad_rx0_data(pad_rx0_data),
		.pad_rx0_clk(pad_rx0_clk),
		.pad_rx1_data(pad_rx1_data),
		.pad_rx1_clk(pad_rx1_clk),
		.buf_rx0_data(e1rx0_data),
		.buf_rx0_ts(e1rx0_ts),
		.buf_rx0_frame(e1rx0_frame),
		.buf_rx0_mf(e1rx0_mf),
		.buf_rx0_we(e1rx0_we),
		.buf_rx0_rdy(e1rx0_rdy),
		.buf_rx1_data(e1rx1_data),
		.buf_rx1_ts(e1rx1_ts),
		.buf_rx1_frame(e1rx1_frame),
		.buf_rx1_mf(e1rx1_mf),
		.buf_rx1_we(e1rx1_we),
		.buf_rx1_rdy(e1rx1_rdy),
		.bus_addr(wb_addr[3:0]),
		.bus_wdata(wb_wdata[15:0]),
		.bus_rdata(wb_rdata[8][15:0]),
		.bus_cyc(wb_cyc[8]),
		.bus_we(wb_we),
		.bus_ack(wb_ack[8]),
		.tick_rx0(e1_tick_rx0),
		.tick_rx1(e1_tick_rx1),
		.clk(clk_24m),
		.rst(rst)
	);

	assign wb_rdata[8][31:16] = 16'h0000;


	// LIU SPI
	// -------

	// Hard-IP
`ifndef SIM
	SB_SPI #(
		.BUS_ADDR74("0b0010")
	) spi_liu_I (
		.SBCLKI(clk_24m),
		.SBRWI(liu_rw),
		.SBSTBI(liu_stb),
		.SBADRI7(liu_addr[7]),
		.SBADRI6(liu_addr[6]),
		.SBADRI5(liu_addr[5]),
		.SBADRI4(liu_addr[4]),
		.SBADRI3(liu_addr[3]),
		.SBADRI2(liu_addr[2]),
		.SBADRI1(liu_addr[1]),
		.SBADRI0(liu_addr[0]),
		.SBDATI7(liu_di[7]),
		.SBDATI6(liu_di[6]),
		.SBDATI5(liu_di[5]),
		.SBDATI4(liu_di[4]),
		.SBDATI3(liu_di[3]),
		.SBDATI2(liu_di[2]),
		.SBDATI1(liu_di[1]),
		.SBDATI0(liu_di[0]),
		.MI(liu_miso_i),
		.SI(liu_mosi_i),
		.SCKI(liu_clk_i),
		.SCSNI(1'b1),
		.SBDATO7(liu_do[7]),
		.SBDATO6(liu_do[6]),
		.SBDATO5(liu_do[5]),
		.SBDATO4(liu_do[4]),
		.SBDATO3(liu_do[3]),
		.SBDATO2(liu_do[2]),
		.SBDATO1(liu_do[1]),
		.SBDATO0(liu_do[0]),
		.SBACKO(liu_ack),
		.SPIIRQ(liu_irq),
		.SPIWKUP(liu_wkup),
		.SO(liu_miso_o),
		.SOE(liu_miso_oe),
		.MO(liu_mosi_o),
		.MOE(liu_mosi_oe),
		.SCKO(liu_clk_o),
		.SCKOE(liu_clk_oe),
		.MCSNO3(liu_csn_o[3]),
		.MCSNO2(liu_csn_o[2]),
		.MCSNO1(liu_csn_o[1]),
		.MCSNO0(liu_csn_o[0]),
		.MCSNOE3(liu_csn_oe[3]),
		.MCSNOE2(liu_csn_oe[2]),
		.MCSNOE1(liu_csn_oe[1]),
		.MCSNOE0(liu_csn_oe[0])
	);
`else
	reg [3:0] sim;

	assign liu_ack = liu_stb;
	assign liu_do = { sim, 4'h8 };

	always @(posedge clk_24m)
		if (rst)
			sim <= 0;
		else if (liu_ack & liu_rw)
			sim <= sim + 1;
`endif

	// IO pads
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b1)
	) liu_io_I[2:0] (
		.PACKAGE_PIN  ({liu_mosi,    liu_miso,    liu_clk   }),
		.OUTPUT_ENABLE({liu_mosi_oe, liu_miso_oe, liu_clk_oe}),
		.D_OUT_0      ({liu_mosi_o,  liu_miso_o,  liu_clk_o }),
		.D_IN_0       ({liu_mosi_i,  liu_miso_i,  liu_clk_i })
	);

		// Bypass OE for CS_n lines
	assign liu_cs_n = liu_csn_o[1:0];

	// Bus interface
	assign liu_addr = { 4'h2, wb_addr[3:0] };
	assign liu_di   = wb_wdata[7:0];
	assign liu_rw   = wb_we;
	assign liu_stb  = wb_cyc[9];

	assign wb_rdata[9] = { {(WB_DW-8){1'b0}}, wb_cyc[9] ? liu_do : 8'h00 };
	assign wb_ack[9] = liu_ack;


	// Bus IF for "Misc"
	// -----------------

	assign wb_rdata[0] = wb_cyc[0] ? { tick1_cap, tick0_cap } : 32'h00000000;
	assign wb_ack[0] = wb_cyc[0];


	// E1 Tick counters
	// ----------------

	always @(posedge clk_24m or posedge rst)
		if (rst)
			tick0_cnt <= 16'h0000;
		else if (e1_tick_rx0)
			tick0_cnt <= tick0_cnt + 1;

	always @(posedge clk_24m or posedge rst)
		if (rst)
			tick0_cnt <= 16'h0000;
		else if (e1_tick_rx1)
			tick1_cnt <= tick1_cnt + 1;

	always @(posedge clk_24m)
		if (sof_sys) begin
			tick0_cap <= tick0_cnt;
			tick1_cap <= tick1_cnt;
		end


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

	// Helper
	dfu_helper #(
		.TIMER_WIDTH(24),
		.BTN_INVERT(1),
`ifdef DFU
		.DFU_MODE(1)
`else
		.DFU_MODE(0)
`endif
	) dfu_helper_I (
		.boot_now(boot_now),
		.boot_sel(boot_sel),
		.btn_pad(btn),
		.btn_val(),
		.rst_req(),
		.clk(clk_24m),
		.rst(rst)
	);


	// PDM
	// ---

	// Config registers
	always @(posedge clk_24m or posedge rst)
		if (rst) begin
			vio_pdm_val <= 8'hff;
		end else if (wb_cyc[0] & wb_we) begin
			if (wb_addr[2:0] == 3'b010) vio_pdm_val <= wb_wdata[7:0];
        end

	// PDM cores
	pdm #(
		.WIDTH(8),
		.PHY("ICE40"),
		.DITHER("NO")
	) vio_pdm_I (
		.in (vio_pdm_val),
		.pdm(vio_pdm),
		.oe (1'b1),
		.clk(clk_24m),
		.rst(rst)
	);


	// Clock / Reset
	// -------------

`ifdef SIM
	reg clk_24m_s = 1'b0;
	reg clk_48m_s = 1'b0;
	reg rst_s = 1'b1;

	always #20.84 clk_24m_s <= !clk_24m_s;
	always #10.42 clk_48m_s <= !clk_48m_s;

	initial begin
		#200 rst_s = 0;
	end

	assign clk_24m = clk_24m_s;
	assign clk_48m = clk_48m_s;
	assign rst = rst_s;
`else
	sysmgr sys_mgr_I (
		.clk_in(clk_in),
		.rst_in(1'b0),
		.clk_24m(clk_24m),
		.clk_48m(clk_48m),
		.rst_out(rst)
	);
`endif

endmodule // top
