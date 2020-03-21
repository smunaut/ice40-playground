/*
 * mc_core.v
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

module mc_core #(
	parameter integer N_WAYS     =  4,
	parameter integer ADDR_WIDTH = 24,	/* Word address, 64 Mbytes */
	parameter integer CACHE_LINE = 64,
	parameter integer CACHE_SIZE = 64,	/* 64k or 128k */

	// auto
	parameter integer BL = ADDR_WIDTH - 1
)(
	// Request input
	input  wire [BL:0] req_addr_pre,	// 1 cycle early

	input  wire        req_valid,

	input  wire        req_write,
	input  wire [31:0] req_wdata,
	input  wire [ 3:0] req_wmask,

	// Response output (1 cycle later)
	output reg         resp_ack,
	output reg         resp_nak,
	output wire [31:0] resp_rdata,

	// Memory controller interface
	output wire [BL:0] mi_addr,
	output wire [ 6:0] mi_len,
	output wire        mi_rw,
	output wire        mi_valid,
	input  wire        mi_ready,

	output wire [31:0] mi_wdata,
	input  wire        mi_wack,
	input  wire        mi_wlast,

	input  wire [31:0] mi_rdata,
	input  wire        mi_rstb,
	input  wire        mi_rlast,

	// Common
	input  wire clk,
	input  wire rst
);

	genvar i;

	// Constants
	// ---------

	localparam integer SPRAM_ADDR_WIDTH = (CACHE_SIZE == 128) ? 15 : 14;
	localparam integer SL = SPRAM_ADDR_WIDTH - 1;

	localparam integer OFS_WIDTH = $clog2(CACHE_LINE) - 2;
	localparam integer IDX_WIDTH = SPRAM_ADDR_WIDTH - $clog2(N_WAYS) - OFS_WIDTH;
	localparam integer TAG_WIDTH = ADDR_WIDTH - (IDX_WIDTH + OFS_WIDTH);
	localparam integer AGE_WIDTH = $clog2(N_WAYS);
	localparam integer WAY_WIDTH = $clog2(N_WAYS);

	localparam integer OL = OFS_WIDTH - 1;
	localparam integer IL = IDX_WIDTH - 1;
	localparam integer TL = TAG_WIDTH - 1;
	localparam integer AL = AGE_WIDTH - 1;
	localparam integer WL = WAY_WIDTH - 1;

	initial begin
		$display("Memory cache config :");
		$display(" - %d ways", N_WAYS);
		$display(" - %d kbytes cache", CACHE_SIZE);
		$display(" - %d bytes cache lines", CACHE_LINE);
		$display(" - %d Mbytes address space", 1 << (ADDR_WIDTH - 18));
		$display(" - %d/%d/%d address split", TAG_WIDTH, IDX_WIDTH, OFS_WIDTH);
	end


	localparam [1:0]
		ST_BUS_MODE = 0,
		ST_MEMIF_ISSUE_WRITE = 1,
		ST_MEMIF_ISSUE_READ = 2,
		ST_MEMIF_WAIT = 3;


	// Signals
	// -------

	// Control
	reg  [1:0]  ctrl_state;
	reg  [1:0]  ctrl_state_nxt;

	wire        ctrl_bus_mode;
	wire        ctrl_tagram_we;

	// Offset counter
	reg  [OL:0] cnt_ofs;
	wire        cnt_ofs_rst;
	wire        cnt_ofs_inc;

	// Requests
	wire [IL:0] req_addr_pre_idx;

	reg  [BL:0] req_addr;
	wire [TL:0] req_addr_tag;
	wire [IL:0] req_addr_idx;
	wire [OL:0] req_addr_ofs;

	// Tag Memory
	wire        way_valid[0:N_WAYS-1];
	wire        way_dirty[0:N_WAYS-1];
	wire [AL:0] way_age[0:N_WAYS-1];
	wire [TL:0] way_tag[0:N_WAYS-1];

	reg         way_valid_nxt[0:N_WAYS-1];
	reg         way_valid_we[0:N_WAYS-1];

	reg         way_dirty_nxt[0:N_WAYS-1];
	reg         way_dirty_we[0:N_WAYS-1];

	reg  [AL:0] way_age_nxt[0:N_WAYS-1];
	wire        way_age_we;

	wire [TL:0] way_tag_nxt;
	reg         way_tag_we[0:N_WAYS-1];

	// Pre-compute on tag mem data
	wire [N_WAYS-1:0] way_match;	// Needs to be vector to use unary OR
	wire [AL:0] way_match_age[0:N_WAYS-1];

	// Lookup
	wire        lu_miss;
	wire        lu_hit;
	reg  [WL:0] lu_hit_way;
	reg  [AL:0] lu_hit_age;

	// Eviction
	reg  [WL:0] ev_way;
	wire        ev_valid;
	wire        ev_dirty;
	wire [TL:0] ev_tag;

	reg  [WL:0] ev_way_r;
	reg         ev_valid_r;
	reg  [TL:0] ev_tag_r;

	// Data memory
	reg  [SL:0] dm_addr;
	wire [31:0] dm_rdata;
	reg         dm_re;
	reg  [31:0] dm_wdata;
	wire [ 7:0] dm_wmask_nibble;
	reg  [ 3:0] dm_wmask;
	reg         dm_we;


	// Control
	// -------

	// FSM state register
	always @(posedge clk or posedge rst)
		if (rst)
			ctrl_state <= ST_BUS_MODE;
		else
			ctrl_state <= ctrl_state_nxt;

	// FSM next-state logic
	always @(*)
	begin
		// Default is not to move
		ctrl_state_nxt = ctrl_state;

		// State change logic
		case (ctrl_state)
			ST_BUS_MODE:
				if (lu_miss)
					ctrl_state_nxt = ev_dirty ? ST_MEMIF_ISSUE_WRITE : ST_MEMIF_ISSUE_READ;

			ST_MEMIF_ISSUE_WRITE:
				if (mi_ready)
					ctrl_state_nxt = ST_MEMIF_ISSUE_READ;

			ST_MEMIF_ISSUE_READ:
				if (mi_ready)
					ctrl_state_nxt = ST_MEMIF_WAIT;

			ST_MEMIF_WAIT:
				if (mi_rstb && mi_rlast)
					ctrl_state_nxt = ST_BUS_MODE;
		endcase
	end

	// State conditions
	assign ctrl_bus_mode = ctrl_state == ST_BUS_MODE;


	// Memory interface
	// ----------------

	// Issue commands
	assign mi_addr  = {
		(ctrl_state == ST_MEMIF_ISSUE_WRITE) ? ev_tag_r : req_addr_tag,
		req_addr_idx,
		{OFS_WIDTH{1'b0}}
	};
	assign mi_len   = (CACHE_LINE / 4) - 1;
	assign mi_rw    = (ctrl_state == ST_MEMIF_ISSUE_READ);
	assign mi_valid = (ctrl_state == ST_MEMIF_ISSUE_WRITE) || (ctrl_state == ST_MEMIF_ISSUE_READ);

	// Read data path
	assign mi_wdata = dm_rdata;

	// Offset counter
	always @(posedge clk)
		if (cnt_ofs_rst)
			cnt_ofs <= 0;
		else if (cnt_ofs_inc)
			cnt_ofs <= cnt_ofs + 1;

	assign cnt_ofs_rst = ctrl_bus_mode | (mi_wack & mi_wlast);
	assign cnt_ofs_inc = mi_rstb | mi_wack | (mi_ready & (ctrl_state == ST_MEMIF_ISSUE_WRITE));


	// Request
	// -------

	// Extract index from pre-address for tag memory lookup
	assign req_addr_pre_idx = req_addr_pre[IDX_WIDTH+OFS_WIDTH-1:OFS_WIDTH];

	// Register the pre-address, _only_ if in bus mode for next cycle
	always @(posedge clk)
		if (ctrl_state_nxt == ST_BUS_MODE)
			req_addr <= req_addr_pre;

	// Split address
	assign { req_addr_tag, req_addr_idx, req_addr_ofs } = req_addr;


	// Tag Memory
	// ----------

	// Blocks
	generate
		for (i=0; i<N_WAYS; i=i+1)
			mc_tag_ram #(
				.IDX_WIDTH(IDX_WIDTH),
				.TAG_WIDTH(TAG_WIDTH),
				.AGE_WIDTH(AGE_WIDTH)
			) tag_ram_I (
				.w_idx     (req_addr_idx),
				.w_ena     (ctrl_tagram_we),
				.w_valid_we(way_valid_we[i]),
				.w_valid   (way_valid_nxt[i]),
				.w_dirty_we(way_dirty_we[i]),
				.w_dirty   (way_dirty_nxt[i]),
				.w_age_we  (way_age_we),
				.w_age     (way_age_nxt[i]),
				.w_tag_we  (way_tag_we[i]),
				.w_tag     (way_tag_nxt),
				.r_ena     (ctrl_state_nxt == ST_BUS_MODE),
				.r_idx     (req_addr_pre_idx),
				.r_valid   (way_valid[i]),
				.r_dirty   (way_dirty[i]),
				.r_age     (way_age[i]),
				.r_tag     (way_tag[i]),
				.clk       (clk)
			);
	endgenerate


	// Lookup logic
	// ------------

	// Per-way precompute
	generate
		for (i=0; i<N_WAYS; i=i+1)
		begin
//`define GENERIC
`ifdef GENERIC
			assign way_match[i] = way_valid[i] & (way_tag[i] == req_addr_tag);
`else
			// Comparator
			mc_tag_match #(
				.TAG_WIDTH(TAG_WIDTH)
			) tag_match_I (
				.ref(req_addr_tag),
				.tag(way_tag[i]),
				.valid(way_valid[i]),
				.match(way_match[i])
			);
`endif

			// Age
			assign way_match_age[i] = way_match[i] ? way_age[i] : 2'b00;
		end
	endgenerate

	// Hit / Miss
	assign lu_miss = ctrl_bus_mode & req_valid & ~|way_match;
	assign lu_hit  = ctrl_bus_mode & req_valid &  |way_match;

	// Hit way and age
	always @(*)
	begin : hit
		integer w;

		// Any way that's a match (should be only one !)
		lu_hit_way = 0;
		for (w=1; w<N_WAYS; w=w+1)
			if (way_match[w])
				lu_hit_way = w;

		// Or all the pre-masked values
		lu_hit_age = 0;
		for (w=0; w<N_WAYS; w=w+1)
			lu_hit_age = lu_hit_age | way_match_age[w];
	end


	// Eviction logic
	// --------------

	// Select way to evict
	always @(*)
	begin : evict
		integer w;

		// Find a way that's either invalid or "oldest"
		ev_way = 0;
		for (w=1; w<N_WAYS; w=w+1)
			if (!way_valid[w] || (way_age[w] == (N_WAYS-1)))
				ev_way = w;
	end

	// Muxes for tag and dirty flags
	assign ev_valid = way_valid[ev_way];
	assign ev_dirty = way_dirty[ev_way];
	assign ev_tag   = way_tag[ev_way];

	// Save them for mem mode
	always @(posedge clk)
	begin
		if (ctrl_bus_mode) begin
			ev_way_r   <= ev_way;
			ev_valid_r <= ev_valid;
			ev_tag_r   <= ev_tag;
		end
	end


	// Tag Memory update logic
	// -----------------------

	// Global write enable
	assign ctrl_tagram_we = lu_hit | ((ctrl_state == ST_MEMIF_ISSUE_READ) & mi_ready);

	// Flag update
	always @(*)
	begin : dirty_next
		integer w;

		if (ctrl_bus_mode)
			// Bus Mode
			for (w=0; w<N_WAYS; w=w+1) begin
				// Valid
				way_valid_nxt[w] = 1'b0;
				way_valid_we[w]  = 1'b0;

				// Dirty: Set on write
				way_dirty_nxt[w] = 1'b1;
				way_dirty_we[w]  = req_valid & req_write & way_match[w];
			end

		else
			// Cache line load
			for (w=0; w<N_WAYS; w=w+1) begin
				// Valid
				way_valid_nxt[w] = 1'b1;
				way_valid_we[w]  = (w == ev_way_r);

				// Dirty: Set on write
				way_dirty_nxt[w] = 1'b0;
				way_dirty_we[w]  = (w == ev_way_r);
			end
	end

	// Age update (on hit)
	assign way_age_we = 1'b1; // ctrl_bus_mode;

	always @(*)
	begin : age_next
		integer w;

		if (ctrl_bus_mode)
		begin
			// Next age is 0 for the hit, max for invalid and increment if current
			// age is lower than the age of the hit way
			for (w=0; w<N_WAYS; w=w+1)
				if (!way_valid[w])
					way_age_nxt[w] = N_WAYS - 1;
				else if (way_match[w])
					way_age_nxt[w] = 0;
				else if (way_age[w] < lu_hit_age)
					way_age_nxt[w] = way_age[w] + 1;
				else
					way_age_nxt[w] = way_age[w];
		end else begin
			for (w=0; w<N_WAYS; w=w+1)
				if (!way_valid[w])
					way_age_nxt[w] = N_WAYS - 1;
				else if (w == ev_way_r)
					way_age_nxt[w] = 0;
				else
					way_age_nxt[w] = way_age[w] + ev_valid_r;
		end

/*
		// Next age is 0 for the hit, max for invalid and increment if current
		// age is lower than the age of the hit way
		for (w=0; w<N_WAYS; w=w+1)
			if (!way_valid[w])
				way_age_nxt[w] = N_WAYS - 1;
			else if (way_match[w])
				way_age_nxt[w] = 0;
			else if (way_age[w] < lu_hit_age)
				way_age_nxt[w] = way_age[w] + 1;
			else
				way_age_nxt[w] = way_age[w];
*/
	end

	// Tag update
	assign way_tag_nxt = req_addr_tag;

	always @(*)
	begin : tag_next
		integer w;

		for (w=0; w<N_WAYS; w=w+1)
			way_tag_we[w] = (ctrl_state == ST_MEMIF_ISSUE_READ) && (w == ev_way_r);
	end


	// Data Memory
	// -----------

	// Mem-block
	ice40_spram_gen #(
		.ADDR_WIDTH(SPRAM_ADDR_WIDTH),
		.DATA_WIDTH(32)
	) data_ram_I (
		.addr(dm_addr),
		.rd_data(dm_rdata),
		.rd_ena(dm_re),
		.wr_data(dm_wdata),
		.wr_mask(dm_wmask_nibble),
		.wr_ena(dm_we),
		.clk(clk)
	);

	// Extend mask to nibbles
	assign dm_wmask_nibble = {
		dm_wmask[3], dm_wmask[3],
		dm_wmask[2], dm_wmask[2],
		dm_wmask[1], dm_wmask[1],
		dm_wmask[0], dm_wmask[0]
	};

	// Muxing
	always @(*)
	begin
		if (ctrl_bus_mode) begin
			// Bus Access
			dm_addr  = { lu_hit_way, req_addr_idx, req_addr_ofs };
			dm_re    = 1'b1;
			dm_wdata = req_wdata;
			dm_wmask = req_wmask;
			dm_we    = req_write & lu_hit;
		end else begin
			// Read or Write access to/from memory interface
			dm_addr  = { ev_way_r, req_addr_idx, cnt_ofs };
			dm_re    = cnt_ofs_inc;
			dm_wdata = mi_rdata;
			dm_wmask = 4'h0;
			dm_we    = mi_rstb;
		end
	end


	// Responses
	// ---------

	// Data is direct from the data memory
	assign resp_rdata = dm_rdata;

	// ACK / NAK
	always @(posedge clk or posedge rst)
		if (rst) begin
			resp_ack <= 1'b0;
			resp_nak <= 1'b0;
		end else begin
			resp_ack <= lu_hit;
			resp_nak <= lu_miss | (req_valid & ~ctrl_bus_mode);
		end

endmodule
