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
	// SPI
	inout  wire spi_mosi,
	inout  wire spi_miso,
	inout  wire spi_clk,
	inout  wire spi_flash_cs_n,
	inout  wire spi_ram_cs_n,

	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,

	// Debug UART
	input  wire uart_rx,
	output wire uart_tx,

	// LED
	output wire [2:0] rgb,

	// Clock
	input  wire clk_in
);

	localparam WB_N  =  6;
	localparam WB_DW = 32;
	localparam WB_AW = 16;
	localparam WB_AI =  2;

	genvar i;


	// Signals
	// -------

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

	// UART

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

	wire        usb_ready;
	wire [31:0] usb_rdata;

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

	assign wb_rdata[0] = 0;
	assign wb_ack[0] = wb_cyc[0];

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
	assign spi_ram_cs_n   = sio_csn_o[1];

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
		.clk(clk_48m),
		.rst(rst)
	);

	// Cross clock bridge
	xclk_wb #(
		.DW(16),
		.AW(12)
	)  wb_48m_xclk_I (
		.s_addr(wb_addr[11:0]),
		.s_wdata(wb_wdata),
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
	always @(posedge clk_24m)
		wb_ack[5] <= wb_cyc[5] & ~wb_ack[5];

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

	// IP core
	SB_WARMBOOT warmboot (
		.BOOT(boot_now),
		.S0(boot_sel[0]),
		.S1(boot_sel[1])
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
