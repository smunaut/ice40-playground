/*
 * hub75_framebuffer.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

`default_nettype none

module hub75_framebuffer #(
	parameter integer N_BANKS  = 2,
	parameter integer N_ROWS   = 32,
	parameter integer N_COLS   = 64,
	parameter integer N_CHANS  = 3,
	parameter integer N_PLANES = 8,
	parameter integer BITDEPTH = 24,

	// Auto-set
	parameter integer LOG_N_BANKS = $clog2(N_BANKS),
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS),
	parameter integer LOG_N_COLS  = $clog2(N_COLS)
)(
	// Write interface - Row store/swap
	input  wire [LOG_N_BANKS-1:0] wr_bank_addr,
	input  wire [LOG_N_ROWS-1:0]  wr_row_addr,
	input  wire wr_row_store,
	output wire wr_row_rdy,
	input  wire wr_row_swap,

	// Write interface - Access
	input  wire [BITDEPTH-1:0] wr_data,
	input  wire [LOG_N_COLS-1:0] wr_col_addr,
	input  wire wr_en,

	// Read interface - Preload
	input  wire [LOG_N_ROWS-1:0] rd_row_addr,
	input  wire rd_row_load,
	output wire rd_row_rdy,
	input  wire rd_row_swap,

	// Read interface - Access
	output wire [(N_BANKS * N_CHANS * N_PLANES)-1:0] rd_data,
	input  wire [LOG_N_COLS-1:0] rd_col_addr,
	input  wire rd_en,

	// Frame swap request
	input  wire frame_swap,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Internal params
	// ---------------
		// This tries to come up with the best memory layout and sets up
		// a bunch of constants appropriately
		//
		// Address seen from access PoV ( fb_addr signal ) :
		//            1 : Buffer Select
		//  LOG_N_BANKS : Bank selection
		//  LOG_N_ROWS  : Row address
		//  LOG_N_COLS  : Column address
		//  LOG_FB_DC   : Index of the word that compose the full color data
		//                (when framebuffer width is thinner than BITDEPTH)
		//  -------------
		//  FB_AW       : (total number of bit in that address)
		//
		// To map this to the memory address ( mem_addr signal ):
		//  * Add PAD_BITS at the MSBs (just in case we use less than 1 SPRAM)
		//  * Drop OMUX_BITS + IMUX_BITS at the LSBs
		//    - IMUX_BITS used for muxing down the 16 bit wide bus down to
		//      FB_DW if needed
		//    - OMUX_BITS used to mux between the SPRAMs used in // to
		//      increase the total memory depth

	`define MIN(_a, _b) ((_a) < (_b) ? (_a) : (_b))
	`define MAX(_a, _b) ((_a) > (_b) ? (_a) : (_b))

	// Round bitdepth to a power of 2 with minimum of 4
	localparam integer LOG_BITDEPTH = (BITDEPTH > 4) ? $clog2(BITDEPTH) : 2;

	// Number of SPRAM needed for frame buffer
	localparam integer LOG_SPRAM_COUNT = `MAX(0, (1 + LOG_N_BANKS + LOG_N_ROWS + LOG_N_COLS + LOG_BITDEPTH) - 18);
	localparam integer SPRAM_COUNT = 1 << LOG_SPRAM_COUNT;

	// Width of the framebuffer access bus
	localparam integer FB_DW = `MIN((16 * SPRAM_COUNT), (1 << LOG_BITDEPTH));

	// Number of SPRAM used in 'width-mode'
	localparam integer LOG_SPRAM_WIDE = $clog2(`MAX(FB_DW,16)) - 4;
	localparam integer SPRAM_WIDE = 1 << LOG_SPRAM_WIDE;

	// Number of SPRAM used in 'depth-mode'
	localparam integer LOG_SPRAM_DEEP = LOG_SPRAM_COUNT - LOG_SPRAM_WIDE;
	localparam integer SPRAM_DEEP = 1 << LOG_SPRAM_DEEP;

	// Number of framebuffer words for each pixel
	localparam integer LOG_FB_DC = LOG_BITDEPTH - $clog2(FB_DW);
	localparam integer FB_DC = 1 << LOG_FB_DC;

	// Framebuffer final address width
	localparam integer FB_AW = 1 + LOG_N_BANKS + LOG_N_ROWS + LOG_N_COLS + LOG_FB_DC;

	// Zero-bits to MSB pad SPRAM address (if using less than 1 SPRAM)
	localparam integer PAD_BITS = `MAX(0, 18 - (1 + LOG_N_BANKS + LOG_N_ROWS + LOG_N_COLS + LOG_BITDEPTH));

	// Number of bits used for muxing inside the wide memory bus down to FB_DW
	localparam integer IMUX_BITS = $clog2(`MAX(1, 16 / FB_DW));

	// Number of bits used for muxing between the SPRAM used in // to increase depth
	localparam integer OMUX_BITS = LOG_SPRAM_DEEP;

	initial begin
		$display("Hub75 Frame Buffer config :");
		$display(" - SPRAM_COUNT : %d", SPRAM_COUNT);
		$display(" - SPRAM_WIDE  : %d", SPRAM_WIDE);
		$display(" - SPRAM_DEEP  : %d", SPRAM_DEEP);
		$display(" - FB_AW       : %d", FB_AW);
		$display(" - FB_DW       : %d", FB_DW);
		$display(" - FB_DC       : %d", FB_DC);
		$display(" - PAD_BITS    : %d", PAD_BITS);
		$display(" - IMUX_BITS   : %d", IMUX_BITS);
		$display(" - OMUX_BITS   : %d", OMUX_BITS);
	end


	// Signals
	// -------

	// Arbitration logic
	reg  arb_busy;
	reg  arb_prio;

	// Write-in control
	wire wi_req;
	reg  wi_gnt;
	wire wi_rel;

	// Read-out control
	wire ro_req;
	reg  ro_gnt;
	wire ro_rel;

	// Raw signals from the storage cells
	wire [16*SPRAM_WIDE-1:0] mem_di;
	wire [16*SPRAM_WIDE-1:0] mem_do [0:SPRAM_DEEP-1];
	wire [13:0] mem_addr;
	wire [ 3:0] mem_mask;
	wire mem_wren [0:SPRAM_DEEP-1];

	wire [16*SPRAM_WIDE-1:0] mem_do_mux;


	// Frame buffer access
	wire [FB_DW-1:0] fb_di;
	wire [FB_DW-1:0] fb_do;
	wire [FB_AW-1:0] fb_addr;
	wire fb_wren;

	reg  [FB_AW-1:0] fb_addr_r;
	reg  fb_pingpong;

	// Write-in frame buffer access
	wire [FB_AW-2:0] wifb_addr;
	wire [FB_DW-1:0] wifb_data;
	wire wifb_wren;

	// Read-out frame-buffer access
	wire [FB_AW-2:0] rofb_addr;
	wire [FB_DW-1:0] rofb_data;


	// Control
	// -------

	// Arbitration logic
	always @(posedge clk or posedge rst)
	begin
		if (rst) begin
			arb_prio <= 1'b0;
			arb_busy <= 1'b0;
			wi_gnt   <= 1'b0;
			ro_gnt   <= 1'b0;
		end else begin
			arb_busy <= (arb_busy | wi_req | ro_req) & ~(wi_rel | ro_rel);
			arb_prio <= (wi_gnt | ro_gnt) ? ro_gnt  : arb_prio;
			wi_gnt   <= ~arb_busy & wi_req & (~ro_req |  arb_prio);
			ro_gnt   <= ~arb_busy & ro_req & (~wi_req | ~arb_prio);
		end
	end

	// Double-Buffer
	always @(posedge clk or posedge rst)
		if (rst)
			fb_pingpong <= 1'b0;
		else
			fb_pingpong <= fb_pingpong ^ frame_swap;

	// Shared access
		// We assume users as well behaved and just use wren for mux control
	assign fb_di = wifb_data;
	assign rofb_data = fb_do;
	assign fb_addr = wifb_wren ? { ~fb_pingpong, wifb_addr } : { fb_pingpong, rofb_addr };
	assign fb_wren = wifb_wren;


	// Storage
	// -------

	genvar i, j;

	// Generate memory elements
	generate
		for (i=0; i<SPRAM_DEEP; i=i+1)
		begin
			for (j=0; j<SPRAM_WIDE; j=j+1)
			begin

				SB_SPRAM256KA mem_I (
					.DATAIN(mem_di[16*j+15:16*j]),
					.ADDRESS(mem_addr),
					.MASKWREN(mem_mask),
					.WREN(mem_wren[i]),
					.CHIPSELECT(1'b1),
					.CLOCK(clk),
					.STANDBY(1'b0),
					.SLEEP(1'b0),
					.POWEROFF(1'b1),
					.DATAOUT(mem_do[i][16*j+15:16*j])
				);

			end
		end
	endgenerate

	// Register address to have it available for muxing
	always @(posedge clk)
		fb_addr_r <= fb_addr;

	// Map fb_addr -> mem_addr
	assign mem_addr = { {(PAD_BITS){1'b0}}, fb_addr[FB_AW-1:OMUX_BITS+IMUX_BITS] };

	// Output muxing
	generate
		// Mux across the SPRAM used in parallel for depth (if needed)
		if (OMUX_BITS > 0)
			assign mem_do_mux = mem_do[fb_addr_r[OMUX_BITS+IMUX_BITS-1:IMUX_BITS]];
		else
			assign mem_do_mux = mem_do[0];

		// Mux down to FB_DW (if needed)
		if (IMUX_BITS > 0)
			assign fb_do = mem_do_mux[FB_DW*fb_addr_r[IMUX_BITS-1:0]+:FB_DW];
		else
			assign fb_do = mem_do_mux;
	endgenerate

	// Map fb_di -> mem_di
	generate
		for (i=0; i<(1<<IMUX_BITS); i=i+1)
			assign mem_di[FB_DW*i+:FB_DW] = fb_di;
	endgenerate

	// Input masking / write-enables
	generate
		// Write Enable
		if (OMUX_BITS > 0)
			for (i=0; i<SPRAM_DEEP; i=i+1)
				assign mem_wren[i] = fb_wren & (fb_addr[IMUX_BITS+:OMUX_BITS] == i);
		else
			assign mem_wren[0] = fb_wren;

		// Mask nibbles (if needed)
		if (IMUX_BITS == 2)
			assign mem_mask = {
				fb_addr[1:0] == 2'b11,
				fb_addr[1:0] == 2'b10,
				fb_addr[1:0] == 2'b01,
				fb_addr[1:0] == 2'b00
			};
		else if (IMUX_BITS == 1)
			assign mem_mask = {
				 fb_addr[0],  fb_addr[0],
				~fb_addr[0], ~fb_addr[0]
			};
		else
			assign mem_mask = 4'hf;
	endgenerate


	// Write-in
	// --------

	hub75_fb_writein #(
		.N_BANKS(N_BANKS),
		.N_ROWS(N_ROWS),
		.N_COLS(N_COLS),
		.BITDEPTH(BITDEPTH),
		.FB_AW(FB_AW-1),
		.FB_DW(FB_DW),
		.FB_DC(FB_DC)
	) writein_I (
		.wr_bank_addr(wr_bank_addr),
		.wr_row_addr(wr_row_addr),
		.wr_row_store(wr_row_store),
		.wr_row_rdy(wr_row_rdy),
		.wr_row_swap(wr_row_swap),
		.wr_data(wr_data),
		.wr_col_addr(wr_col_addr),
		.wr_en(wr_en),
		.ctrl_req(wi_req),
		.ctrl_gnt(wi_gnt),
		.ctrl_rel(wi_rel),
		.fb_addr(wifb_addr),
		.fb_data(wifb_data),
		.fb_wren(wifb_wren),
		.clk(clk),
		.rst(rst)
	);


	// Read-out
	// --------

	hub75_fb_readout #(
		.N_BANKS(N_BANKS),
		.N_ROWS(N_ROWS),
		.N_COLS(N_COLS),
		.N_CHANS(N_CHANS),
		.N_PLANES(N_PLANES),
		.BITDEPTH(BITDEPTH),
		.FB_AW(FB_AW-1),
		.FB_DW(FB_DW),
		.FB_DC(FB_DC)
	) readout_I (
		.rd_row_addr(rd_row_addr),
		.rd_row_load(rd_row_load),
		.rd_row_rdy(rd_row_rdy),
		.rd_row_swap(rd_row_swap),
		.rd_data(rd_data),
		.rd_col_addr(rd_col_addr),
		.rd_en(rd_en),
		.ctrl_req(ro_req),
		.ctrl_gnt(ro_gnt),
		.ctrl_rel(ro_rel),
		.fb_addr(rofb_addr),
		.fb_data(rofb_data),
		.clk(clk),
		.rst(rst)
	);

endmodule // hub75_framebuffer
