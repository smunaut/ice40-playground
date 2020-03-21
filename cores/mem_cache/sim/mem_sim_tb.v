/*
 * mem_sim_tb.v
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

module mem_sim_tb;

	// Signals
	// -------

	// Memory interface
	reg  [19:0] mi_addr;
	reg  [ 6:0] mi_len;
	reg         mi_rw;
	reg         mi_valid;
	wire        mi_ready;

	reg  [31:0] mi_wdata;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// Clocks / Sync
	wire [3:0] clk_read_delay;

	reg  pll_lock = 1'b0;
	reg  clk = 1'b0;
	wire rst;

	reg  [3:0] rst_cnt = 4'h8;


	// Recording setup
	// ---------------

	initial begin
		$dumpfile("mem_sim_tb.vcd");
		$dumpvars(0,mem_sim_tb);
	end


	// DUT
	// ---

	mem_sim dut_I (
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
		.clk(clk),
		.rst(rst)
	);


	// Mem interface
	// -------------

	always @(posedge clk)
		if (rst)
			mi_wdata <= 32'h00010203;
		else if (mi_wack)
			mi_wdata <= mi_wdata + 32'h04040404;


	// Stimulus
	// --------

	task mi_burst_write;
		input [31:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b0;
			mi_valid <= 1'b1;

			@(posedge clk);
			while (~mi_ready)
				@(posedge clk);

			mi_valid <= 1'b0;

			@(posedge clk);
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

			@(posedge clk);
			while (~mi_ready)
				@(posedge clk);

			mi_valid <= 1'b0;

			@(posedge clk);
		end
	endtask

	initial begin
		// Defaults
		mi_addr  <= 32'hxxxxxxxx;
		mi_len   <= 7'hx;
		mi_rw    <= 1'bx;
		mi_valid <= 1'b0;

		@(negedge rst);
		@(posedge clk);

		#200 @(posedge clk);

		// Execute 32 byte burst
		mi_burst_read (32'h00002000, 7'd15);
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

	always #4 clk = ~clk;

	// Reset
	always @(posedge clk or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h8;
		else if (rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst = rst_cnt[3];

endmodule
