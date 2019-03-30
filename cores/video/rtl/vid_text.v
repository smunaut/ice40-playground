/*
 * vid_text.v
 *
 * vim: ts=4 sw=4
 *
 * Video Text Mode generator
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

module vid_text (
	// Timing input
	input  wire vid_active_0,
	input  wire vid_h_first_0,
	input  wire vid_h_last_0,
	input  wire vid_v_first_0,
	input  wire vid_v_last_0,

	// Pixel output
	output wire [15:0] vid_pix0_11,
	output wire [15:0] vid_pix1_11,

	// Bus interface
	input  wire [15:0] bus_addr,
	input  wire [15:0] bus_din,
	output wire [15:0] bus_dout,
	input  wire bus_cyc,
	input  wire bus_we,
	output wire bus_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Signals
	// -------

	// Char look-up
	reg  [10:0] cl_y_cnt_0;

	reg  [ 9:0] cl_y_cnt_1;
	reg  [ 9:0] cl_x_cnt_1;
	reg  cl_fetch_1;
	reg  cl_valid_1;

	wire cl_stb_3;
	wire cl_valid_3;

	wire [15:0] cl_char_4;

	// Glyph look-up
	reg  [ 1:0] gl_x_4;
	wire [ 3:0] gl_y_4;
	reg  gl_fetch_4;

	wire gl_flip_x_4;
	wire gl_flip_y_4;

	wire gl_flip_x_7;
	wire [ 3:0] gl_pixa_7;
	wire [ 3:0] gl_pixb_7;

	reg  [ 3:0] gl_pix0_8;
	reg  [ 3:0] gl_pix1_8;
	wire [ 7:0] gl_attrs_8;
	wire gl_valid_8;

	// RAM fetch interfaces
	wire [13:0] sm_addr_1;
	wire [15:0] sm_data_4;
	wire sm_read_1;

	wire [13:0] gm_addr_4;
	wire [15:0] gm_data_7;
	wire gm_read_4;

	wire [ 7:0] cm_addr0_8;
	wire [ 7:0] cm_addr1_8;
	wire [15:0] cm_data0_11;
	wire [15:0] cm_data1_11;
	wire cm_read_8;
	wire cm_zero_8;

	// RAM bus interfaces
	wire smb_ready;
	reg  smb_read;
	reg  smb_zero;
	reg  smb_write;

	wire gmb_ready;
	reg  gmb_read;
	reg  gmb_zero;
	reg  gmb_write;

	wire cmb_ready;
	reg  cmb_read;
	reg  cmb_zero;
	reg  cmb_write;

	wire [15:0] smb_dout;
	wire [15:0] gmb_dout;
	wire [15:0] cmb_dout;

	// Bus interface
	reg  smb_req;
	wire smb_clear;

	reg  gmb_req;
	wire gmb_clear;

	reg  cmb_req;
	wire cmb_clear;

	reg  bus_ack_wait;
	wire bus_req_ok;
	reg  [2:0] bus_req_ok_dly;


	// Char lookup
	// -----------

	// Y counter
	always @(posedge clk)
		if (vid_v_first_0)
			// Start at -27 to center the 1024 in the 1080 of full HD
			cl_y_cnt_0  <= 11'h7e5;
		else
			cl_y_cnt_0  <= cl_y_cnt_0 + vid_h_last_0;

	always @(posedge clk)
		cl_y_cnt_1 <= cl_y_cnt_0[9:0];

	// X counter
	always @(posedge clk)
		if (vid_h_first_0)
			cl_x_cnt_1  <= 0;
		else
			cl_x_cnt_1  <= cl_x_cnt_1 + 1;

	// Valid flag
	always @(posedge clk)
		cl_valid_1 <= ~cl_y_cnt_0[10] & vid_active_0;

	// Fetch
	always @(posedge clk)
		cl_fetch_1 <= ~cl_y_cnt_0[10] & vid_active_0 & (vid_h_first_0 | (cl_x_cnt_1[1:0] == 3'b11));

	// RAM interface
	assign sm_addr_1 = { cl_y_cnt_1[9:4], cl_x_cnt_1[9:2] };
	assign sm_read_1 = cl_fetch_1;

	assign cl_char_4 = sm_data_4;

	// Provide some sync signals to the next stage
	delay_bit #(2) dly_stb13   ( .d(cl_fetch_1), .q(cl_stb_3),   .clk(clk) );
	delay_bit #(2) dly_valid13 ( .d(cl_valid_1), .q(cl_valid_3), .clk(clk) );


	// Glyph lookup
	// ------------

	// X Counter
	always @(posedge clk)
		if (cl_stb_3)
			gl_x_4 <= 2'b00;
		else
			gl_x_4 <= gl_x_4 + 1;

	// Y counter
	delay_bus #(3, 4) dly_y_cnt ( .d(cl_y_cnt_1[3:0]), .q(gl_y_4), .clk(clk) );

	// Fetch
	always @(posedge clk)
		gl_fetch_4 <= cl_stb_3 | gl_x_4[0];

	// X/Y flips attributes
	assign gl_flip_y_4 = cl_char_4[10] & ~cl_char_4[9];
	assign gl_flip_x_4 = cl_char_4[11] & ~cl_char_4[9];

	// RAM interface
	assign gm_addr_4 = {
		cl_char_4[8:0],
		gl_y_4    ^ { 4{gl_flip_y_4} },		// Handle Y-flip
		gl_x_4[1] ^     gl_flip_x_4			// Handle X-flip
	};
	assign gm_read_4 = gl_fetch_4;

	// Delay control signal for the mux
	delay_bit #(3) dly_flip_h ( .d(gl_flip_x_4), .q(gl_flip_x_7), .clk(clk) );

	// Mux
	assign gl_pixa_7  = (gl_x_4[0] ^ gl_flip_x_7) ? gm_data_7[11: 8] : gm_data_7[3:0];
	assign gl_pixb_7  = (gl_x_4[0] ^ gl_flip_x_7) ? gm_data_7[15:12] : gm_data_7[7:4];

	always @(posedge clk)
	begin
		gl_pix0_8 <= gl_flip_x_7 ? gl_pixa_7 : gl_pixb_7;
		gl_pix1_8 <= gl_flip_x_7 ? gl_pixb_7 : gl_pixa_7;
	end

	// Forward the attributes & validity to the next stage
	delay_bit #(5) dly_valid38  ( .d(cl_valid_3),      .q(gl_valid_8), .clk(clk) );
	delay_bus #(4, 8) dly_attrs ( .d(cl_char_4[15:8]), .q(gl_attrs_8), .clk(clk) );


	// Color lookup
	// ------------

	// RAM interface
	vid_color_map cmap0_I (
		.attrs(gl_attrs_8),
		.glyph(gl_pix0_8),
		.color(cm_addr0_8)
	);

	vid_color_map cmap1_I (
		.attrs(gl_attrs_8),
		.glyph(gl_pix1_8),
		.color(cm_addr1_8)
	);

	assign cm_read_8  = gl_valid_8;
	assign cm_zero_8  = ~gl_valid_8;

	assign vid_pix0_11 = cm_data0_11;
	assign vid_pix1_11 = cm_data1_11;


	// Memories
	// --------

	// Screen memory (contains chars and attributes)
	vid_shared_ram #(
		.TYPE("SPRAM")
	) screen_mem_I (
		.p_addr_0(sm_addr_1),
		.p_read_0(sm_read_1),
		.p_zero_0(1'b0),
		.p_dout_3(sm_data_4),
		.s_addr_0(bus_addr[13:0]),
		.s_din_0(bus_din),
		.s_read_0(smb_read),
		.s_zero_0(smb_zero),
		.s_write_0(smb_write),
		.s_dout_3(smb_dout),
		.s_ready_0(smb_ready),
		.clk(clk),
		.rst(rst)
	);

	// Glyph memory (contains bitmap for each character)
	vid_shared_ram #(
		.TYPE("SPRAM")
	) glyph_mem_I (
		.p_addr_0(gm_addr_4),
		.p_read_0(gm_read_4),
		.p_zero_0(1'b0),
		.p_dout_3(gm_data_7),
		.s_addr_0(bus_addr[13:0]),
		.s_din_0(bus_din),
		.s_read_0(gmb_read),
		.s_zero_0(gmb_zero),
		.s_write_0(gmb_write),
		.s_dout_3(gmb_dout),
		.s_ready_0(gmb_ready),
		.clk(clk),
		.rst(rst)
	);

	// Palette memory (contain mapping to real color)
	// (duplicated to allow 2 looks ups in //)
	vid_shared_ram #(
		.TYPE("EBR")
	) color_mem_a_I (
		.p_addr_0(cm_addr0_8),
		.p_read_0(cm_read_8),
		.p_zero_0(cm_zero_8),
		.p_dout_3(cm_data0_11),
		.s_addr_0(bus_addr[7:0]),
		.s_din_0(bus_din),
		.s_read_0(cmb_read),
		.s_zero_0(cmb_zero),
		.s_write_0(cmb_write),
		.s_dout_3(cmb_dout),
		.s_ready_0(cmb_ready),
		.clk(clk),
		.rst(rst)
	);

	vid_shared_ram #(
		.TYPE("EBR")
	) color_mem_b_I (
		.p_addr_0(cm_addr1_8),
		.p_read_0(cm_read_8),
		.p_zero_0(cm_zero_8),
		.p_dout_3(cm_data1_11),
		.s_addr_0(bus_addr[7:0]),
		.s_din_0(bus_din),
		.s_read_0(1'b0),
		.s_zero_0(1'b0),
		.s_write_0(cmb_write),
		.s_dout_3(),
		.s_ready_0(),
		.clk(clk),
		.rst(rst)
	);


	// External bus interface
	// ----------------------

	// Request lines from the various memories
	always @(posedge clk)
		if (smb_clear) begin
			smb_read  <= 1'b0;
			smb_zero  <= 1'b0;
			smb_write <= 1'b0;
			smb_req   <= 1'b0;
		end else begin
			smb_read  <= (bus_addr[15:14] == 2'b10) & ~bus_we;
			smb_zero  <= (bus_addr[15:14] != 2'b10);
			smb_write <= (bus_addr[15:14] == 2'b10) & bus_we;
			smb_req   <= (bus_addr[15:14] == 2'b10);
		end

	always @(posedge clk)
		if (gmb_clear) begin
			gmb_read  <= 1'b0;
			gmb_zero  <= 1'b0;
			gmb_write <= 1'b0;
			gmb_req   <= 1'b0;
		end else begin
			gmb_read  <= (bus_addr[15:14] == 2'b11) & ~bus_we;
			gmb_zero  <= (bus_addr[15:14] != 2'b11);
			gmb_write <= (bus_addr[15:14] == 2'b11) & bus_we;
			gmb_req   <= (bus_addr[15:14] == 2'b11);
		end

	always @(posedge clk)
		if (cmb_clear) begin
			cmb_read  <= 1'b0;
			cmb_zero  <= 1'b0;
			cmb_write <= 1'b0;
			cmb_req   <= 1'b0;
		end else begin
			cmb_read  <= (bus_addr[15:13] == 3'b011) & ~bus_we;
			cmb_zero  <= (bus_addr[15:13] != 3'b011);
			cmb_write <= (bus_addr[15:13] == 3'b011) & bus_we;
			cmb_req   <= (bus_addr[15:13] == 3'b011);
		end

	// Condition to force the requests to zero :
	//  no access needed, ack pending or this cycle went through
	assign smb_clear = ~bus_cyc | bus_ack_wait | (smb_req & smb_ready);
	assign gmb_clear = ~bus_cyc | bus_ack_wait | (gmb_req & gmb_ready);
	assign cmb_clear = ~bus_cyc | bus_ack_wait | (cmb_req & cmb_ready);

	// Track when request are accepted by the RAM
	assign bus_req_ok = (smb_req & smb_ready) | (gmb_req & gmb_ready) | (cmb_req & cmb_ready);

	always @(posedge clk)
		bus_req_ok_dly <= { bus_req_ok_dly[1:0], bus_req_ok & ~bus_we };

	// ACK wait state tracking
	always @(posedge clk)
		if (rst)
			bus_ack_wait <= 1'b0;
		else
			bus_ack_wait <= ((bus_ack_wait & ~bus_we) | bus_req_ok) & ~bus_req_ok_dly[2];

	// Bus Ack
	assign bus_ack = bus_ack_wait & (bus_we | bus_req_ok_dly[2]);

	// Output is simply the OR of all memory since we force them to zero if
	// they're not accessed
	assign bus_dout = smb_dout | gmb_dout | cmb_dout;

endmodule // vid_text


module vid_color_map (
	input  wire [7:0] attrs,
	input  wire [3:0] glyph,
	output reg  [7:0] color
);

	always @(*)
	begin
		if (attrs[1]) begin
			if (glyph[3:2] == 2'b00)
				color <= { 4'b0000, glyph[1], glyph[0] ? attrs[7:5] : attrs[4:2] };
			else
				color <= { 4'b0001, glyph };
		end else begin
			color <= { attrs[7:4], glyph };
		end
	end

endmodule
