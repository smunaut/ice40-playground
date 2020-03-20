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
//`define NO_PLL

module top (
	// nano-PMOD
	output wire clk_lp,
	output wire clk_hs_p,
	output wire clk_hs_n,
	output wire dat_lp,
	output wire dat_hs_p,
	output wire dat_hs_n,

	output wire lcd_reset_n,
	output wire bl_pwm,

	// SPI
	input  wire spi_mosi,
	output wire spi_miso,
	input  wire spi_cs_n,
	input  wire spi_clk,

	// LED
	output wire [2:0] rgb,

	// Clock
	input  wire clk_12m
);

	localparam integer AWIDTH = 10;

	// Signals
	// -------

	// SPI 'simple-bus'
	wire [7:0] sb_addr;
	wire [7:0] sb_data;
	wire sb_first;
	wire sb_last;
	wire sb_stb;

	// SPI Packets
	wire [7:0] spf_wr_data;
	wire spf_wr_last;
	wire spf_wr_ena;
	wire spf_full;
	wire [7:0] spf_rd_data;
	wire spf_rd_last;
	wire spf_rd_ena;
	wire spf_empty;

	// MIPI
	wire [7:0] cfg_dsi_hs_prep;
	wire [7:0] cfg_dsi_hs_zero;
	wire [7:0] cfg_dsi_hs_trail;

	wire hs_clk_req;
	wire hs_clk_rdy;
	wire hs_clk_sync;

	wire hs_start;
	wire [7:0] hs_data;
	wire hs_last;
	wire hs_ack;
	wire hs_rdy;

	// LCD Control
	wire [15:0] cfg_lcd_csr;
	wire bl_pwm_i;

	// LED debug
	wire [2:0] rgb_pwm;

	// Clock / Reset logic
`ifdef NO_PLL
	reg [7:0] rst_cnt = 8'h00;
	wire rst_i;
`endif

	wire clk;
	wire rst;


	// Slave SPI interface
	// -------------------

`ifdef SPI_FAST
	spi_fast spi_I (
`else
	spi_simple spi_I (
`endif
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.spi_cs_n(spi_cs_n),
		.spi_clk(spi_clk),
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.last(sb_last),
		.strobe(sb_stb),
		.clk(clk),
		.rst(rst)
	);


	// Packet handling
	// ---------------

	// SPI Packet writer
	pkt_spi_write #(
		.BASE(8'h20)
	) write_I (
		.sb_addr(sb_addr),
		.sb_data(sb_data),
		.sb_first(sb_first),
		.sb_last(sb_last),
		.sb_strobe(sb_stb),
		.fifo_data(spf_wr_data),
		.fifo_last(spf_wr_last),
		.fifo_wren(spf_wr_ena),
		.fifo_full(spf_full),
		.clk(clk),
		.rst(rst)
	);

	// SPI packet FIFO
	pkt_fifo #(
		.AWIDTH(AWIDTH)
	) spi_packet_fifo_I (
		.wr_data(spf_wr_data),
		.wr_last(spf_wr_last),
		.wr_ena(spf_wr_ena),
		.full(spf_full),
		.rd_data(spf_rd_data),
		.rd_last(spf_rd_last),
		.rd_ena(spf_rd_ena),
		.empty(spf_empty),
		.clk(clk),
		.rst(rst)
	);

	// Packet reader
	reg reading;
	assign hs_start   = ~spf_empty & ~reading;
	assign hs_data    = spf_rd_data;
	assign hs_last    = spf_rd_last;
	assign spf_rd_ena = hs_ack;

	always @(posedge clk or posedge rst)
		if (rst)
			reading <= 1'b0;
		else
			reading <= (reading | hs_start) & ~(hs_last & hs_ack);


	// MIPI-DSI
	// --------

	// Config registers
	spi_reg #(
		.ADDR(8'h10),
		.BYTES(1)
	) reg_dsi_hs_prep_I (
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.strobe(sb_stb),
		.rst_val(8'h04),
		.out_val(cfg_dsi_hs_prep),
		.out_stb(),
		.clk(clk),
		.rst(rst)
	);

	spi_reg #(
		.ADDR(8'h11),
		.BYTES(1)
	) reg_dsi_hs_zero_I (
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.strobe(sb_stb),
		.rst_val(8'h04),
		.out_val(cfg_dsi_hs_zero),
		.out_stb(),
		.clk(clk),
		.rst(rst)
	);

	spi_reg #(
		.ADDR(8'h12),
		.BYTES(1)
	) reg_dsi_hs_trail_I (
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.strobe(sb_stb),
		.rst_val(8'h04),
		.out_val(cfg_dsi_hs_trail),
		.out_stb(),
		.clk(clk),
		.rst(rst)
	);

	// MIPI DSI cores
	nano_dsi_clk dsi_clk_I (
		.clk_lp(clk_lp),
		.clk_hs_p(clk_hs_p),
		.clk_hs_n(clk_hs_n),
		.hs_req(hs_clk_req),
		.hs_rdy(hs_clk_rdy),
		.clk_sync(hs_clk_sync),
		.cfg_hs_prep(cfg_dsi_hs_prep),
		.cfg_hs_zero(cfg_dsi_hs_zero),
		.cfg_hs_trail(cfg_dsi_hs_trail),
		.clk(clk),
		.rst(rst)
	);

	nano_dsi_data dsi_data_I (
		.data_lp(dat_lp),
		.data_hs_p(dat_hs_p),
		.data_hs_n(dat_hs_n),
		.hs_start(hs_start),
		.hs_data(hs_data),
		.hs_last(hs_last),
		.hs_ack(hs_ack),
		.hs_rdy(hs_rdy),
		.clk_sync(hs_clk_sync),
		.cfg_hs_prep(cfg_dsi_hs_prep),
		.cfg_hs_zero(cfg_dsi_hs_zero),
		.cfg_hs_trail(cfg_dsi_hs_trail),
		.clk(clk),
		.rst(rst)
	);


	// LCD misc
	// --------

	// Config registers
	spi_reg #(
		.ADDR(8'h00),
		.BYTES(2)
	) reg_lcd_csr_I (
		.addr(sb_addr),
		.data(sb_data),
		.first(sb_first),
		.strobe(sb_stb),
		.rst_val(16'h000f),
		.out_val(cfg_lcd_csr),
		.out_stb(),
		.clk(clk),
		.rst(rst)
	);

	// Back Light PWM
	pwm #(
		.WIDTH(10)
	) bl_pwm_I (
		.pwm(bl_pwm_i),
		.cfg_val(cfg_lcd_csr[9:0]),
		.clk(clk),
		.rst(rst)
	);

	assign bl_pwm = bl_pwm_i;

	// Reset
	assign lcd_reset_n = cfg_lcd_csr[15] ? 1'b0 : 1'bz;

	// HS clock enable
	assign hs_clk_req = cfg_lcd_csr[14];


	// LED debug
	// ---------

	//
	assign rgb_pwm[0] = bl_pwm_i;
	assign rgb_pwm[1] = ~spf_empty;
	assign rgb_pwm[2] = hs_clk_rdy;

	// Driver
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_drv_I (
		.RGBLEDEN(1'b1),
		.RGB0PWM(rgb_pwm[0]),
		.RGB1PWM(rgb_pwm[1]),
		.RGB2PWM(rgb_pwm[2]),
		.CURREN(1'b1),
		.RGB0(rgb[0]),
		.RGB1(rgb[1]),
		.RGB2(rgb[2])
	);


	// Clock / Reset
	// -------------

`ifdef NO_PLL
	always @(posedge clk)
		if (~rst_cnt[7])
			rst_cnt <= rst_cnt + 1;

	wire rst_i = ~rst_cnt[7];

	SB_GB clk_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(clk_12m),
		.GLOBAL_BUFFER_OUTPUT(clk)
	);

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_i),
		.GLOBAL_BUFFER_OUTPUT(rst)
	);
`else
	sysmgr sys_mgr_I (
		.clk_in(clk_12m),
		.rst_in(1'b0),
		.clk_out(clk),
		.rst_out(rst)
	);
`endif

endmodule // top

