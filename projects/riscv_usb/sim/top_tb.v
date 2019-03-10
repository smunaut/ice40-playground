/*
 * top_tb.v
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

module top_tb;

	// Signals
	// -------

	wire spi_mosi;
	wire spi_miso;
	wire spi_flash_cs_n;
	wire spi_clk;

	wire usb_dp;
	wire usb_dn;
	wire usb_pu;

	wire uart_rx;
	wire uart_tx;


	// Setup recording
	// ---------------

	initial begin
		$dumpfile("top_tb.vcd");
		$dumpvars(0,top_tb);
		# 2000000 $finish;
	end


	// DUT
	// ---

	top dut_I (
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.spi_flash_cs_n(spi_flash_cs_n),
		.spi_clk(spi_clk),
		.usb_dp(usb_dp),
		.usb_dn(usb_dn),
		.usb_pu(usb_pu),
		.uart_rx(uart_rx),
		.uart_tx(uart_tx),
		.rgb(),
		.clk_in(1'b0)
	);


	// Support
	// -------

	pullup(usb_dp);
	pullup(usb_dn);

	pullup(uart_tx);
	pullup(uart_rx);

	spiflash flash_I (
		.csb(spi_flash_cs_n),
		.clk(spi_clk),
		.io0(spi_mosi),
		.io1(spi_miso),
		.io2(),
		.io3()
	);

endmodule // top_tb
