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
	output wire spi_flash_cs_n,
`ifdef HAS_PSRAM
	output wire spi_ram_cs_n,
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

	// Audio output
	output wire [1:0] audio,

	input  wire midi_rx,
	output wire midi_tx,

	// Clock
	input  wire clk_in
);

	localparam integer SPRAM_AW = 14; /* 14 => 64k, 15 => 128k */
	localparam integer WB_N  =  8;

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

	// USB
	wire usb_sof;

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


	// SPI [2]
	// ---

	ice40_spi_wb #(
`ifdef HAS_PSRAM
		.N_CS(2),
`else
		.N_CS(1),
`endif
		.WITH_IOB(1),
		.UNIT(0)
	) spi_I (
		.pad_mosi (spi_mosi),
		.pad_miso (spi_miso),
		.pad_clk  (spi_clk),
`ifdef HAS_PSRAM
		.pad_csn  ({spi_ram_cs_n, spi_flash_cs_n}),
`else
		.pad_csn  (spi_flash_cs_n),
`endif
		.wb_addr  (wb_addr[3:0]),
		.wb_rdata (wb_rdata[2]),
		.wb_wdata (wb_wdata),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[2]),
		.wb_ack   (wb_ack[2]),
		.clk      (clk_24m),
		.rst      (rst)
	);


	// RGB LEDs [3]
	// --------

	ice40_rgb_wb #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_I (
		.pad_rgb    (rgb),
		.wb_addr    (wb_addr[4:0]),
		.wb_rdata   (wb_rdata[3]),
		.wb_wdata   (wb_wdata),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc[3]),
		.wb_ack     (wb_ack[3]),
		.clk        (clk_24m),
		.rst        (rst)
	);


	// USB [4 & 5]
	// ---

	soc_usb #(
		.DW(WB_DW)
	) usb_I (
		.usb_dp   (usb_dp),
		.usb_dn   (usb_dn),
		.usb_pu   (usb_pu),
		.wb_addr  (wb_addr[11:0]),
		.wb_rdata (wb_rdata[4]),
		.wb_wdata (wb_wdata),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[5:4]),
		.wb_ack   (wb_ack[5:4]),
		.usb_sof  (usb_sof),
		.clk_sys  (clk_24m),
		.clk_48m  (clk_48m),
		.rst      (rst)
	);

	assign wb_rdata[5] = 0;


	// Audio PCM [6]
	// ---------

	audio_pcm pcm_I (
		.audio    (audio),
		.wb_addr  (wb_addr[1:0]),
		.wb_rdata (wb_rdata[6]),
		.wb_wdata (wb_wdata),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[6]),
		.wb_ack   (wb_ack[6]),
		.usb_sof  (usb_sof),
		.clk      (clk_24m),
		.rst      (rst)
	);


	// Midi [7]
	//---------

	uart_wb #(
		.DIV_WIDTH(12),
		.DW(WB_DW)
	) midi_I (
		.uart_tx  (midi_tx),
		.uart_rx  (midi_rx),
		.wb_addr  (wb_addr[1:0]),
		.wb_rdata (wb_rdata[7]),
		.wb_we    (wb_we),
		.wb_wdata (wb_wdata),
		.wb_cyc   (wb_cyc[7]),
		.wb_ack   (wb_ack[7]),
		.clk      (clk_24m),
		.rst      (rst)
	);


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
