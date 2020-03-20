/*
 * hram_top_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
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
`timescale 1ns / 100ps

module hram_top_tb;

	// Signals
	// -------

	// HyperRAM pins
	wire [7:0] hram_dq;
	wire       hram_rwds;
	wire       hram_ck;
	wire [3:0] hram_cs_n;
	wire       hram_rst_n;

	// Memory interface
	wire [ 1:0] mi_addr_cs;
	reg  [31:0] mi_addr;
	reg  [ 6:0] mi_len;
	reg         mi_rw;
	wire        mi_linear;
	reg         mi_valid;
	wire        mi_ready;

	reg  [31:0] mi_wdata;
	wire [ 3:0] mi_wmsk;
	wire        mi_wack;

	wire [31:0] mi_rdata;
	wire        mi_rstb;

	// Wishbone interface
	reg  [31:0] wb_wdata;
	wire [31:0] wb_rdata;
	reg  [ 3:0] wb_addr;
	reg         wb_we;
	reg         wb_cyc;
	wire        wb_ack;

	// Clocks / Sync
	wire [3:0] clk_read_delay;

	reg  pll_lock = 1'b0;
	wire clk_slow;
	reg  clk_fast = 1'b0;
	reg  clk_read = 1'b0;
	reg  clk_sync;
	wire rst;

	reg        rst_div;
	reg  [1:0] clk_div;
	reg  [3:0] rst_cnt = 4'h8;


	// Recording setup
	// ---------------

	initial begin
		$dumpfile("hram_top_tb.vcd");
		$dumpvars(0,hram_top_tb);
	end


	// DUT
	// ---

	hram_top dut_I (
		.hram_dq(hram_dq),
		.hram_rwds(hram_rwds),
		.hram_ck(hram_ck),
		.hram_cs_n(hram_cs_n),
		.hram_rst_n(hram_rst_n),
		.mi_addr_cs(mi_addr_cs),
		.mi_addr(mi_addr),
		.mi_len(mi_len),
		.mi_rw(mi_rw),
		.mi_linear(mi_linear),
		.mi_valid(mi_valid),
		.mi_ready(mi_ready),
		.mi_wdata(mi_wdata),
		.mi_wmsk(mi_wmsk),
		.mi_wack(mi_wack),
		.mi_rdata(mi_rdata),
		.mi_rstb(mi_rstb),
		.wb_wdata(wb_wdata),
		.wb_rdata(wb_rdata),
		.wb_addr(wb_addr),
		.wb_we(wb_we),
		.wb_cyc(wb_cyc),
		.wb_ack(wb_ack),
		.clk_read_delay(clk_read_delay),
		.clk_slow(clk_slow),
		.clk_fast(clk_fast),
		.clk_read(clk_read),
		.clk_sync(clk_sync),
		.rst(rst)
	);


	// Mem interface
	// -------------

	// Fixed values
	assign mi_addr_cs = 2'b01;
	assign mi_linear  = 1'b0;
	assign mi_wmsk    = 4'h0;

	always @(posedge clk_slow)
		if (rst)
			mi_wdata <= 32'h00010203;
		else if (mi_wack)
			mi_wdata <= mi_wdata + 32'h04040404;

	// Stimulus
	// --------

	task wb_write;
		input [ 3:0] addr;
		input [31:0] data;
		begin
			wb_addr  <= addr;
			wb_wdata <= data;
			wb_we    <= 1'b1;
			wb_cyc   <= 1'b1;

			while (~wb_ack)
				@(posedge clk_slow);

			wb_addr  <= 4'hx;
			wb_wdata <= 32'hxxxxxxxx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;

			@(posedge clk_slow);
		end
	endtask

	task mi_burst_write;
		input [31:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b0;
			mi_valid <= 1'b1;

			@(posedge clk_slow);
			while (~mi_ready)
				@(posedge clk_slow);

			mi_valid <= 1'b0;

			@(posedge clk_slow);
		end
	endtask

	task mi_burst_read;
		input [31:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b1;
			mi_valid <= 1'b1;

			@(posedge clk_slow);
			while (~mi_ready)
				@(posedge clk_slow);

			mi_valid <= 1'b0;

			@(posedge clk_slow);
		end
	endtask

	initial begin
		// Defaults
		wb_addr  <= 4'hx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		mi_addr  <= 32'hxxxxxxxx;
		mi_len   <= 7'hx;
		mi_rw    <= 1'bx;
		mi_valid <= 1'b0;

		@(negedge rst);
		@(posedge clk_slow);

		// Reset pulse
		wb_write(4'h0, 32'h00001102);
		wb_write(4'h0, 32'h00001100);

		// Queue CR0 write
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'h60000100);
		wb_write(4'h2, 32'h00008fef);
		wb_write(4'h2, 32'h00000000);

		wb_write(4'h1, 32'h0000000e);

		// Wait
		#200
		@(posedge clk_slow);

		// Queue Memory write
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'h00000246);
		wb_write(4'h3, 32'h00000020);
		wb_write(4'h2, 32'h00040000);
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'hcafebabe);

		wb_write(4'h1, 32'h0000021c);

		// Wait
		#200
		@(posedge clk_slow);

		// Queue Memory read
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'h80000246);
		wb_write(4'h3, 32'h00000020);
		wb_write(4'h2, 32'h00040000);
		wb_write(4'h3, 32'h00000000);
		wb_write(4'h2, 32'h00000000);

		wb_write(4'h1, 32'h0000021d);

		// Wait
		#200
		@(posedge clk_slow);

		// Switch to run-time mode
		wb_write(4'h0, 32'h00001101);

		// Execute 32 byte burst
		mi_burst_write(32'h00002000, 7'd31);
		mi_burst_read (32'h00002000, 7'd15);
		mi_burst_write(32'h00003000, 7'd31);
	end


	// Clock / Reset
	// -------------

	// Native clocks
	initial begin
		# 200 pll_lock = 1'b1;
		# 100000 $finish;
	end

	always #4 clk_fast = ~clk_fast;		// 125   MHz
	always #8 clk_read = ~clk_read;		//  62.5 MHz

	// Clock Divider & Sync
	always @(negedge clk_read or negedge pll_lock)
		if (~pll_lock)
			rst_div <= 1'b1;
		else
			rst_div <= 1'b0;

	always @(posedge clk_fast or posedge rst_div)
		if (rst_div)
			{ clk_sync, clk_div } <= 3'b000;
		else
			case (clk_div)
				2'b00: { clk_sync, clk_div } <= 3'b001;
				2'b01: { clk_sync, clk_div } <= 3'b010;
				2'b10: { clk_sync, clk_div } <= 3'b011;
				2'b11: { clk_sync, clk_div } <= 3'b100;
			endcase

	assign clk_slow = clk_div[1];

	// Reset
	always @(posedge clk_slow or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h8;
		else if (rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst = rst_cnt[3];

endmodule
