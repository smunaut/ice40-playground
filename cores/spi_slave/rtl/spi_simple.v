/*
 * spi_simple.v
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

module spi_simple (
	// SPI pads
	input  wire spi_mosi,
	output wire spi_miso,
	input  wire spi_cs_n,
	input  wire spi_clk,

	// Interface
	output wire [7:0] addr,
	output wire [7:0] data,
	output reg  first,
	output reg  last,
	output wire strobe,

	input  wire [7:0] out,

	// Clock / Reset
	input  wire  clk,
	input  wire  rst
);
	// Signals
	// -------

	wire spi_cs_n_i;
	wire spi_cs_n_r;
	wire spi_cs_n_f;
	wire spi_clk_r;
	wire spi_clk_f;
	wire spi_mosi_i;

	reg  spi_miso_out;
	wire spi_miso_oe;

	reg [8:0] shift_reg;
	reg [7:0] addr_reg;
	reg [2:0] bit_cnt;

	reg has_byte;
	reg addr_done;
	reg strobe_addr;
	reg strobe_ext;


	// IOs
	// ---

	// IOs
	spi_simple_io_in cs_n_io_I (
		.pad(spi_cs_n),
		.val(spi_cs_n_i),
		.rise(spi_cs_n_r),
		.fall(spi_cs_n_f),
		.clk(clk),
		.rst(rst)
	);

	spi_simple_io_in clk_io_I (
		.pad(spi_clk),
		.val(),
		.rise(spi_clk_r),
		.fall(spi_clk_f),
		.clk(clk),
		.rst(rst)
	);

	spi_simple_io_in mosi_io_I (
		.pad(spi_mosi),
		.val(spi_mosi_i),
		.rise(),
		.fall(),
		.clk(clk),
		.rst(rst)
	);

	spi_simple_io_out miso_io_I (
		.pad(spi_miso),
		.val(spi_miso_out),
		.oe(spi_miso_oe),
		.clk(clk),
		.rst(rst)
	);


	// Control logic
	// -------------

	// Output of single byte
	assign spi_miso_oe  = ~spi_cs_n_i;

	always @(posedge clk)
		if (spi_cs_n_f)
			spi_miso_out <= out[7];
		else if (spi_clk_f)
			spi_miso_out <= shift_reg[7] & ~(has_byte | addr_done);

	// Shift register
	always @(posedge clk)
		if (spi_cs_n_f)
			shift_reg <= { 1'b0, out };
		else if (spi_clk_r | spi_cs_n_r)
			shift_reg <= { shift_reg[7:0], spi_mosi_i };

	// Bit counter
	always @(posedge clk)
		if (spi_cs_n_f)
			bit_cnt <= 0;
		else
			bit_cnt <= bit_cnt + spi_clk_r;

	// Strobes
	always @(posedge clk)
		if (spi_cs_n_f) begin
			// Technically reset isn't needed ... but sharing it should allow
			// packing in the same TILE as the other bit using that reset line
			has_byte    <= 1'b0;
			strobe_addr <= 1'b0;
			strobe_ext  <= 1'b0;
		end else begin
			has_byte <= (has_byte & ~(spi_clk_r | spi_cs_n_r)) | ((bit_cnt == 3'b111) & spi_clk_r);
			strobe_addr <= has_byte & (spi_clk_r | spi_cs_n_r) & ~addr_done;
			strobe_ext  <= has_byte & (spi_clk_r | spi_cs_n_r) &  addr_done;
		end

	// Address register
	always @(posedge clk)
		if (spi_cs_n_f)
			addr_done <= 1'b0;
		else
			addr_done <= addr_done | strobe_addr;

	always @(posedge clk)
		if (strobe_addr)
			addr_reg <= shift_reg[8:1];

	// Outputs
	assign addr   = addr_reg;
	assign data   = shift_reg[8:1];
	assign strobe = strobe_ext;

	always @(posedge clk)
	begin
		if (spi_cs_n_f) begin
			first <= 1'b1;
			last  <= 1'b0;
		end else begin
			first <= first & ~strobe_ext;
			last  <= last | spi_cs_n_r;
		end
	end

endmodule // spi


module spi_simple_io_in (
	input  wire pad,
	output wire val,
	output reg  rise,
	output reg  fall,
	input  wire clk,
	input  wire rst
);
	// Signals
	wire iob_out;
	reg val_i;

	// IOB
	SB_IO #(
		.PIN_TYPE(6'b000000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) cs_n_iob_I (
		.PACKAGE_PIN(pad),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(clk),
//		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(1'b0),
		.D_OUT_0(1'b0),
		.D_OUT_1(1'b0),
		.D_IN_0(iob_out),
		.D_IN_1()
	);

	// Value and transition registers
	always @(posedge clk or posedge rst)
		if (rst) begin
			val_i <= 1'b0;
			rise  <= 1'b0;
			fall  <= 1'b0;
		end else begin
			val_i <=  iob_out;
			rise  <=  iob_out & ~val_i;
			fall  <= ~iob_out &  val_i;
		end

	assign val = val_i;

endmodule // spi_simple_io_in


module spi_simple_io_out (
	output wire pad,
	input  wire val,
	input  wire oe,
	input  wire clk,
	input  wire rst
);

	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) miso_iob_I (
		.PACKAGE_PIN(pad),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(clk),
		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(oe),
		.D_OUT_0(val),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);

endmodule // spi_simple_io_out
