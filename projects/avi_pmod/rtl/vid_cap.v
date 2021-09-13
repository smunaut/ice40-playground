`default_nettype none

module vid_cap (
	// Video data
	input  wire  [7:0] vid_data,
	input  wire        vid_clk,

	// QPI Memory interface
	output reg  [21:0] mi_addr,
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

	// Wishbone
	input  wire [15:0] wb_addr,
	input  wire [31:0] wb_wdata,
	output wire [31:0] wb_rdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Capture sync detect
	reg  [31:0] vid_data_pipe;

	reg         vid_sync_mark;
	wire        vid_sync_f0v1h1;
	wire        vid_sync_f0v0h1;

	// Pixel capture control
	reg         wr_req;
	reg         wr_armed;
	reg         wr_active;

	// Video RAM buffer
	reg   [9:0] vram_wr_addr;
	wire  [7:0] vram_wr_data;
	wire        vram_wr_ena;

	reg   [7:0] vram_rd_addr;
	wire [31:0] vram_rd_data_mix;
	wire [31:0] vram_rd_data;
	wire        vram_rd_ena;

	// Read buffer
	reg   [7:0] rbuf_wr_addr;
	wire [31:0] rbuf_wr_data;
	wire        rbuf_wr_ena;

	wire  [7:0] rbuf_rd_addr;
	wire [31:0] rbuf_rd_data;

	// Capture control
	localparam [2:0]
		ST_IDLE				= 0,
		ST_CAP_WAIT			= 1,	// Wait for capture to fill VRAM
		ST_CAP_FLUSH_CMD	= 2,	// Issue flush command
		ST_CAP_FLUSH_WAIT	= 3,	// Wait for flush completion
		ST_READ_CMD         = 4,
		ST_READ_WAIT        = 5,
		ST_END				= 7;

	reg   [2:0] state;
	reg   [2:0] state_nxt;

	wire        cap_start;
	wire        cap_done;
	reg         cap_run;
	reg         cap_last;
	reg   [2:0] cap_buf_sync;
	wire        cap_buf;
	reg         cap_flip;
	reg         cap_flip_r;

	// Bus interface
	wire        read_start;
	wire [21:0] read_addr;

	wire bus_clr;
	reg  bus_we_csr;
	reg  bus_we_eaddr;
	reg  bus_we_raddr;


	// Pixel Capture
	// --------------

	// Sync detection
	always @(posedge vid_clk)
	begin
		vid_data_pipe[31:0] <= { vid_data_pipe[23:0], vid_data };
		vid_sync_mark  <= ({ vid_data_pipe[15:0], vid_data } == 24'hff0000);
	end

	assign vid_sync_f0v1h1 = vid_sync_mark & (vid_data == 8'hb6);
	assign vid_sync_f0v0h1 = vid_sync_mark & (vid_data == 8'h9d);

	// Write start requested
	always @(posedge vid_clk or negedge cap_run)
		if (~cap_run)
			wr_req <= 1'b0;
		else
			wr_req <= 1'b1;

	// Armed once we see vsync
	always @(posedge vid_clk or negedge cap_run)
		if (~cap_run)
			wr_armed <= 1'b0;
		else
			wr_armed <= wr_armed | (wr_req & vid_sync_f0v1h1);

	// Active once armed and we see first active line
	always @(posedge vid_clk or negedge cap_run)
		if (~cap_run)
			wr_active <= 1'b0;
		else
			wr_active <= wr_active | (wr_armed & vid_sync_f0v0h1);

	// Write to VRAM buffer
	always @(posedge vid_clk)
		if (~wr_active)
			vram_wr_addr <= 0;
		else
			vram_wr_addr <= vram_wr_addr + 1;

	assign vram_wr_data = vid_data_pipe[31:24];
	assign vram_wr_ena  = wr_active;


	// Video RAM buffer
	// ----------------

	ice40_ebr #(
		.READ_MODE (0),	// 256x16
		.WRITE_MODE(2)	// 1024x4
	) vid_ram_I[1:0] (
		.wr_addr (vram_wr_addr),
		.wr_data (vram_wr_data),
		.wr_mask (4'h0),
		.wr_ena  (vram_wr_ena),
		.wr_clk  (vid_clk),
		.rd_addr (vram_rd_addr),
		.rd_data (vram_rd_data_mix),
		.rd_ena  (vram_rd_ena),
		.rd_clk  (clk)
	);

	assign vram_rd_data = {
		vram_rd_data_mix[31:28], vram_rd_data_mix[15:12],
		vram_rd_data_mix[27:24], vram_rd_data_mix[11: 8],
		vram_rd_data_mix[23:20], vram_rd_data_mix[ 7: 4],
		vram_rd_data_mix[19:16], vram_rd_data_mix[ 3: 0]
	};


	// Read buffer
	// -----------

	ice40_ebr #(
		.READ_MODE (0),	// 256x16
		.WRITE_MODE(0)	// 256x16
	) rbuf_I[1:0] (
		.wr_addr (rbuf_wr_addr),
		.wr_data (rbuf_wr_data),
		.wr_mask (32'h00000000),
		.wr_ena  (rbuf_wr_ena),
		.wr_clk  (clk),
		.rd_addr (rbuf_rd_addr),
		.rd_data (rbuf_rd_data),
		.rd_ena  (1'b1),
		.rd_clk  (clk)
	);


	// State machine
	// -------------

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next state
	always @(*)
	begin
		// Default is no-change
		state_nxt = state;

		// State transitions
		case (state)
			ST_IDLE:
				if (cap_start)
					state_nxt = ST_CAP_WAIT;
				else if (read_start)
					state_nxt = ST_READ_CMD;

			ST_CAP_WAIT:
				if (cap_flip)
					state_nxt = ST_CAP_FLUSH_CMD;

			ST_CAP_FLUSH_CMD:
				if (mi_ready)
					state_nxt = ST_CAP_FLUSH_WAIT;

			ST_CAP_FLUSH_WAIT:
				if (mi_wack & mi_wlast)
					state_nxt = cap_last ? ST_IDLE : ST_CAP_WAIT;

			ST_READ_CMD:
				if (mi_ready)
					state_nxt = ST_READ_WAIT;

			ST_READ_WAIT:
				if (mi_rstb & mi_rlast)
					state_nxt = ST_IDLE;
		endcase
	end


	// Other control
	// -------------

	// Running state
	always @(posedge clk)
	begin
		if (rst)
			cap_run <= 1'b0;
		else
			cap_run <= (cap_run & ~cap_done) | cap_start;
	end

	// Monitor the buffer used on video side
	always @(posedge clk)
	begin
		cap_buf_sync <= { cap_buf_sync[1:0], vram_wr_addr[9] };
		cap_flip     <= cap_buf_sync[2] ^ cap_buf_sync[1];
		cap_flip_r   <= cap_flip;
	end

	assign cap_buf = cap_buf_sync[2];

	// Last when filled
	always @(posedge clk)
		cap_last <= mi_addr == 22'h200000;

	// Done when acking last
	assign cap_done = mi_wack & mi_wlast & cap_last;


	// PSRAM access
	// ------------

	// PSRAM address
	always @(posedge clk)
	begin
		if (cap_start)
			// Reset to 0 on capture start
			mi_addr <= 22'h000000;
		else if (read_start)
			mi_addr <= read_addr;
		else if (mi_valid & mi_ready)
			// Increment by burst size when command is accepted
			// (128 words = 512 bytes)
			mi_addr <= mi_addr + 22'd128;
	end

	// Command
	assign mi_len   = 7'd127;	// 128 words
	assign mi_rw    = (state == ST_READ_CMD);
	assign mi_valid = (state == ST_CAP_FLUSH_CMD) | (state == ST_READ_CMD);

	// Read data from VRAM buffer
	always @(posedge clk)
		if (cap_flip)
			vram_rd_addr <= { ~cap_buf, 7'b0000000 };
		else
			vram_rd_addr <= vram_rd_addr + vram_rd_ena;

	assign vram_rd_ena  = mi_wack | cap_flip_r;
	assign mi_wdata = vram_rd_data;

	// Write data from PSRAM to Read buffer
	always @(posedge clk)
		if (read_start)
			rbuf_wr_addr <= { wb_wdata[29], 7'b0000000 };
		else
			rbuf_wr_addr <= rbuf_wr_addr + rbuf_wr_ena;

	assign rbuf_wr_data = mi_rdata;
	assign rbuf_wr_ena  = mi_rstb;


	// Bus interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	// Read (only from RAM)
	assign wb_rdata = wb_ack ? rbuf_rd_data : 32'h00000000;

	assign rbuf_rd_addr = wb_addr[7:0];

	// Write strobes
	assign bus_clr = ~wb_cyc | ~wb_we | wb_ack;
	always @(posedge clk)
	begin
		if (bus_clr) begin
			bus_we_csr   <= 1'b0;
			bus_we_eaddr <= 1'b0;
			bus_we_raddr <= 1'b0;
		end else begin
			bus_we_csr   <= wb_addr == 4'h0;
			bus_we_eaddr <= wb_addr == 4'h2;
			bus_we_raddr <= wb_addr == 4'h3;
		end
	end

	// CSR writes
	assign cap_start  = bus_we_csr & wb_wdata[31];
	assign read_start = bus_we_csr & wb_wdata[30];
	assign read_addr  = wb_wdata[21:0];

endmodule // vid_cap
