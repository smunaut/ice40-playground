/*
 * dfu_helper_tb.v
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

module dfu_helper_tb;

	// Signals
	// -------

	reg clk = 1'b0;
	reg rst = 1'b1;
	reg btn = 1'b0;


	// Setup recording
	// ---------------

	initial begin
		$dumpfile("dfu_helper_tb.vcd");
		$dumpvars(0,dfu_helper_tb);
		# 2000000 $finish;
	end

	always #10 clk <= !clk;

	initial begin
		#200 rst = 0;
		#10000 btn = 1;
		#200000 btn = 0;
		#100000 btn = 1;
	end


	// DUT
	// ---

	dfu_helper #(
		.TIMER_WIDTH(12),
		.BTN_MODE(3),
		.DFU_MODE(0)
	) dut_I (
		.boot_sel(2'b00),
		.boot_now(1'b0),
		.btn_pad(btn),
		.btn_val(),
		.rst_req(),
		.clk(clk),
		.rst(rst)
	);

endmodule // dfu_helper_tb
