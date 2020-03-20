/*
 * pkt_spi_write.v
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

module pkt_spi_write #(
	parameter BASE = 8'h20
)(
	// SPI 'simple bus'
	input  wire [7:0] sb_addr,
	input  wire [7:0] sb_data,
	input  wire sb_first,
	input  wire sb_last,
	input  wire sb_strobe,

	// Packet FIFO write
	output reg  [7:0] fifo_data,
	output reg  fifo_last,
	output reg  fifo_wren,
	input  wire fifo_full,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Signals
	reg [7:0] data;
	reg first;
	reg last;

	reg [2:0] cnt;

	reg [7:0] data_mux;

	reg hit_ena;
	reg hit_type;
	reg hit_ext;

	// Decode 'hits'
	always @(posedge clk)
	begin
		hit_ena  <= sb_strobe & (sb_addr[7:1] == (BASE >> 1));
		hit_type <= sb_addr[0] & cnt[2] & ~sb_first;
		hit_ext  <= hit_ena & hit_type;
	end

	// Register data
	always @(posedge clk)
		if (sb_strobe) begin
			data  <= sb_data;
			first <= sb_first;
			last  <= sb_last;
		end

	// Position counter
	always @(posedge clk)
		if (sb_strobe) begin
			if (sb_first)
				cnt <= 0;
			else
				cnt <= cnt + { 3'b000, ~cnt[2] };
		end

	// Data Mux
	always @(*)
		if (~hit_type)
			// RAW
			data_mux = data;
		else if (~hit_ext)
			// Ext First byte
//			data_mux = { data[4:2], data[1:0], data[1:0], data[1] };
			data_mux = { data[5:3], data[2:0], data[2:1] };
		else
			// Ext Second byte
//			data_mux = { data[7:5], data[7:6], data[4:2] };
			data_mux = { data[7:6], data[7:6], data[7], data[5:3] };

	// FIFO interface
	always @(posedge clk)
	begin
		fifo_data <= data_mux;
		fifo_last <= last & (~hit_type | hit_ext);
		fifo_wren <= hit_ena | hit_ext;
	end

endmodule // pkt_spi_write
