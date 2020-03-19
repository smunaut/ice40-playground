/*
 * ice40_spram_gen.v
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

module ice40_spram_gen #(
	parameter integer ADDR_WIDTH = 15,
	parameter integer DATA_WIDTH = 32,

	// auto
	parameter integer MASK_WIDTH = (DATA_WIDTH + 3) / 4,

	parameter integer AL = ADDR_WIDTH - 1,
	parameter integer DL = DATA_WIDTH - 1,
	parameter integer ML = MASK_WIDTH - 1
)(
	input  wire [AL:0] addr,
	output reg  [DL:0] rd_data,
	input  wire        rd_ena,		// Write WILL corrupt read data
	input  wire [DL:0] wr_data,
	input  wire [ML:0] wr_mask,
	input  wire        wr_ena,
	input  wire        clk
);

	genvar x, y;

	// Constants
	// ---------

	localparam integer ND = 1 << (ADDR_WIDTH - 14);
	localparam integer NW = (DATA_WIDTH + 15) / 16;

	localparam integer MSW = (ADDR_WIDTH > 14) ? (ADDR_WIDTH - 14) : 0;
	localparam integer MDW = NW * 16;
	localparam integer MMW = NW *  4;

	initial
		$display("ice40_spram_gen: (%dx%d) -> %dx%d array of SPRAM\n", (1<<ADDR_WIDTH), DATA_WIDTH, ND, NW);


	// Signals
	// -------

	reg  [AL:0]    addr_r;

	wire [13:0]    mem_addr;

	wire [ND-1:0]  mem_sel;
	wire [ND-1:0]  mem_ce;
	wire [ND-1:0]  mem_wren;

	wire [MDW-1:0] mem_do_m[0:ND-1];
	wire [MDW-1:0] mem_do_w;
	reg  [MDW-1:0] mem_di_w;
	reg  [MMW-1:0] mem_dm_w;

	wire [15:0]    mem_do[0:ND*NW-1];
	wire [15:0]    mem_di[0:ND*NW-1];
	wire [ 3:0]    mem_dm[0:ND*NW-1];


	// Main logic
	// ----------

	// Register address for read-muxing
	always @(posedge clk)
		if (rd_ena)
			addr_r <= addr;

	// Address mapping
	assign mem_addr = addr[13:0];

	// Map input data to/from 16*NW bit words
	always @(*)
	begin : map
		integer n, x, o;

		// Map actual bits
		for (n=0; n<MASK_WIDTH; n=n+1)
		begin
			// Determine position
			x = n % NW;	// Which SPRAM
			o = n / NW;	// Which nibble inside that SPRAM

			// Map IO
			mem_di_w[(16*x)+(4*o)+:4] =  wr_data[4*n+:4];
			mem_dm_w[( 4*x)+   o    ] = ~wr_mask[n];

			rd_data[4*n+:4] = mem_do_w[(16*x)+(4*o)+:4];
		end
	end

	// Generate memory array
	generate
		// Per-depth loop
		for (y=0; y<ND; y=y+1)
		begin
			// Per-width loop
			for (x=0; x<NW; x=x+1)
			begin
				// IO mapping for word
				assign mem_di[y*NW+x] = mem_di_w[x*16+:16];
				assign mem_dm[y*NW+x] = mem_dm_w[x* 4+: 4];

				assign mem_do_m[y][x*16+:16] = mem_do[y*NW+x];

				// Memory element
				SB_SPRAM256KA ram_I (
					.ADDRESS   (mem_addr),
					.DATAIN    (mem_di[y*NW+x]),
					.MASKWREN  (mem_dm[y*NW+x]),
					.WREN      (mem_wren[y]),
					.CHIPSELECT(mem_ce[y]),
					.CLOCK     (clk),
					.STANDBY   (1'b0),
					.SLEEP     (1'b0),
					.POWEROFF  (1'b1),
					.DATAOUT   (mem_do[y*NW+x])
				);
			end

			// Enables
			if (MSW == 0)
				assign mem_sel[y] = 1'b1;
			else
				assign mem_sel[y] = (addr[AL:AL-MSW+1] == y);

			assign mem_wren[y] = mem_sel[y] &  wr_ena;
			assign mem_ce[y]   = mem_sel[y] & (wr_ena | rd_ena);

			// Muxing
			if (MSW == 0)
				// Trivial case
				assign mem_do_w = mem_do_m[0];
			else
				// Read side mux
				assign mem_do_w = mem_do_m[addr_r[AL:AL-MSW+1]];
		end
	endgenerate

endmodule
