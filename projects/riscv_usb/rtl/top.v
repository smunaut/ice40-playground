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
	inout  wire [3:0] spi_io,
	inout  wire       spi_sck,
	inout  wire [1:0] spi_cs_n,

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

	localparam WB_N  =  6;
	localparam WB_DW = 32;
	localparam WB_AW = 16;
	localparam WB_AI =  2;

	localparam SPRAM_AW = 14; /* 14 => 64k, 15 => 128k */

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
	wire [14:0] spram_addr;
	wire [31:0] spram_rdata;
	wire [31:0] spram_wdata;
	wire [ 3:0] spram_wmsk;
	wire        spram_we;

	// Memory cache wishbone
	wire [23:0] mc_addr;
	wire [31:0] mc_rdata;
	wire [31:0] mc_wdata;
	wire [ 3:0] mc_wmsk;
	wire        mc_cyc;
	wire        mc_we;
	wire        mc_ack;

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

	// LEDs
	reg  [4:0] led_ctrl;
	wire [2:0] rgb_pwm;

	// WarmBoot
	reg boot_now;
	reg [1:0] boot_sel;

	// Clock / Reset logic
	wire [3:0] pll_delay;
	wire clk_24m;
	wire clk_48m;
	wire clk_96m;
	wire clk_rd;
	wire sync_96m;
	wire sync_rd;
	wire rst;


	// SoC
	// ---

	// Local reset for SoC to help timing
	reg soc_rst_n;

	always @(posedge clk_24m or posedge rst)
		if (rst)
			soc_rst_n <= 1'b0;
		else
			soc_rst_n <= 1'b1;

	// CPU
	picorv32 #(
		.PROGADDR_RESET(32'h 0000_0000),
		.STACKADDR(32'h 0000_0400),
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(0),
		.ENABLE_COUNTERS(1),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(0),
		.ENABLE_IRQ_QREGS(0),
		.CATCH_MISALIGN(0),
		.CATCH_ILLINSN(0)
	) cpu_I (
		.clk       (clk_24m),
		.resetn    (soc_rst_n),
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
		.mc_addr(mc_addr),
		.mc_rdata(mc_rdata),
		.mc_wdata(mc_wdata),
		.mc_wmsk(mc_wmsk),
		.mc_cyc(mc_cyc),
		.mc_we(mc_we),
		.mc_ack(mc_ack),
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
	soc_spram #(
		.AW(SPRAM_AW)
	) spram_I (
		.addr(spram_addr[SPRAM_AW-1:0]),
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


	// QSPI
	// ----

	// PHY signals
	wire [15:0] phy_io_i;
	wire [15:0] phy_io_o;
	wire [ 3:0] phy_io_oe;
	wire [ 3:0] phy_clk_o;
	wire [ 1:0] phy_cs_o;

	// Memory interface
	wire [23:0] mi_addr;
	wire [ 6:0] mi_len;
	wire        mi_rw;
	wire        mi_linear;
	wire        mi_valid;
	wire        mi_ready;

	wire [31:0] mi_wdata;
	wire [ 3:0] mi_wmsk;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// Cache Request / Response interface
	wire [23:0] cache_req_addr_pre;
	wire        cache_req_valid;
	wire        cache_req_write;
	wire [31:0] cache_req_wdata;
	wire [ 3:0] cache_req_wmask;

	wire        cache_resp_ack;
	wire        cache_resp_nak;
	wire [31:0] cache_resp_rdata;

	// Cache bus interface
	mc_bus_wb #(
		.ADDR_WIDTH(24)
	) cache_bus_I (
		.wb_addr(mc_addr),
		.wb_wdata(mc_wdata),
		.wb_wmask(mc_wmsk),
		.wb_rdata(mc_rdata),
		.wb_cyc(mc_cyc),
		.wb_we(mc_we),
		.wb_ack(mc_ack),
		.req_addr_pre(cache_req_addr_pre),
		.req_valid(cache_req_valid),
		.req_write(cache_req_write),
		.req_wdata(cache_req_wdata),
		.req_wmask(cache_req_wmask),
		.resp_ack(cache_resp_ack),
		.resp_nak(cache_resp_nak),
		.resp_rdata(cache_resp_rdata),
		.clk(clk_24m),
		.rst(rst)
	);

	// Cache
	mc_core #(
		.N_WAYS(4),
		.ADDR_WIDTH(24),
		.CACHE_LINE(64),
		.CACHE_SIZE(64)
	) cache_I (
		.req_addr_pre(cache_req_addr_pre),
		.req_valid(cache_req_valid),
		.req_write(cache_req_write),
		.req_wdata(cache_req_wdata),
		.req_wmask(cache_req_wmask),
		.resp_ack(cache_resp_ack),
		.resp_nak(cache_resp_nak),
		.resp_rdata(cache_resp_rdata),
		.mi_addr(mi_addr),
		.mi_len(mi_len),
		.mi_rw(mi_rw),
		.mi_valid(mi_valid),
		.mi_ready(mi_ready),
		.mi_wdata(mi_wdata),
		.mi_wack(mi_wack),
		.mi_wlast(mi_wlast),
		.mi_rdata(mi_rdata),
		.mi_rstb(mi_rstb),
		.mi_rlast(mi_rlast),
		.clk(clk_24m),
		.rst(rst)
	);

	// Controller
	qspi_master #(
		.CMD_READ(16'hEB0B),
		.CMD_WRITE(16'h0202),
		.DUMMY_CLK(6),
		.PAUSE_CLK(8),
		.FIFO_DEPTH(1),
		.N_CS(2),
		.PHY_SPEED(4),
		.PHY_WIDTH(1),
		.PHY_DELAY(4)
	) memctrl_I (
		.phy_io_i(phy_io_i),
		.phy_io_o(phy_io_o),
		.phy_io_oe(phy_io_oe),
		.phy_clk_o(phy_clk_o),
		.phy_cs_o(phy_cs_o),
		.mi_addr_cs(mi_addr[23:22]),
		.mi_addr({mi_addr[21:0], 2'b00 }),	/* 32 bits aligned */
		.mi_len(mi_len),
		.mi_rw(mi_rw),
		.mi_valid(mi_valid),
		.mi_ready(mi_ready),
		.mi_wdata({mi_wdata[7:0], mi_wdata[15:8], mi_wdata[23:16], mi_wdata[31:24]}),
	//	.mi_wdata(mi_wdata),
		.mi_wack(mi_wack),
		.mi_wlast(mi_wlast),
		.mi_rdata({mi_rdata[7:0], mi_rdata[15:8], mi_rdata[23:16], mi_rdata[31:24]}),
	//	.mi_rdata(mi_rdata),
		.mi_rstb(mi_rstb),
		.mi_rlast(mi_rlast),
		.wb_wdata(wb_wdata),
		.wb_rdata(wb_rdata[2]),
		.wb_addr(wb_addr[4:0]),
		.wb_we(wb_we),
		.wb_cyc(wb_cyc[2]),
		.wb_ack(wb_ack[2]),
		.clk(clk_24m),
		.rst(rst)
	);

	// PHY
	qspi_phy_ice40_4x #(
		.N_CS(2),
		.WITH_CLK(1)
	) phy_I (
		.pad_io(spi_io),
		.pad_clk(spi_sck),
		.pad_cs_n(spi_cs_n),
		.phy_io_i(phy_io_i),
		.phy_io_o(phy_io_o),
		.phy_io_oe(phy_io_oe),
		.phy_clk_o(phy_clk_o),
		.phy_cs_o(phy_cs_o),
		.clk_1x(clk_24m),
		.clk_4x(clk_96m),
		.clk_sync(sync_96m)
	);

	assign pll_delay = 4'h0;


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
		.BTN_MODE(3),
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


	// Clock / Reset
	// -------------

`ifdef SIM
	reg clk_96m_s = 1'b0;
	reg clk_48m_s = 1'b0;
	reg clk_24m_s = 1'b0;
	reg rst_s = 1'b1;
	reg [1:0] clk_sync_cnt = 2'b00;

	always  #5.21 clk_96m_s <= !clk_96m_s;
	always #10.42 clk_48m_s <= !clk_48m_s;
	always #20.84 clk_24m_s <= !clk_24m_s;

	initial begin
		#200 rst_s = 0;
	end

	always @(posedge clk_96m_s)
		if (rst)
			clk_sync_cnt <= 2'b00;
		else
			clk_sync_cnt <= clk_sync_cnt + 1;

	assign clk_rd   = clk_96m_s;
	assign clk_96m  = clk_96m_s;
	assign clk_48m  = clk_48m_s;
	assign clk_24m  = clk_24m_s;
	assign sync_96m = (clk_sync_cnt == 2'b10);
	assign sync_rd  = sync_96m;
	assign rst = rst_s;
`else
	sysmgr sys_mgr_I (
		.delay(pll_delay),
		.clk_in(clk_in),
		.clk_24m(clk_24m),
		.clk_48m(clk_48m),
		.clk_96m(clk_96m),
		.clk_rd(clk_rd),
		.sync_96m(sync_96m),
		.sync_rd(sync_rd),
		.rst(rst)
	);
`endif

endmodule // top
