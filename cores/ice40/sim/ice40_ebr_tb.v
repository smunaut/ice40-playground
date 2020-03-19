/*
 * ice40_ebr_tb.v
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
`timescale 1ns/100ps

module ice40_ebr_tb #(
	parameter integer READ_MODE  = 2,	/* 0 =  256x16, 1 =  512x8 */
	parameter integer WRITE_MODE = 1,	/* 2 = 1024x4,  3 = 2048x2 */
	parameter integer MASK_WORKAROUND = 1
);

	// Config
	// ------

	localparam integer WAW = 8 + WRITE_MODE;
	localparam integer WDW = 16 / (1 << WRITE_MODE);
	localparam integer RAW = 8 + READ_MODE;
	localparam integer RDW = 16 / (1 << READ_MODE);


	// Signals
	// -------

	reg  [WAW-1:0] wr_addr;
	reg  [WDW-1:0] wr_data;
	reg  [WDW-1:0] wr_mask;
	reg            wr_ena;

	reg  [RAW-1:0] rd_addr;
	wire [RDW-1:0] rd_data;
	reg            rd_ena;

	reg  clk = 0;
	reg  rst = 1;


	// Test bench
	// ----------

	// Setup recording
	initial begin
		$dumpfile("ice40_ebr_tb.vcd");
		$dumpvars(0,ice40_ebr_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

    // Clocks
    always #10 clk = !clk;



	// DUT
	// ---

	ice40_ebr #(
		.READ_MODE(READ_MODE),
		.WRITE_MODE(WRITE_MODE),
		.MASK_WORKAROUND(MASK_WORKAROUND)
	) dut_I (
		.wr_addr(wr_addr),
		.wr_data(wr_data),
		.wr_mask(wr_mask),
		.wr_ena(wr_ena),
		.wr_clk(clk),
		.rd_addr(rd_addr),
		.rd_data(rd_data),
		.rd_ena(rd_ena),
		.rd_clk(clk)
	);


	reg mode;

	always @(posedge clk)
	begin
		// Writes
		if (!mode) begin
			wr_addr <= wr_addr + wr_ena;
			wr_data <= $random;
			wr_mask <= 8'hf0;
			wr_ena  <= ~&wr_addr;
			mode    <= mode ^ &wr_addr;
		end

		// Reads
		if (mode) begin
			rd_addr <= rd_addr + rd_ena;
			rd_ena  <= ~&rd_addr;
			mode    <= mode ^ &rd_addr;
		end

		// Reset
		if (rst) begin
			wr_addr <= 0;
			wr_ena  <= 1'b0;
			rd_addr <= 0;
			rd_ena  <= 1'b0;
			mode    <= 1'b0;
		end
	end

endmodule
