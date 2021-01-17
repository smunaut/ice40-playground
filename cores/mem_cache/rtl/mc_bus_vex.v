/*
 * mc_bus_vex.v
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

module mc_bus_vex #(
	parameter integer WB_N = 2,

	// auto
	parameter integer CL = WB_N - 1,
	parameter integer DL = (32*WB_N)- 1
)(
	// VexRiscv busses
	input  wire        i_axi_ar_valid,
	output wire        i_axi_ar_ready,
	input  wire [31:0] i_axi_ar_payload_addr,
	input  wire [ 7:0] i_axi_ar_payload_len,	// ignored, assumes 8'h07
	input  wire [ 1:0] i_axi_ar_payload_burst,	// ignored
	input  wire [ 3:0] i_axi_ar_payload_cache,	// ignored
	input  wire [ 2:0] i_axi_ar_payload_prot,	// ignored
	output wire        i_axi_r_valid,
	input  wire        i_axi_r_ready,			// ignored, assumes 1'b1
	output wire [31:0] i_axi_r_payload_data,
	output wire [ 1:0] i_axi_r_payload_resp,
	output wire        i_axi_r_payload_last,	// Fixed to zero

	input  wire        d_wb_cyc,
	input  wire        d_wb_stb,
	output reg         d_wb_ack,
	input  wire        d_wb_we,
	input  wire [29:0] d_wb_adr,
	output wire [31:0] d_wb_dat_miso,
	input  wire [31:0] d_wb_dat_mosi,
	input  wire [ 3:0] d_wb_sel,
	output wire        d_wb_err,
	input  wire [ 1:0] d_wb_bte,
	input  wire [ 2:0] d_wb_cti,

	// Peripheral wishbone bus (0x8000_0000 -> 0x8fff_ffff)
	output wire [21:0] wb_addr,
	output wire [31:0] wb_wdata,
	output wire [ 3:0] wb_wmsk,
	input  wire [DL:0] wb_rdata,
	output reg  [CL:0] wb_cyc,
	output wire        wb_we,
	input  wire [CL:0] wb_ack,

	// RAM (0x0000_0000 - 0x3fff_ffff)
	output wire [27:0] ram_addr,
	output wire [31:0] ram_wdata,
	output wire [ 3:0] ram_wmsk,
	input  wire [31:0] ram_rdata,
	output wire        ram_we,

	// Cache (0x4000_0000 - 0x7fff_0000)
		// Request output
	output wire [27:0] req_addr_pre,	// 1 cycle early

	output wire        req_valid,

	output wire        req_write,
	output wire [31:0] req_wdata,
	output wire [ 3:0] req_wmsk,

		// Response input
	input  wire        resp_ack,
	input  wire        resp_nak,
	input  wire [31:0] resp_rdata,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Global control
	localparam
		ST_IDLE     = 0,
		ST_D_CACHE  = 1,
		ST_D_RAM    = 2,
		ST_D_IO     = 3,
		ST_I_PROBE  = 4,
		ST_I_ACTIVE = 5,
		ST_I_FLUSH  = 6;

	reg  [ 2:0] state;
	reg  [ 2:0] state_nxt;

	reg  ctrl_is_ibus;
	reg  ctrl_is_dbus;
	reg  ctrl_is_cache;
	reg  ctrl_is_ram;
	reg  ctrl_is_io;

	// Data path
	reg  [31:0] rdata_io;
	wire [31:0] rdata_mux_i;
	wire [31:0] rdata_mux_d;
	wire [ 1:0] rdata_sel;

	// Address path
	wire [29:0] addr_mux;
	wire        addr_sel;

	// Instruction bus
	reg  [2:0] ib_addr_cnt;
	wire [2:0] ib_addr_lsb;
	wire       ib_addr_last;

	// Cache access
	reg req_new;

	// Peripheral access
	wire wb_cyc_i;
	reg  wb_ack_i;


	// Global control
	// --------------

	// State reg
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next-state
	always @(*)
	begin
		// Default
		state_nxt = state;

		// State transitions
		case (state)
			ST_IDLE:
				if (i_axi_ar_valid)
					state_nxt = i_axi_ar_payload_addr[30] ? ST_I_PROBE : ST_I_ACTIVE;
				else if (d_wb_cyc)
					state_nxt = d_wb_adr[29] ? ST_D_IO : (d_wb_adr[28] ? ST_D_CACHE : ST_D_RAM);

			ST_I_PROBE:
				if (resp_ack)
					state_nxt = ST_I_ACTIVE;

			ST_I_ACTIVE:
				if (ib_addr_last)
					state_nxt = ctrl_is_cache ? ST_I_FLUSH : ST_IDLE;

			ST_I_FLUSH:
				state_nxt = ST_IDLE;

			ST_D_CACHE:
				if (resp_ack)
					state_nxt = ST_IDLE;

			ST_D_RAM:
				state_nxt = ST_IDLE;

			ST_D_IO:
				if (wb_ack_i)
					state_nxt = ST_IDLE;
		endcase
	end

	// Some status
	always @(posedge clk)
	begin
		if (state == ST_IDLE) begin
			ctrl_is_ibus <=  i_axi_ar_valid;
			ctrl_is_dbus <= ~i_axi_ar_valid & d_wb_cyc;
			ctrl_is_cache = i_axi_ar_valid ?  i_axi_ar_payload_addr[30] : (d_wb_adr[29:28] == 2'b01);
			ctrl_is_ram   = i_axi_ar_valid ? ~i_axi_ar_payload_addr[30] : (d_wb_adr[29:28] == 2'b00);
			ctrl_is_io    = i_axi_ar_valid ? 1'b0 : d_wb_adr[29];
		end
	end

	// Read Data mux sel
	assign rdata_sel[1] = ctrl_is_io;
	assign rdata_sel[0] = ctrl_is_ram;

	// Address mux sel
	assign addr_sel = (state == ST_IDLE) ? ~i_axi_ar_valid : ctrl_is_dbus;


	// Data path
	// ---------

	// OR all data from IO
	always @(posedge clk)
	begin : rdata
		integer i;
		rdata_io = 32'h00000000;
		for (i=0; i<WB_N; i=i+1)
			rdata_io = rdata_io | wb_rdata[32*i+:32];
	end

	// Read muxes for IBus / DBus
	assign rdata_mux_i = rdata_sel[0] ? ram_rdata : resp_rdata;
	assign rdata_mux_d = rdata_sel[1] ? rdata_io  : rdata_mux_i;


	// Address path
	// ------------

	assign addr_mux = addr_sel ? d_wb_adr : { i_axi_ar_payload_addr[31:5], ib_addr_lsb };


	// Instruction Bus
	// ---------------

	// Address counter
	always @(posedge clk)
		ib_addr_cnt <= ib_addr_lsb;

	assign ib_addr_lsb = (state == ST_IDLE) ? 3'b000 : (ib_addr_cnt + (resp_ack | (state == ST_I_ACTIVE)));
	assign ib_addr_last = (ib_addr_cnt == 3'b111);

	assign i_axi_ar_ready = ctrl_is_cache ? (state == ST_I_FLUSH) : ib_addr_last;

	// Data channel
	assign i_axi_r_valid = (ctrl_is_ibus & ctrl_is_cache) ? resp_ack : (state == ST_I_ACTIVE);

	assign i_axi_r_payload_data = rdata_mux_i;

	assign i_axi_r_payload_resp = 2'b00;	// No errors
	assign i_axi_r_payload_last = 1'b0;		// Not used by Vex


	// Data Bus
	// --------

	always @(*)
	begin
		d_wb_ack = 0;

		case (state)
			ST_D_CACHE:
				d_wb_ack = resp_ack;
			ST_D_RAM:
				d_wb_ack = 1'b1;
			ST_D_IO:
				d_wb_ack = wb_ack_i;
		endcase
	end

	assign d_wb_dat_miso = rdata_mux_d;
	assign d_wb_err = 1'b0;					// No errors


	// Cache access
	// ------------

	assign req_addr_pre =  addr_mux[27:0];
	assign req_valid    =  req_new | resp_nak | ((state == ST_I_ACTIVE) & ctrl_is_cache);
	assign req_write    =  d_wb_we & (state == ST_D_CACHE);
	assign req_wdata    =  d_wb_dat_mosi;
	assign req_wmsk     = ~d_wb_sel;

	always @(posedge clk)
		req_new <= (state == ST_IDLE) && ((state_nxt == ST_I_PROBE) || (state_nxt == ST_D_CACHE));


	// RAM access
	// ----------

	assign ram_addr  =  addr_mux[27:0];
	assign ram_wdata =  d_wb_dat_mosi;
	assign ram_wmsk  = ~d_wb_sel;
	assign ram_we    =  d_wb_we & (state == ST_D_RAM);


	// Peripheral access
	// -----------------

	assign wb_addr  =  d_wb_adr[21:0];
	assign wb_wdata =  d_wb_dat_mosi;
	assign wb_wmsk  = ~d_wb_sel;
	assign wb_we    =  d_wb_we;

	assign wb_cyc_i = (state == ST_IDLE) && (state_nxt == ST_D_IO);

	always @(posedge clk)
		wb_ack_i <= |wb_ack;

	always @(posedge clk)
	begin : wb_cyc_proc
		integer i;
		if (rst)
			wb_cyc <= 0;
		else
			for (i=0; i<WB_N; i=i+1)
				wb_cyc[i] <= (wb_cyc[i] & ~wb_ack[i]) | (wb_cyc_i & (d_wb_adr[25:22] == i));
	end

endmodule
