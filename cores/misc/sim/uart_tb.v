/*
 * uart_tb.v
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
`timescale 1ns / 100ps

module uart_tb;

	// Signals
	reg rst = 1'b1;
	reg clk_rx = 1'b0;
	reg clk_tx = 1'b0;

	wire serial;

	reg  [7:0] tx_data;
	wire tx_valid;
	wire tx_ack;

	wire [7:0] rx_data;
	wire rx_stb;

	// Setup recording
	initial begin
		$dumpfile("uart_tb.vcd");
		$dumpvars(0,uart_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #10.4 clk_rx = !clk_rx;
	always #10.0 clk_tx = !clk_tx;

	// DUT
	uart_tx #(
		.DIV_WIDTH(4)
	) dut_tx_I (
		.tx(serial),
		.data(tx_data),
		.valid(tx_valid),
		.ack(tx_ack),
		.div(4'h3),
		.clk(clk_tx),
		.rst(rst)
	);

	uart_rx #(
		.DIV_WIDTH(4),
		.GLITCH_FILTER(2)
	) dut_rx_I (
		.rx(serial),
		.data(rx_data),
		.stb(rx_stb),
		.div(4'h3),
		.clk(clk_rx),
		.rst(rst)
	);

	always @(posedge clk_tx)
		if (rst)
			tx_data <= 8'h00;
		else if (tx_ack)
			tx_data <= tx_data + 1;

	assign tx_valid = ~rst;

endmodule // uart_tb
