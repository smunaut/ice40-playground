// Generator : SpinalHDL v1.4.0    git head : ecb5a80b713566f417ea3ea061f9969e73770a7f
// Date      : 02/05/2020, 15:18:04
// Component : VexRiscv


`define BranchCtrlEnum_defaultEncoding_type [1:0]
`define BranchCtrlEnum_defaultEncoding_INC 2'b00
`define BranchCtrlEnum_defaultEncoding_B 2'b01
`define BranchCtrlEnum_defaultEncoding_JAL 2'b10
`define BranchCtrlEnum_defaultEncoding_JALR 2'b11

`define Src1CtrlEnum_defaultEncoding_type [1:0]
`define Src1CtrlEnum_defaultEncoding_RS 2'b00
`define Src1CtrlEnum_defaultEncoding_IMU 2'b01
`define Src1CtrlEnum_defaultEncoding_PC_INCREMENT 2'b10
`define Src1CtrlEnum_defaultEncoding_URS1 2'b11

`define AluBitwiseCtrlEnum_defaultEncoding_type [1:0]
`define AluBitwiseCtrlEnum_defaultEncoding_XOR_1 2'b00
`define AluBitwiseCtrlEnum_defaultEncoding_OR_1 2'b01
`define AluBitwiseCtrlEnum_defaultEncoding_AND_1 2'b10

`define ShiftCtrlEnum_defaultEncoding_type [1:0]
`define ShiftCtrlEnum_defaultEncoding_DISABLE_1 2'b00
`define ShiftCtrlEnum_defaultEncoding_SLL_1 2'b01
`define ShiftCtrlEnum_defaultEncoding_SRL_1 2'b10
`define ShiftCtrlEnum_defaultEncoding_SRA_1 2'b11

`define EnvCtrlEnum_defaultEncoding_type [1:0]
`define EnvCtrlEnum_defaultEncoding_NONE 2'b00
`define EnvCtrlEnum_defaultEncoding_XRET 2'b01
`define EnvCtrlEnum_defaultEncoding_ECALL 2'b10

`define AluCtrlEnum_defaultEncoding_type [1:0]
`define AluCtrlEnum_defaultEncoding_ADD_SUB 2'b00
`define AluCtrlEnum_defaultEncoding_SLT_SLTU 2'b01
`define AluCtrlEnum_defaultEncoding_BITWISE 2'b10

`define Src2CtrlEnum_defaultEncoding_type [1:0]
`define Src2CtrlEnum_defaultEncoding_RS 2'b00
`define Src2CtrlEnum_defaultEncoding_IMI 2'b01
`define Src2CtrlEnum_defaultEncoding_IMS 2'b10
`define Src2CtrlEnum_defaultEncoding_PC 2'b11


module InstructionCache (
  input               io_flush,
  input               io_cpu_prefetch_isValid,
  output reg          io_cpu_prefetch_haltIt,
  input      [31:0]   io_cpu_prefetch_pc,
  input               io_cpu_fetch_isValid,
  input               io_cpu_fetch_isStuck,
  input               io_cpu_fetch_isRemoved,
  input      [31:0]   io_cpu_fetch_pc,
  output     [31:0]   io_cpu_fetch_data,
  output              io_cpu_fetch_mmuBus_cmd_isValid,
  output     [31:0]   io_cpu_fetch_mmuBus_cmd_virtualAddress,
  output              io_cpu_fetch_mmuBus_cmd_bypassTranslation,
  input      [31:0]   io_cpu_fetch_mmuBus_rsp_physicalAddress,
  input               io_cpu_fetch_mmuBus_rsp_isIoAccess,
  input               io_cpu_fetch_mmuBus_rsp_allowRead,
  input               io_cpu_fetch_mmuBus_rsp_allowWrite,
  input               io_cpu_fetch_mmuBus_rsp_allowExecute,
  input               io_cpu_fetch_mmuBus_rsp_exception,
  input               io_cpu_fetch_mmuBus_rsp_refilling,
  output              io_cpu_fetch_mmuBus_end,
  input               io_cpu_fetch_mmuBus_busy,
  output     [31:0]   io_cpu_fetch_physicalAddress,
  output              io_cpu_fetch_haltIt,
  input               io_cpu_decode_isValid,
  input               io_cpu_decode_isStuck,
  input      [31:0]   io_cpu_decode_pc,
  output     [31:0]   io_cpu_decode_physicalAddress,
  output     [31:0]   io_cpu_decode_data,
  output              io_cpu_decode_cacheMiss,
  output              io_cpu_decode_error,
  output              io_cpu_decode_mmuRefilling,
  output              io_cpu_decode_mmuException,
  input               io_cpu_decode_isUser,
  input               io_cpu_fill_valid,
  input      [31:0]   io_cpu_fill_payload,
  output              io_mem_cmd_valid,
  input               io_mem_cmd_ready,
  output     [31:0]   io_mem_cmd_payload_address,
  output     [2:0]    io_mem_cmd_payload_size,
  input               io_mem_rsp_valid,
  input      [31:0]   io_mem_rsp_payload_data,
  input               io_mem_rsp_payload_error,
  input               clk,
  input               reset 
);
  reg        [23:0]   _zz_10_;
  reg        [31:0]   _zz_11_;
  wire                _zz_12_;
  wire                _zz_13_;
  wire       [0:0]    _zz_14_;
  wire       [0:0]    _zz_15_;
  wire       [23:0]   _zz_16_;
  reg                 _zz_1_;
  reg                 _zz_2_;
  reg                 lineLoader_fire;
  reg                 lineLoader_valid;
  (* keep , syn_keep *) reg        [31:0]   lineLoader_address /* synthesis syn_keep = 1 */ ;
  reg                 lineLoader_hadError;
  reg                 lineLoader_flushPending;
  reg        [5:0]    lineLoader_flushCounter;
  reg                 _zz_3_;
  reg                 lineLoader_cmdSent;
  reg                 lineLoader_wayToAllocate_willIncrement;
  wire                lineLoader_wayToAllocate_willClear;
  wire                lineLoader_wayToAllocate_willOverflowIfInc;
  wire                lineLoader_wayToAllocate_willOverflow;
  (* keep , syn_keep *) reg        [2:0]    lineLoader_wordIndex /* synthesis syn_keep = 1 */ ;
  wire                lineLoader_write_tag_0_valid;
  wire       [4:0]    lineLoader_write_tag_0_payload_address;
  wire                lineLoader_write_tag_0_payload_data_valid;
  wire                lineLoader_write_tag_0_payload_data_error;
  wire       [21:0]   lineLoader_write_tag_0_payload_data_address;
  wire                lineLoader_write_data_0_valid;
  wire       [7:0]    lineLoader_write_data_0_payload_address;
  wire       [31:0]   lineLoader_write_data_0_payload_data;
  wire                _zz_4_;
  wire       [4:0]    _zz_5_;
  wire                _zz_6_;
  wire                fetchStage_read_waysValues_0_tag_valid;
  wire                fetchStage_read_waysValues_0_tag_error;
  wire       [21:0]   fetchStage_read_waysValues_0_tag_address;
  wire       [23:0]   _zz_7_;
  wire       [7:0]    _zz_8_;
  wire                _zz_9_;
  wire       [31:0]   fetchStage_read_waysValues_0_data;
  wire                fetchStage_hit_hits_0;
  wire                fetchStage_hit_valid;
  wire                fetchStage_hit_error;
  wire       [31:0]   fetchStage_hit_data;
  wire       [31:0]   fetchStage_hit_word;
  reg        [31:0]   io_cpu_fetch_data_regNextWhen;
  reg        [31:0]   decodeStage_mmuRsp_physicalAddress;
  reg                 decodeStage_mmuRsp_isIoAccess;
  reg                 decodeStage_mmuRsp_allowRead;
  reg                 decodeStage_mmuRsp_allowWrite;
  reg                 decodeStage_mmuRsp_allowExecute;
  reg                 decodeStage_mmuRsp_exception;
  reg                 decodeStage_mmuRsp_refilling;
  reg                 decodeStage_hit_valid;
  reg                 decodeStage_hit_error;
  reg [23:0] ways_0_tags [0:31];
  reg [31:0] ways_0_datas [0:255];

  assign _zz_12_ = (! lineLoader_flushCounter[5]);
  assign _zz_13_ = (lineLoader_flushPending && (! (lineLoader_valid || io_cpu_fetch_isValid)));
  assign _zz_14_ = _zz_7_[0 : 0];
  assign _zz_15_ = _zz_7_[1 : 1];
  assign _zz_16_ = {lineLoader_write_tag_0_payload_data_address,{lineLoader_write_tag_0_payload_data_error,lineLoader_write_tag_0_payload_data_valid}};
  always @ (posedge clk) begin
    if(_zz_2_) begin
      ways_0_tags[lineLoader_write_tag_0_payload_address] <= _zz_16_;
    end
  end

  always @ (posedge clk) begin
    if(_zz_6_) begin
      _zz_10_ <= ways_0_tags[_zz_5_];
    end
  end

  always @ (posedge clk) begin
    if(_zz_1_) begin
      ways_0_datas[lineLoader_write_data_0_payload_address] <= lineLoader_write_data_0_payload_data;
    end
  end

  always @ (posedge clk) begin
    if(_zz_9_) begin
      _zz_11_ <= ways_0_datas[_zz_8_];
    end
  end

  always @ (*) begin
    _zz_1_ = 1'b0;
    if(lineLoader_write_data_0_valid)begin
      _zz_1_ = 1'b1;
    end
  end

  always @ (*) begin
    _zz_2_ = 1'b0;
    if(lineLoader_write_tag_0_valid)begin
      _zz_2_ = 1'b1;
    end
  end

  assign io_cpu_fetch_haltIt = io_cpu_fetch_mmuBus_busy;
  always @ (*) begin
    lineLoader_fire = 1'b0;
    if(io_mem_rsp_valid)begin
      if((lineLoader_wordIndex == (3'b111)))begin
        lineLoader_fire = 1'b1;
      end
    end
  end

  always @ (*) begin
    io_cpu_prefetch_haltIt = (lineLoader_valid || lineLoader_flushPending);
    if(_zz_12_)begin
      io_cpu_prefetch_haltIt = 1'b1;
    end
    if((! _zz_3_))begin
      io_cpu_prefetch_haltIt = 1'b1;
    end
    if(io_flush)begin
      io_cpu_prefetch_haltIt = 1'b1;
    end
  end

  assign io_mem_cmd_valid = (lineLoader_valid && (! lineLoader_cmdSent));
  assign io_mem_cmd_payload_address = {lineLoader_address[31 : 5],5'h0};
  assign io_mem_cmd_payload_size = (3'b101);
  always @ (*) begin
    lineLoader_wayToAllocate_willIncrement = 1'b0;
    if((! lineLoader_valid))begin
      lineLoader_wayToAllocate_willIncrement = 1'b1;
    end
  end

  assign lineLoader_wayToAllocate_willClear = 1'b0;
  assign lineLoader_wayToAllocate_willOverflowIfInc = 1'b1;
  assign lineLoader_wayToAllocate_willOverflow = (lineLoader_wayToAllocate_willOverflowIfInc && lineLoader_wayToAllocate_willIncrement);
  assign _zz_4_ = 1'b1;
  assign lineLoader_write_tag_0_valid = ((_zz_4_ && lineLoader_fire) || (! lineLoader_flushCounter[5]));
  assign lineLoader_write_tag_0_payload_address = (lineLoader_flushCounter[5] ? lineLoader_address[9 : 5] : lineLoader_flushCounter[4 : 0]);
  assign lineLoader_write_tag_0_payload_data_valid = lineLoader_flushCounter[5];
  assign lineLoader_write_tag_0_payload_data_error = (lineLoader_hadError || io_mem_rsp_payload_error);
  assign lineLoader_write_tag_0_payload_data_address = lineLoader_address[31 : 10];
  assign lineLoader_write_data_0_valid = (io_mem_rsp_valid && _zz_4_);
  assign lineLoader_write_data_0_payload_address = {lineLoader_address[9 : 5],lineLoader_wordIndex};
  assign lineLoader_write_data_0_payload_data = io_mem_rsp_payload_data;
  assign _zz_5_ = io_cpu_prefetch_pc[9 : 5];
  assign _zz_6_ = (! io_cpu_fetch_isStuck);
  assign _zz_7_ = _zz_10_;
  assign fetchStage_read_waysValues_0_tag_valid = _zz_14_[0];
  assign fetchStage_read_waysValues_0_tag_error = _zz_15_[0];
  assign fetchStage_read_waysValues_0_tag_address = _zz_7_[23 : 2];
  assign _zz_8_ = io_cpu_prefetch_pc[9 : 2];
  assign _zz_9_ = (! io_cpu_fetch_isStuck);
  assign fetchStage_read_waysValues_0_data = _zz_11_;
  assign fetchStage_hit_hits_0 = (fetchStage_read_waysValues_0_tag_valid && (fetchStage_read_waysValues_0_tag_address == io_cpu_fetch_mmuBus_rsp_physicalAddress[31 : 10]));
  assign fetchStage_hit_valid = (fetchStage_hit_hits_0 != (1'b0));
  assign fetchStage_hit_error = fetchStage_read_waysValues_0_tag_error;
  assign fetchStage_hit_data = fetchStage_read_waysValues_0_data;
  assign fetchStage_hit_word = fetchStage_hit_data;
  assign io_cpu_fetch_data = fetchStage_hit_word;
  assign io_cpu_decode_data = io_cpu_fetch_data_regNextWhen;
  assign io_cpu_fetch_mmuBus_cmd_isValid = io_cpu_fetch_isValid;
  assign io_cpu_fetch_mmuBus_cmd_virtualAddress = io_cpu_fetch_pc;
  assign io_cpu_fetch_mmuBus_cmd_bypassTranslation = 1'b0;
  assign io_cpu_fetch_mmuBus_end = ((! io_cpu_fetch_isStuck) || io_cpu_fetch_isRemoved);
  assign io_cpu_fetch_physicalAddress = io_cpu_fetch_mmuBus_rsp_physicalAddress;
  assign io_cpu_decode_cacheMiss = (! decodeStage_hit_valid);
  assign io_cpu_decode_error = decodeStage_hit_error;
  assign io_cpu_decode_mmuRefilling = decodeStage_mmuRsp_refilling;
  assign io_cpu_decode_mmuException = ((! decodeStage_mmuRsp_refilling) && (decodeStage_mmuRsp_exception || (! decodeStage_mmuRsp_allowExecute)));
  assign io_cpu_decode_physicalAddress = decodeStage_mmuRsp_physicalAddress;
  always @ (posedge clk or posedge reset) begin
    if (reset) begin
      lineLoader_valid <= 1'b0;
      lineLoader_hadError <= 1'b0;
      lineLoader_flushPending <= 1'b1;
      lineLoader_cmdSent <= 1'b0;
      lineLoader_wordIndex <= (3'b000);
    end else begin
      if(lineLoader_fire)begin
        lineLoader_valid <= 1'b0;
      end
      if(lineLoader_fire)begin
        lineLoader_hadError <= 1'b0;
      end
      if(io_cpu_fill_valid)begin
        lineLoader_valid <= 1'b1;
      end
      if(io_flush)begin
        lineLoader_flushPending <= 1'b1;
      end
      if(_zz_13_)begin
        lineLoader_flushPending <= 1'b0;
      end
      if((io_mem_cmd_valid && io_mem_cmd_ready))begin
        lineLoader_cmdSent <= 1'b1;
      end
      if(lineLoader_fire)begin
        lineLoader_cmdSent <= 1'b0;
      end
      if(io_mem_rsp_valid)begin
        lineLoader_wordIndex <= (lineLoader_wordIndex + (3'b001));
        if(io_mem_rsp_payload_error)begin
          lineLoader_hadError <= 1'b1;
        end
      end
    end
  end

  always @ (posedge clk) begin
    if(io_cpu_fill_valid)begin
      lineLoader_address <= io_cpu_fill_payload;
    end
    if(_zz_12_)begin
      lineLoader_flushCounter <= (lineLoader_flushCounter + 6'h01);
    end
    _zz_3_ <= lineLoader_flushCounter[5];
    if(_zz_13_)begin
      lineLoader_flushCounter <= 6'h0;
    end
    if((! io_cpu_decode_isStuck))begin
      io_cpu_fetch_data_regNextWhen <= io_cpu_fetch_data;
    end
    if((! io_cpu_decode_isStuck))begin
      decodeStage_mmuRsp_physicalAddress <= io_cpu_fetch_mmuBus_rsp_physicalAddress;
      decodeStage_mmuRsp_isIoAccess <= io_cpu_fetch_mmuBus_rsp_isIoAccess;
      decodeStage_mmuRsp_allowRead <= io_cpu_fetch_mmuBus_rsp_allowRead;
      decodeStage_mmuRsp_allowWrite <= io_cpu_fetch_mmuBus_rsp_allowWrite;
      decodeStage_mmuRsp_allowExecute <= io_cpu_fetch_mmuBus_rsp_allowExecute;
      decodeStage_mmuRsp_exception <= io_cpu_fetch_mmuBus_rsp_exception;
      decodeStage_mmuRsp_refilling <= io_cpu_fetch_mmuBus_rsp_refilling;
    end
    if((! io_cpu_decode_isStuck))begin
      decodeStage_hit_valid <= fetchStage_hit_valid;
    end
    if((! io_cpu_decode_isStuck))begin
      decodeStage_hit_error <= fetchStage_hit_error;
    end
  end


endmodule

module VexRiscv (
  input      [31:0]   externalResetVector,
  input               timerInterrupt,
  input               softwareInterrupt,
  input      [31:0]   externalInterruptArray,
  output              iBusAXI_ar_valid,
  input               iBusAXI_ar_ready,
  output     [31:0]   iBusAXI_ar_payload_addr,
  output     [7:0]    iBusAXI_ar_payload_len,
  output     [1:0]    iBusAXI_ar_payload_burst,
  output     [3:0]    iBusAXI_ar_payload_cache,
  output     [2:0]    iBusAXI_ar_payload_prot,
  input               iBusAXI_r_valid,
  output              iBusAXI_r_ready,
  input      [31:0]   iBusAXI_r_payload_data,
  input      [1:0]    iBusAXI_r_payload_resp,
  input               iBusAXI_r_payload_last,
  output              dBusWishbone_CYC,
  output              dBusWishbone_STB,
  input               dBusWishbone_ACK,
  output              dBusWishbone_WE,
  output     [29:0]   dBusWishbone_ADR,
  input      [31:0]   dBusWishbone_DAT_MISO,
  output     [31:0]   dBusWishbone_DAT_MOSI,
  output reg [3:0]    dBusWishbone_SEL,
  input               dBusWishbone_ERR,
  output     [1:0]    dBusWishbone_BTE,
  output     [2:0]    dBusWishbone_CTI,
  input               clk,
  input               reset 
);
  wire                _zz_151_;
  wire                _zz_152_;
  wire                _zz_153_;
  wire                _zz_154_;
  wire                _zz_155_;
  wire                _zz_156_;
  wire                _zz_157_;
  reg                 _zz_158_;
  reg        [31:0]   _zz_159_;
  reg        [31:0]   _zz_160_;
  reg        [31:0]   _zz_161_;
  wire                IBusCachedPlugin_cache_io_cpu_prefetch_haltIt;
  wire       [31:0]   IBusCachedPlugin_cache_io_cpu_fetch_data;
  wire       [31:0]   IBusCachedPlugin_cache_io_cpu_fetch_physicalAddress;
  wire                IBusCachedPlugin_cache_io_cpu_fetch_haltIt;
  wire                IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_isValid;
  wire       [31:0]   IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_virtualAddress;
  wire                IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_bypassTranslation;
  wire                IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_end;
  wire                IBusCachedPlugin_cache_io_cpu_decode_error;
  wire                IBusCachedPlugin_cache_io_cpu_decode_mmuRefilling;
  wire                IBusCachedPlugin_cache_io_cpu_decode_mmuException;
  wire       [31:0]   IBusCachedPlugin_cache_io_cpu_decode_data;
  wire                IBusCachedPlugin_cache_io_cpu_decode_cacheMiss;
  wire       [31:0]   IBusCachedPlugin_cache_io_cpu_decode_physicalAddress;
  wire                IBusCachedPlugin_cache_io_mem_cmd_valid;
  wire       [31:0]   IBusCachedPlugin_cache_io_mem_cmd_payload_address;
  wire       [2:0]    IBusCachedPlugin_cache_io_mem_cmd_payload_size;
  wire                _zz_162_;
  wire                _zz_163_;
  wire                _zz_164_;
  wire                _zz_165_;
  wire                _zz_166_;
  wire                _zz_167_;
  wire                _zz_168_;
  wire                _zz_169_;
  wire                _zz_170_;
  wire       [1:0]    _zz_171_;
  wire                _zz_172_;
  wire                _zz_173_;
  wire                _zz_174_;
  wire                _zz_175_;
  wire                _zz_176_;
  wire                _zz_177_;
  wire                _zz_178_;
  wire                _zz_179_;
  wire                _zz_180_;
  wire                _zz_181_;
  wire                _zz_182_;
  wire                _zz_183_;
  wire                _zz_184_;
  wire       [1:0]    _zz_185_;
  wire                _zz_186_;
  wire       [0:0]    _zz_187_;
  wire       [0:0]    _zz_188_;
  wire       [0:0]    _zz_189_;
  wire       [32:0]   _zz_190_;
  wire       [31:0]   _zz_191_;
  wire       [32:0]   _zz_192_;
  wire       [0:0]    _zz_193_;
  wire       [0:0]    _zz_194_;
  wire       [0:0]    _zz_195_;
  wire       [0:0]    _zz_196_;
  wire       [0:0]    _zz_197_;
  wire       [0:0]    _zz_198_;
  wire       [0:0]    _zz_199_;
  wire       [0:0]    _zz_200_;
  wire       [0:0]    _zz_201_;
  wire       [3:0]    _zz_202_;
  wire       [2:0]    _zz_203_;
  wire       [31:0]   _zz_204_;
  wire       [11:0]   _zz_205_;
  wire       [31:0]   _zz_206_;
  wire       [19:0]   _zz_207_;
  wire       [11:0]   _zz_208_;
  wire       [31:0]   _zz_209_;
  wire       [31:0]   _zz_210_;
  wire       [19:0]   _zz_211_;
  wire       [11:0]   _zz_212_;
  wire       [0:0]    _zz_213_;
  wire       [2:0]    _zz_214_;
  wire       [4:0]    _zz_215_;
  wire       [11:0]   _zz_216_;
  wire       [11:0]   _zz_217_;
  wire       [31:0]   _zz_218_;
  wire       [31:0]   _zz_219_;
  wire       [31:0]   _zz_220_;
  wire       [31:0]   _zz_221_;
  wire       [31:0]   _zz_222_;
  wire       [31:0]   _zz_223_;
  wire       [31:0]   _zz_224_;
  wire       [11:0]   _zz_225_;
  wire       [19:0]   _zz_226_;
  wire       [11:0]   _zz_227_;
  wire       [31:0]   _zz_228_;
  wire       [31:0]   _zz_229_;
  wire       [31:0]   _zz_230_;
  wire       [11:0]   _zz_231_;
  wire       [19:0]   _zz_232_;
  wire       [11:0]   _zz_233_;
  wire       [2:0]    _zz_234_;
  wire       [0:0]    _zz_235_;
  wire       [0:0]    _zz_236_;
  wire       [0:0]    _zz_237_;
  wire       [0:0]    _zz_238_;
  wire       [0:0]    _zz_239_;
  wire       [0:0]    _zz_240_;
  wire       [0:0]    _zz_241_;
  wire       [0:0]    _zz_242_;
  wire       [0:0]    _zz_243_;
  wire       [6:0]    _zz_244_;
  wire                _zz_245_;
  wire                _zz_246_;
  wire       [1:0]    _zz_247_;
  wire                _zz_248_;
  wire                _zz_249_;
  wire                _zz_250_;
  wire       [31:0]   _zz_251_;
  wire       [31:0]   _zz_252_;
  wire                _zz_253_;
  wire                _zz_254_;
  wire                _zz_255_;
  wire       [0:0]    _zz_256_;
  wire       [1:0]    _zz_257_;
  wire                _zz_258_;
  wire       [0:0]    _zz_259_;
  wire       [0:0]    _zz_260_;
  wire                _zz_261_;
  wire       [0:0]    _zz_262_;
  wire       [20:0]   _zz_263_;
  wire       [31:0]   _zz_264_;
  wire       [31:0]   _zz_265_;
  wire       [31:0]   _zz_266_;
  wire       [31:0]   _zz_267_;
  wire       [31:0]   _zz_268_;
  wire                _zz_269_;
  wire       [31:0]   _zz_270_;
  wire       [0:0]    _zz_271_;
  wire       [0:0]    _zz_272_;
  wire       [0:0]    _zz_273_;
  wire       [0:0]    _zz_274_;
  wire                _zz_275_;
  wire       [0:0]    _zz_276_;
  wire       [18:0]   _zz_277_;
  wire       [31:0]   _zz_278_;
  wire       [31:0]   _zz_279_;
  wire       [31:0]   _zz_280_;
  wire       [31:0]   _zz_281_;
  wire       [31:0]   _zz_282_;
  wire       [0:0]    _zz_283_;
  wire       [1:0]    _zz_284_;
  wire       [0:0]    _zz_285_;
  wire       [0:0]    _zz_286_;
  wire                _zz_287_;
  wire       [0:0]    _zz_288_;
  wire       [15:0]   _zz_289_;
  wire       [31:0]   _zz_290_;
  wire       [31:0]   _zz_291_;
  wire       [31:0]   _zz_292_;
  wire       [31:0]   _zz_293_;
  wire       [31:0]   _zz_294_;
  wire       [31:0]   _zz_295_;
  wire       [31:0]   _zz_296_;
  wire       [0:0]    _zz_297_;
  wire       [0:0]    _zz_298_;
  wire       [0:0]    _zz_299_;
  wire       [0:0]    _zz_300_;
  wire                _zz_301_;
  wire       [0:0]    _zz_302_;
  wire       [12:0]   _zz_303_;
  wire       [31:0]   _zz_304_;
  wire       [31:0]   _zz_305_;
  wire       [31:0]   _zz_306_;
  wire                _zz_307_;
  wire                _zz_308_;
  wire       [0:0]    _zz_309_;
  wire       [0:0]    _zz_310_;
  wire       [1:0]    _zz_311_;
  wire       [1:0]    _zz_312_;
  wire                _zz_313_;
  wire       [0:0]    _zz_314_;
  wire       [9:0]    _zz_315_;
  wire       [31:0]   _zz_316_;
  wire       [31:0]   _zz_317_;
  wire       [31:0]   _zz_318_;
  wire       [31:0]   _zz_319_;
  wire                _zz_320_;
  wire                _zz_321_;
  wire       [1:0]    _zz_322_;
  wire       [1:0]    _zz_323_;
  wire                _zz_324_;
  wire       [0:0]    _zz_325_;
  wire       [6:0]    _zz_326_;
  wire       [31:0]   _zz_327_;
  wire       [31:0]   _zz_328_;
  wire                _zz_329_;
  wire       [0:0]    _zz_330_;
  wire       [0:0]    _zz_331_;
  wire       [0:0]    _zz_332_;
  wire       [0:0]    _zz_333_;
  wire                _zz_334_;
  wire       [0:0]    _zz_335_;
  wire       [3:0]    _zz_336_;
  wire       [31:0]   _zz_337_;
  wire       [31:0]   _zz_338_;
  wire                _zz_339_;
  wire                _zz_340_;
  wire       [0:0]    _zz_341_;
  wire       [4:0]    _zz_342_;
  wire       [0:0]    _zz_343_;
  wire       [0:0]    _zz_344_;
  wire                _zz_345_;
  wire       [0:0]    _zz_346_;
  wire       [0:0]    _zz_347_;
  wire       [31:0]   _zz_348_;
  wire       [31:0]   _zz_349_;
  wire                _zz_350_;
  wire       [0:0]    _zz_351_;
  wire       [1:0]    _zz_352_;
  wire       [31:0]   _zz_353_;
  wire       [31:0]   _zz_354_;
  wire       [31:0]   _zz_355_;
  wire                _zz_356_;
  wire                _zz_357_;
  wire                _zz_358_;
  wire                _zz_359_;
  wire                _zz_360_;
  wire       [31:0]   writeBack_FORMAL_PC_NEXT;
  wire       [31:0]   memory_FORMAL_PC_NEXT;
  wire       [31:0]   execute_FORMAL_PC_NEXT;
  wire       [31:0]   decode_FORMAL_PC_NEXT;
  wire       `BranchCtrlEnum_defaultEncoding_type _zz_1_;
  wire       `BranchCtrlEnum_defaultEncoding_type _zz_2_;
  wire                decode_PREDICTION_HAD_BRANCHED2;
  wire       `Src1CtrlEnum_defaultEncoding_type decode_SRC1_CTRL;
  wire       `Src1CtrlEnum_defaultEncoding_type _zz_3_;
  wire       `Src1CtrlEnum_defaultEncoding_type _zz_4_;
  wire       `Src1CtrlEnum_defaultEncoding_type _zz_5_;
  wire                decode_IS_CSR;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type decode_ALU_BITWISE_CTRL;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type _zz_6_;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type _zz_7_;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type _zz_8_;
  wire                decode_SRC2_FORCE_ZERO;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_9_;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_10_;
  wire       `ShiftCtrlEnum_defaultEncoding_type decode_SHIFT_CTRL;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_11_;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_12_;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_13_;
  wire       [31:0]   memory_MEMORY_READ_DATA;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_14_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_15_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_16_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_17_;
  wire       `EnvCtrlEnum_defaultEncoding_type decode_ENV_CTRL;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_18_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_19_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_20_;
  wire                decode_MEMORY_STORE;
  wire                decode_SRC_LESS_UNSIGNED;
  wire       [31:0]   execute_SHIFT_RIGHT;
  wire                decode_CSR_READ_OPCODE;
  wire                execute_BYPASSABLE_MEMORY_STAGE;
  wire                decode_BYPASSABLE_MEMORY_STAGE;
  wire       [1:0]    memory_MEMORY_ADDRESS_LOW;
  wire       [1:0]    execute_MEMORY_ADDRESS_LOW;
  wire                execute_BRANCH_DO;
  wire                decode_BYPASSABLE_EXECUTE_STAGE;
  wire       [31:0]   execute_BRANCH_CALC;
  wire       `AluCtrlEnum_defaultEncoding_type decode_ALU_CTRL;
  wire       `AluCtrlEnum_defaultEncoding_type _zz_21_;
  wire       `AluCtrlEnum_defaultEncoding_type _zz_22_;
  wire       `AluCtrlEnum_defaultEncoding_type _zz_23_;
  wire       `Src2CtrlEnum_defaultEncoding_type decode_SRC2_CTRL;
  wire       `Src2CtrlEnum_defaultEncoding_type _zz_24_;
  wire       `Src2CtrlEnum_defaultEncoding_type _zz_25_;
  wire       `Src2CtrlEnum_defaultEncoding_type _zz_26_;
  wire                decode_CSR_WRITE_OPCODE;
  wire       [31:0]   writeBack_REGFILE_WRITE_DATA;
  wire       [31:0]   execute_REGFILE_WRITE_DATA;
  wire                execute_CSR_READ_OPCODE;
  wire                execute_CSR_WRITE_OPCODE;
  wire                execute_IS_CSR;
  wire       `EnvCtrlEnum_defaultEncoding_type memory_ENV_CTRL;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_27_;
  wire       `EnvCtrlEnum_defaultEncoding_type execute_ENV_CTRL;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_28_;
  wire       `EnvCtrlEnum_defaultEncoding_type writeBack_ENV_CTRL;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_29_;
  wire       [31:0]   memory_BRANCH_CALC;
  wire                memory_BRANCH_DO;
  wire       [31:0]   execute_PC;
  wire                execute_PREDICTION_HAD_BRANCHED2;
  wire       [31:0]   execute_RS1;
  wire                execute_BRANCH_COND_RESULT;
  wire       `BranchCtrlEnum_defaultEncoding_type execute_BRANCH_CTRL;
  wire       `BranchCtrlEnum_defaultEncoding_type _zz_30_;
  wire                decode_RS2_USE;
  wire                decode_RS1_USE;
  reg        [31:0]   _zz_31_;
  wire                execute_REGFILE_WRITE_VALID;
  wire                execute_BYPASSABLE_EXECUTE_STAGE;
  wire                memory_REGFILE_WRITE_VALID;
  wire       [31:0]   memory_INSTRUCTION;
  wire                memory_BYPASSABLE_MEMORY_STAGE;
  wire                writeBack_REGFILE_WRITE_VALID;
  reg        [31:0]   decode_RS2;
  reg        [31:0]   decode_RS1;
  wire       [31:0]   memory_SHIFT_RIGHT;
  reg        [31:0]   _zz_32_;
  wire       `ShiftCtrlEnum_defaultEncoding_type memory_SHIFT_CTRL;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_33_;
  wire       `ShiftCtrlEnum_defaultEncoding_type execute_SHIFT_CTRL;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_34_;
  wire                execute_SRC_LESS_UNSIGNED;
  wire                execute_SRC2_FORCE_ZERO;
  wire                execute_SRC_USE_SUB_LESS;
  wire       [31:0]   _zz_35_;
  wire       `Src2CtrlEnum_defaultEncoding_type execute_SRC2_CTRL;
  wire       `Src2CtrlEnum_defaultEncoding_type _zz_36_;
  wire       `Src1CtrlEnum_defaultEncoding_type execute_SRC1_CTRL;
  wire       `Src1CtrlEnum_defaultEncoding_type _zz_37_;
  wire                decode_SRC_USE_SUB_LESS;
  wire                decode_SRC_ADD_ZERO;
  wire       [31:0]   execute_SRC_ADD_SUB;
  wire                execute_SRC_LESS;
  wire       `AluCtrlEnum_defaultEncoding_type execute_ALU_CTRL;
  wire       `AluCtrlEnum_defaultEncoding_type _zz_38_;
  wire       [31:0]   execute_SRC2;
  wire       [31:0]   execute_SRC1;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type execute_ALU_BITWISE_CTRL;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type _zz_39_;
  wire       [31:0]   _zz_40_;
  wire                _zz_41_;
  reg                 _zz_42_;
  wire       [31:0]   decode_INSTRUCTION_ANTICIPATED;
  reg                 decode_REGFILE_WRITE_VALID;
  wire       `AluCtrlEnum_defaultEncoding_type _zz_43_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_44_;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_45_;
  wire       `Src1CtrlEnum_defaultEncoding_type _zz_46_;
  wire       `Src2CtrlEnum_defaultEncoding_type _zz_47_;
  wire       `BranchCtrlEnum_defaultEncoding_type _zz_48_;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type _zz_49_;
  wire                writeBack_MEMORY_STORE;
  reg        [31:0]   _zz_50_;
  wire                writeBack_MEMORY_ENABLE;
  wire       [1:0]    writeBack_MEMORY_ADDRESS_LOW;
  wire       [31:0]   writeBack_MEMORY_READ_DATA;
  wire                memory_MMU_FAULT;
  wire       [31:0]   memory_MMU_RSP_physicalAddress;
  wire                memory_MMU_RSP_isIoAccess;
  wire                memory_MMU_RSP_allowRead;
  wire                memory_MMU_RSP_allowWrite;
  wire                memory_MMU_RSP_allowExecute;
  wire                memory_MMU_RSP_exception;
  wire                memory_MMU_RSP_refilling;
  wire       [31:0]   memory_PC;
  wire       [31:0]   memory_REGFILE_WRITE_DATA;
  wire                memory_MEMORY_STORE;
  wire                memory_MEMORY_ENABLE;
  wire                execute_MMU_FAULT;
  wire       [31:0]   execute_MMU_RSP_physicalAddress;
  wire                execute_MMU_RSP_isIoAccess;
  wire                execute_MMU_RSP_allowRead;
  wire                execute_MMU_RSP_allowWrite;
  wire                execute_MMU_RSP_allowExecute;
  wire                execute_MMU_RSP_exception;
  wire                execute_MMU_RSP_refilling;
  wire       [31:0]   execute_SRC_ADD;
  wire       [31:0]   execute_RS2;
  wire       [31:0]   execute_INSTRUCTION;
  wire                execute_MEMORY_STORE;
  wire                execute_MEMORY_ENABLE;
  wire                execute_ALIGNEMENT_FAULT;
  wire                decode_MEMORY_ENABLE;
  wire                decode_FLUSH_ALL;
  reg                 _zz_51_;
  reg                 _zz_51__0;
  wire       `BranchCtrlEnum_defaultEncoding_type decode_BRANCH_CTRL;
  wire       `BranchCtrlEnum_defaultEncoding_type _zz_52_;
  wire       [31:0]   decode_INSTRUCTION;
  reg        [31:0]   _zz_53_;
  reg        [31:0]   _zz_54_;
  wire       [31:0]   decode_PC;
  wire       [31:0]   writeBack_PC;
  wire       [31:0]   writeBack_INSTRUCTION;
  reg                 decode_arbitration_haltItself;
  reg                 decode_arbitration_haltByOther;
  reg                 decode_arbitration_removeIt;
  wire                decode_arbitration_flushIt;
  reg                 decode_arbitration_flushNext;
  wire                decode_arbitration_isValid;
  wire                decode_arbitration_isStuck;
  wire                decode_arbitration_isStuckByOthers;
  wire                decode_arbitration_isFlushed;
  wire                decode_arbitration_isMoving;
  wire                decode_arbitration_isFiring;
  reg                 execute_arbitration_haltItself;
  wire                execute_arbitration_haltByOther;
  reg                 execute_arbitration_removeIt;
  wire                execute_arbitration_flushIt;
  reg                 execute_arbitration_flushNext;
  reg                 execute_arbitration_isValid;
  wire                execute_arbitration_isStuck;
  wire                execute_arbitration_isStuckByOthers;
  wire                execute_arbitration_isFlushed;
  wire                execute_arbitration_isMoving;
  wire                execute_arbitration_isFiring;
  reg                 memory_arbitration_haltItself;
  wire                memory_arbitration_haltByOther;
  reg                 memory_arbitration_removeIt;
  reg                 memory_arbitration_flushIt;
  reg                 memory_arbitration_flushNext;
  reg                 memory_arbitration_isValid;
  wire                memory_arbitration_isStuck;
  wire                memory_arbitration_isStuckByOthers;
  wire                memory_arbitration_isFlushed;
  wire                memory_arbitration_isMoving;
  wire                memory_arbitration_isFiring;
  wire                writeBack_arbitration_haltItself;
  wire                writeBack_arbitration_haltByOther;
  reg                 writeBack_arbitration_removeIt;
  wire                writeBack_arbitration_flushIt;
  reg                 writeBack_arbitration_flushNext;
  reg                 writeBack_arbitration_isValid;
  wire                writeBack_arbitration_isStuck;
  wire                writeBack_arbitration_isStuckByOthers;
  wire                writeBack_arbitration_isFlushed;
  wire                writeBack_arbitration_isMoving;
  wire                writeBack_arbitration_isFiring;
  wire       [31:0]   lastStageInstruction /* verilator public */ ;
  wire       [31:0]   lastStagePc /* verilator public */ ;
  wire                lastStageIsValid /* verilator public */ ;
  wire                lastStageIsFiring /* verilator public */ ;
  reg                 IBusCachedPlugin_fetcherHalt;
  reg                 IBusCachedPlugin_incomingInstruction;
  wire                IBusCachedPlugin_predictionJumpInterface_valid;
  (* keep , syn_keep *) wire       [31:0]   IBusCachedPlugin_predictionJumpInterface_payload /* synthesis syn_keep = 1 */ ;
  reg                 IBusCachedPlugin_decodePrediction_cmd_hadBranch;
  wire                IBusCachedPlugin_decodePrediction_rsp_wasWrong;
  wire                IBusCachedPlugin_pcValids_0;
  wire                IBusCachedPlugin_pcValids_1;
  wire                IBusCachedPlugin_pcValids_2;
  wire                IBusCachedPlugin_pcValids_3;
  wire                IBusCachedPlugin_mmuBus_cmd_isValid;
  wire       [31:0]   IBusCachedPlugin_mmuBus_cmd_virtualAddress;
  wire                IBusCachedPlugin_mmuBus_cmd_bypassTranslation;
  wire       [31:0]   IBusCachedPlugin_mmuBus_rsp_physicalAddress;
  wire                IBusCachedPlugin_mmuBus_rsp_isIoAccess;
  wire                IBusCachedPlugin_mmuBus_rsp_allowRead;
  wire                IBusCachedPlugin_mmuBus_rsp_allowWrite;
  wire                IBusCachedPlugin_mmuBus_rsp_allowExecute;
  wire                IBusCachedPlugin_mmuBus_rsp_exception;
  wire                IBusCachedPlugin_mmuBus_rsp_refilling;
  wire                IBusCachedPlugin_mmuBus_end;
  wire                IBusCachedPlugin_mmuBus_busy;
  reg                 DBusSimplePlugin_memoryExceptionPort_valid;
  reg        [3:0]    DBusSimplePlugin_memoryExceptionPort_payload_code;
  wire       [31:0]   DBusSimplePlugin_memoryExceptionPort_payload_badAddr;
  wire                DBusSimplePlugin_mmuBus_cmd_isValid;
  wire       [31:0]   DBusSimplePlugin_mmuBus_cmd_virtualAddress;
  wire                DBusSimplePlugin_mmuBus_cmd_bypassTranslation;
  wire       [31:0]   DBusSimplePlugin_mmuBus_rsp_physicalAddress;
  wire                DBusSimplePlugin_mmuBus_rsp_isIoAccess;
  wire                DBusSimplePlugin_mmuBus_rsp_allowRead;
  wire                DBusSimplePlugin_mmuBus_rsp_allowWrite;
  wire                DBusSimplePlugin_mmuBus_rsp_allowExecute;
  wire                DBusSimplePlugin_mmuBus_rsp_exception;
  wire                DBusSimplePlugin_mmuBus_rsp_refilling;
  wire                DBusSimplePlugin_mmuBus_end;
  wire                DBusSimplePlugin_mmuBus_busy;
  reg                 DBusSimplePlugin_redoBranch_valid;
  wire       [31:0]   DBusSimplePlugin_redoBranch_payload;
  wire                BranchPlugin_jumpInterface_valid;
  wire       [31:0]   BranchPlugin_jumpInterface_payload;
  wire                CsrPlugin_inWfi /* verilator public */ ;
  wire                CsrPlugin_thirdPartyWake;
  reg                 CsrPlugin_jumpInterface_valid;
  reg        [31:0]   CsrPlugin_jumpInterface_payload;
  wire                CsrPlugin_exceptionPendings_0;
  wire                CsrPlugin_exceptionPendings_1;
  wire                CsrPlugin_exceptionPendings_2;
  wire                CsrPlugin_exceptionPendings_3;
  wire                externalInterrupt;
  wire                contextSwitching;
  reg        [1:0]    CsrPlugin_privilege;
  wire                CsrPlugin_forceMachineWire;
  reg                 CsrPlugin_selfException_valid;
  reg        [3:0]    CsrPlugin_selfException_payload_code;
  wire       [31:0]   CsrPlugin_selfException_payload_badAddr;
  wire                CsrPlugin_allowInterrupts;
  wire                CsrPlugin_allowException;
  wire                IBusCachedPlugin_externalFlush;
  wire                IBusCachedPlugin_jump_pcLoad_valid;
  wire       [31:0]   IBusCachedPlugin_jump_pcLoad_payload;
  wire       [3:0]    _zz_55_;
  wire       [3:0]    _zz_56_;
  wire                _zz_57_;
  wire                _zz_58_;
  wire                _zz_59_;
  wire                IBusCachedPlugin_fetchPc_output_valid;
  wire                IBusCachedPlugin_fetchPc_output_ready;
  wire       [31:0]   IBusCachedPlugin_fetchPc_output_payload;
  reg        [31:0]   IBusCachedPlugin_fetchPc_pcReg /* verilator public */ ;
  reg                 IBusCachedPlugin_fetchPc_correction;
  reg                 IBusCachedPlugin_fetchPc_correctionReg;
  wire                IBusCachedPlugin_fetchPc_corrected;
  reg                 IBusCachedPlugin_fetchPc_pcRegPropagate;
  reg                 IBusCachedPlugin_fetchPc_booted;
  reg                 IBusCachedPlugin_fetchPc_inc;
  reg        [31:0]   IBusCachedPlugin_fetchPc_pc;
  wire                IBusCachedPlugin_fetchPc_redo_valid;
  wire       [31:0]   IBusCachedPlugin_fetchPc_redo_payload;
  reg                 IBusCachedPlugin_fetchPc_flushed;
  reg                 IBusCachedPlugin_iBusRsp_redoFetch;
  wire                IBusCachedPlugin_iBusRsp_stages_0_input_valid;
  wire                IBusCachedPlugin_iBusRsp_stages_0_input_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_stages_0_input_payload;
  wire                IBusCachedPlugin_iBusRsp_stages_0_output_valid;
  wire                IBusCachedPlugin_iBusRsp_stages_0_output_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_stages_0_output_payload;
  reg                 IBusCachedPlugin_iBusRsp_stages_0_halt;
  wire                IBusCachedPlugin_iBusRsp_stages_1_input_valid;
  wire                IBusCachedPlugin_iBusRsp_stages_1_input_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_stages_1_input_payload;
  wire                IBusCachedPlugin_iBusRsp_stages_1_output_valid;
  wire                IBusCachedPlugin_iBusRsp_stages_1_output_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_stages_1_output_payload;
  reg                 IBusCachedPlugin_iBusRsp_stages_1_halt;
  wire                IBusCachedPlugin_iBusRsp_stages_2_input_valid;
  wire                IBusCachedPlugin_iBusRsp_stages_2_input_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_stages_2_input_payload;
  wire                IBusCachedPlugin_iBusRsp_stages_2_output_valid;
  wire                IBusCachedPlugin_iBusRsp_stages_2_output_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_stages_2_output_payload;
  reg                 IBusCachedPlugin_iBusRsp_stages_2_halt;
  wire                _zz_60_;
  wire                _zz_61_;
  wire                _zz_62_;
  wire                IBusCachedPlugin_iBusRsp_flush;
  wire                _zz_63_;
  wire                _zz_64_;
  reg                 _zz_65_;
  wire                _zz_66_;
  reg                 _zz_67_;
  reg        [31:0]   _zz_68_;
  reg                 IBusCachedPlugin_iBusRsp_readyForError;
  wire                IBusCachedPlugin_iBusRsp_output_valid;
  wire                IBusCachedPlugin_iBusRsp_output_ready;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_output_payload_pc;
  wire                IBusCachedPlugin_iBusRsp_output_payload_rsp_error;
  wire       [31:0]   IBusCachedPlugin_iBusRsp_output_payload_rsp_inst;
  wire                IBusCachedPlugin_iBusRsp_output_payload_isRvc;
  reg                 IBusCachedPlugin_injector_nextPcCalc_valids_0;
  reg                 IBusCachedPlugin_injector_nextPcCalc_valids_1;
  reg                 IBusCachedPlugin_injector_nextPcCalc_valids_2;
  reg                 IBusCachedPlugin_injector_nextPcCalc_valids_3;
  reg                 IBusCachedPlugin_injector_nextPcCalc_valids_4;
  wire                _zz_69_;
  reg        [18:0]   _zz_70_;
  wire                _zz_71_;
  reg        [10:0]   _zz_72_;
  wire                _zz_73_;
  reg        [18:0]   _zz_74_;
  reg                 _zz_75_;
  wire                _zz_76_;
  reg        [10:0]   _zz_77_;
  wire                _zz_78_;
  reg        [18:0]   _zz_79_;
  wire                iBus_cmd_valid;
  wire                iBus_cmd_ready;
  reg        [31:0]   iBus_cmd_payload_address;
  wire       [2:0]    iBus_cmd_payload_size;
  wire                iBus_rsp_valid;
  wire       [31:0]   iBus_rsp_payload_data;
  wire                iBus_rsp_payload_error;
  wire       [31:0]   _zz_80_;
  reg        [31:0]   IBusCachedPlugin_rspCounter;
  wire                IBusCachedPlugin_s0_tightlyCoupledHit;
  reg                 IBusCachedPlugin_s1_tightlyCoupledHit;
  reg                 IBusCachedPlugin_s2_tightlyCoupledHit;
  wire                IBusCachedPlugin_rsp_iBusRspOutputHalt;
  wire                IBusCachedPlugin_rsp_issueDetected;
  reg                 IBusCachedPlugin_rsp_redoFetch;
  wire                dBus_cmd_valid;
  wire                dBus_cmd_ready;
  wire                dBus_cmd_payload_wr;
  wire       [31:0]   dBus_cmd_payload_address;
  wire       [31:0]   dBus_cmd_payload_data;
  wire       [1:0]    dBus_cmd_payload_size;
  wire                dBus_rsp_ready;
  wire                dBus_rsp_error;
  wire       [31:0]   dBus_rsp_data;
  wire                _zz_81_;
  reg                 execute_DBusSimplePlugin_skipCmd;
  reg        [31:0]   _zz_82_;
  reg        [3:0]    _zz_83_;
  wire       [3:0]    execute_DBusSimplePlugin_formalMask;
  reg        [31:0]   writeBack_DBusSimplePlugin_rspShifted;
  wire                _zz_84_;
  reg        [31:0]   _zz_85_;
  wire                _zz_86_;
  reg        [31:0]   _zz_87_;
  reg        [31:0]   writeBack_DBusSimplePlugin_rspFormated;
  wire       [26:0]   _zz_88_;
  wire                _zz_89_;
  wire                _zz_90_;
  wire                _zz_91_;
  wire                _zz_92_;
  wire       `AluBitwiseCtrlEnum_defaultEncoding_type _zz_93_;
  wire       `BranchCtrlEnum_defaultEncoding_type _zz_94_;
  wire       `Src2CtrlEnum_defaultEncoding_type _zz_95_;
  wire       `Src1CtrlEnum_defaultEncoding_type _zz_96_;
  wire       `ShiftCtrlEnum_defaultEncoding_type _zz_97_;
  wire       `EnvCtrlEnum_defaultEncoding_type _zz_98_;
  wire       `AluCtrlEnum_defaultEncoding_type _zz_99_;
  reg                 RegFilePlugin_shadow_write;
  reg                 RegFilePlugin_shadow_read;
  reg                 RegFilePlugin_shadow_clear;
  wire       [5:0]    decode_RegFilePlugin_regFileReadAddress1;
  wire       [5:0]    decode_RegFilePlugin_regFileReadAddress2;
  wire       [31:0]   decode_RegFilePlugin_rs1Data;
  wire       [31:0]   decode_RegFilePlugin_rs2Data;
  reg                 lastStageRegFileWrite_valid /* verilator public */ ;
  wire       [5:0]    lastStageRegFileWrite_payload_address /* verilator public */ ;
  wire       [31:0]   lastStageRegFileWrite_payload_data /* verilator public */ ;
  reg                 _zz_100_;
  reg        [31:0]   execute_IntAluPlugin_bitwise;
  reg        [31:0]   _zz_101_;
  reg        [31:0]   _zz_102_;
  wire                _zz_103_;
  reg        [19:0]   _zz_104_;
  wire                _zz_105_;
  reg        [19:0]   _zz_106_;
  reg        [31:0]   _zz_107_;
  reg        [31:0]   execute_SrcPlugin_addSub;
  wire                execute_SrcPlugin_less;
  wire       [4:0]    execute_FullBarrelShifterPlugin_amplitude;
  reg        [31:0]   _zz_108_;
  wire       [31:0]   execute_FullBarrelShifterPlugin_reversed;
  reg        [31:0]   _zz_109_;
  reg                 _zz_110_;
  reg                 _zz_111_;
  reg                 _zz_112_;
  reg        [4:0]    _zz_113_;
  reg        [31:0]   _zz_114_;
  wire                _zz_115_;
  wire                _zz_116_;
  wire                _zz_117_;
  wire                _zz_118_;
  wire                _zz_119_;
  wire                _zz_120_;
  wire                execute_BranchPlugin_eq;
  wire       [2:0]    _zz_121_;
  reg                 _zz_122_;
  reg                 _zz_123_;
  wire                _zz_124_;
  reg        [19:0]   _zz_125_;
  wire                _zz_126_;
  reg        [10:0]   _zz_127_;
  wire                _zz_128_;
  reg        [18:0]   _zz_129_;
  reg                 _zz_130_;
  wire                execute_BranchPlugin_missAlignedTarget;
  reg        [31:0]   execute_BranchPlugin_branch_src1;
  reg        [31:0]   execute_BranchPlugin_branch_src2;
  wire                _zz_131_;
  reg        [19:0]   _zz_132_;
  wire                _zz_133_;
  reg        [10:0]   _zz_134_;
  wire                _zz_135_;
  reg        [18:0]   _zz_136_;
  wire       [31:0]   execute_BranchPlugin_branchAdder;
  wire       [1:0]    CsrPlugin_misa_base;
  wire       [25:0]   CsrPlugin_misa_extensions;
  reg        [1:0]    CsrPlugin_mtvec_mode;
  reg        [29:0]   CsrPlugin_mtvec_base;
  reg        [31:0]   CsrPlugin_mepc;
  reg                 CsrPlugin_mstatus_MIE;
  reg                 CsrPlugin_mstatus_MPIE;
  reg        [1:0]    CsrPlugin_mstatus_MPP;
  reg                 CsrPlugin_mip_MEIP;
  reg                 CsrPlugin_mip_MTIP;
  reg                 CsrPlugin_mip_MSIP;
  reg                 CsrPlugin_mie_MEIE;
  reg                 CsrPlugin_mie_MTIE;
  reg                 CsrPlugin_mie_MSIE;
  reg                 CsrPlugin_mcause_interrupt;
  reg        [3:0]    CsrPlugin_mcause_exceptionCode;
  reg        [31:0]   CsrPlugin_mtval;
  reg        [63:0]   CsrPlugin_mcycle = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  reg        [63:0]   CsrPlugin_minstret = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire                _zz_137_;
  wire                _zz_138_;
  wire                _zz_139_;
  wire                CsrPlugin_exceptionPortCtrl_exceptionValids_decode;
  reg                 CsrPlugin_exceptionPortCtrl_exceptionValids_execute;
  reg                 CsrPlugin_exceptionPortCtrl_exceptionValids_memory;
  reg                 CsrPlugin_exceptionPortCtrl_exceptionValids_writeBack;
  wire                CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_decode;
  reg                 CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute;
  reg                 CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory;
  reg                 CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack;
  reg        [3:0]    CsrPlugin_exceptionPortCtrl_exceptionContext_code;
  reg        [31:0]   CsrPlugin_exceptionPortCtrl_exceptionContext_badAddr;
  wire       [1:0]    CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilegeUncapped;
  wire       [1:0]    CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilege;
  reg                 CsrPlugin_interrupt_valid;
  reg        [3:0]    CsrPlugin_interrupt_code /* verilator public */ ;
  reg        [1:0]    CsrPlugin_interrupt_targetPrivilege;
  wire                CsrPlugin_exception;
  wire                CsrPlugin_lastStageWasWfi;
  reg                 CsrPlugin_pipelineLiberator_pcValids_0;
  reg                 CsrPlugin_pipelineLiberator_pcValids_1;
  reg                 CsrPlugin_pipelineLiberator_pcValids_2;
  wire                CsrPlugin_pipelineLiberator_active;
  reg                 CsrPlugin_pipelineLiberator_done;
  wire                CsrPlugin_interruptJump /* verilator public */ ;
  reg                 CsrPlugin_hadException;
  reg        [1:0]    CsrPlugin_targetPrivilege;
  reg        [3:0]    CsrPlugin_trapCause;
  reg        [1:0]    CsrPlugin_xtvec_mode;
  reg        [29:0]   CsrPlugin_xtvec_base;
  reg                 execute_CsrPlugin_wfiWake;
  wire                execute_CsrPlugin_blockedBySideEffects;
  reg                 execute_CsrPlugin_illegalAccess;
  reg                 execute_CsrPlugin_illegalInstruction;
  wire       [31:0]   execute_CsrPlugin_readData;
  wire                execute_CsrPlugin_writeInstruction;
  wire                execute_CsrPlugin_readInstruction;
  wire                execute_CsrPlugin_writeEnable;
  wire                execute_CsrPlugin_readEnable;
  wire       [31:0]   execute_CsrPlugin_readToWriteData;
  reg        [31:0]   execute_CsrPlugin_writeData;
  wire       [11:0]   execute_CsrPlugin_csrAddress;
  reg        [31:0]   externalInterruptArray_regNext;
  reg        [31:0]   _zz_140_;
  wire       [31:0]   _zz_141_;
  reg        [31:0]   execute_to_memory_REGFILE_WRITE_DATA;
  reg        [31:0]   memory_to_writeBack_REGFILE_WRITE_DATA;
  reg        [31:0]   decode_to_execute_PC;
  reg        [31:0]   execute_to_memory_PC;
  reg        [31:0]   memory_to_writeBack_PC;
  reg                 decode_to_execute_CSR_WRITE_OPCODE;
  reg        `Src2CtrlEnum_defaultEncoding_type decode_to_execute_SRC2_CTRL;
  reg                 execute_to_memory_MMU_FAULT;
  reg        `AluCtrlEnum_defaultEncoding_type decode_to_execute_ALU_CTRL;
  reg                 decode_to_execute_SRC_USE_SUB_LESS;
  reg        [31:0]   execute_to_memory_BRANCH_CALC;
  reg                 decode_to_execute_BYPASSABLE_EXECUTE_STAGE;
  reg                 execute_to_memory_BRANCH_DO;
  reg        [31:0]   decode_to_execute_INSTRUCTION;
  reg        [31:0]   execute_to_memory_INSTRUCTION;
  reg        [31:0]   memory_to_writeBack_INSTRUCTION;
  reg        [1:0]    execute_to_memory_MEMORY_ADDRESS_LOW;
  reg        [1:0]    memory_to_writeBack_MEMORY_ADDRESS_LOW;
  reg                 decode_to_execute_REGFILE_WRITE_VALID;
  reg                 execute_to_memory_REGFILE_WRITE_VALID;
  reg                 memory_to_writeBack_REGFILE_WRITE_VALID;
  reg                 decode_to_execute_BYPASSABLE_MEMORY_STAGE;
  reg                 execute_to_memory_BYPASSABLE_MEMORY_STAGE;
  reg                 decode_to_execute_CSR_READ_OPCODE;
  reg        [31:0]   execute_to_memory_SHIFT_RIGHT;
  reg                 decode_to_execute_SRC_LESS_UNSIGNED;
  reg                 decode_to_execute_MEMORY_STORE;
  reg                 execute_to_memory_MEMORY_STORE;
  reg                 memory_to_writeBack_MEMORY_STORE;
  reg        `EnvCtrlEnum_defaultEncoding_type decode_to_execute_ENV_CTRL;
  reg        `EnvCtrlEnum_defaultEncoding_type execute_to_memory_ENV_CTRL;
  reg        `EnvCtrlEnum_defaultEncoding_type memory_to_writeBack_ENV_CTRL;
  reg        [31:0]   memory_to_writeBack_MEMORY_READ_DATA;
  reg        `ShiftCtrlEnum_defaultEncoding_type decode_to_execute_SHIFT_CTRL;
  reg        `ShiftCtrlEnum_defaultEncoding_type execute_to_memory_SHIFT_CTRL;
  reg        [31:0]   decode_to_execute_RS1;
  reg                 decode_to_execute_SRC2_FORCE_ZERO;
  reg        [31:0]   decode_to_execute_RS2;
  reg                 decode_to_execute_MEMORY_ENABLE;
  reg                 execute_to_memory_MEMORY_ENABLE;
  reg                 memory_to_writeBack_MEMORY_ENABLE;
  reg        `AluBitwiseCtrlEnum_defaultEncoding_type decode_to_execute_ALU_BITWISE_CTRL;
  reg                 decode_to_execute_IS_CSR;
  reg        `Src1CtrlEnum_defaultEncoding_type decode_to_execute_SRC1_CTRL;
  reg        [31:0]   execute_to_memory_MMU_RSP_physicalAddress;
  reg                 execute_to_memory_MMU_RSP_isIoAccess;
  reg                 execute_to_memory_MMU_RSP_allowRead;
  reg                 execute_to_memory_MMU_RSP_allowWrite;
  reg                 execute_to_memory_MMU_RSP_allowExecute;
  reg                 execute_to_memory_MMU_RSP_exception;
  reg                 execute_to_memory_MMU_RSP_refilling;
  reg                 decode_to_execute_PREDICTION_HAD_BRANCHED2;
  reg        `BranchCtrlEnum_defaultEncoding_type decode_to_execute_BRANCH_CTRL;
  reg        [31:0]   decode_to_execute_FORMAL_PC_NEXT;
  reg        [31:0]   execute_to_memory_FORMAL_PC_NEXT;
  reg        [31:0]   memory_to_writeBack_FORMAL_PC_NEXT;
  reg                 execute_CsrPlugin_csr_1984;
  reg                 execute_CsrPlugin_csr_768;
  reg                 execute_CsrPlugin_csr_836;
  reg                 execute_CsrPlugin_csr_772;
  reg                 execute_CsrPlugin_csr_773;
  reg                 execute_CsrPlugin_csr_833;
  reg                 execute_CsrPlugin_csr_834;
  reg                 execute_CsrPlugin_csr_835;
  reg                 execute_CsrPlugin_csr_3008;
  reg                 execute_CsrPlugin_csr_4032;
  reg        [31:0]   _zz_142_;
  reg        [31:0]   _zz_143_;
  reg        [31:0]   _zz_144_;
  reg        [31:0]   _zz_145_;
  reg        [31:0]   _zz_146_;
  reg        [31:0]   _zz_147_;
  reg        [31:0]   _zz_148_;
  reg        [31:0]   _zz_149_;
  wire                dBus_cmd_halfPipe_valid;
  wire                dBus_cmd_halfPipe_ready;
  wire                dBus_cmd_halfPipe_payload_wr;
  wire       [31:0]   dBus_cmd_halfPipe_payload_address;
  wire       [31:0]   dBus_cmd_halfPipe_payload_data;
  wire       [1:0]    dBus_cmd_halfPipe_payload_size;
  reg                 dBus_cmd_halfPipe_regs_valid;
  reg                 dBus_cmd_halfPipe_regs_ready;
  reg                 dBus_cmd_halfPipe_regs_payload_wr;
  reg        [31:0]   dBus_cmd_halfPipe_regs_payload_address;
  reg        [31:0]   dBus_cmd_halfPipe_regs_payload_data;
  reg        [1:0]    dBus_cmd_halfPipe_regs_payload_size;
  reg        [3:0]    _zz_150_;
  `ifndef SYNTHESIS
  reg [31:0] _zz_1__string;
  reg [31:0] _zz_2__string;
  reg [95:0] decode_SRC1_CTRL_string;
  reg [95:0] _zz_3__string;
  reg [95:0] _zz_4__string;
  reg [95:0] _zz_5__string;
  reg [39:0] decode_ALU_BITWISE_CTRL_string;
  reg [39:0] _zz_6__string;
  reg [39:0] _zz_7__string;
  reg [39:0] _zz_8__string;
  reg [71:0] _zz_9__string;
  reg [71:0] _zz_10__string;
  reg [71:0] decode_SHIFT_CTRL_string;
  reg [71:0] _zz_11__string;
  reg [71:0] _zz_12__string;
  reg [71:0] _zz_13__string;
  reg [39:0] _zz_14__string;
  reg [39:0] _zz_15__string;
  reg [39:0] _zz_16__string;
  reg [39:0] _zz_17__string;
  reg [39:0] decode_ENV_CTRL_string;
  reg [39:0] _zz_18__string;
  reg [39:0] _zz_19__string;
  reg [39:0] _zz_20__string;
  reg [63:0] decode_ALU_CTRL_string;
  reg [63:0] _zz_21__string;
  reg [63:0] _zz_22__string;
  reg [63:0] _zz_23__string;
  reg [23:0] decode_SRC2_CTRL_string;
  reg [23:0] _zz_24__string;
  reg [23:0] _zz_25__string;
  reg [23:0] _zz_26__string;
  reg [39:0] memory_ENV_CTRL_string;
  reg [39:0] _zz_27__string;
  reg [39:0] execute_ENV_CTRL_string;
  reg [39:0] _zz_28__string;
  reg [39:0] writeBack_ENV_CTRL_string;
  reg [39:0] _zz_29__string;
  reg [31:0] execute_BRANCH_CTRL_string;
  reg [31:0] _zz_30__string;
  reg [71:0] memory_SHIFT_CTRL_string;
  reg [71:0] _zz_33__string;
  reg [71:0] execute_SHIFT_CTRL_string;
  reg [71:0] _zz_34__string;
  reg [23:0] execute_SRC2_CTRL_string;
  reg [23:0] _zz_36__string;
  reg [95:0] execute_SRC1_CTRL_string;
  reg [95:0] _zz_37__string;
  reg [63:0] execute_ALU_CTRL_string;
  reg [63:0] _zz_38__string;
  reg [39:0] execute_ALU_BITWISE_CTRL_string;
  reg [39:0] _zz_39__string;
  reg [63:0] _zz_43__string;
  reg [39:0] _zz_44__string;
  reg [71:0] _zz_45__string;
  reg [95:0] _zz_46__string;
  reg [23:0] _zz_47__string;
  reg [31:0] _zz_48__string;
  reg [39:0] _zz_49__string;
  reg [31:0] decode_BRANCH_CTRL_string;
  reg [31:0] _zz_52__string;
  reg [39:0] _zz_93__string;
  reg [31:0] _zz_94__string;
  reg [23:0] _zz_95__string;
  reg [95:0] _zz_96__string;
  reg [71:0] _zz_97__string;
  reg [39:0] _zz_98__string;
  reg [63:0] _zz_99__string;
  reg [23:0] decode_to_execute_SRC2_CTRL_string;
  reg [63:0] decode_to_execute_ALU_CTRL_string;
  reg [39:0] decode_to_execute_ENV_CTRL_string;
  reg [39:0] execute_to_memory_ENV_CTRL_string;
  reg [39:0] memory_to_writeBack_ENV_CTRL_string;
  reg [71:0] decode_to_execute_SHIFT_CTRL_string;
  reg [71:0] execute_to_memory_SHIFT_CTRL_string;
  reg [39:0] decode_to_execute_ALU_BITWISE_CTRL_string;
  reg [95:0] decode_to_execute_SRC1_CTRL_string;
  reg [31:0] decode_to_execute_BRANCH_CTRL_string;
  `endif

  reg [31:0] RegFilePlugin_regFile [0:63] /* verilator public */ ;

  assign _zz_162_ = (execute_arbitration_isValid && execute_IS_CSR);
  assign _zz_163_ = (writeBack_arbitration_isValid && writeBack_REGFILE_WRITE_VALID);
  assign _zz_164_ = 1'b1;
  assign _zz_165_ = (memory_arbitration_isValid && memory_REGFILE_WRITE_VALID);
  assign _zz_166_ = (execute_arbitration_isValid && execute_REGFILE_WRITE_VALID);
  assign _zz_167_ = ((_zz_155_ && IBusCachedPlugin_cache_io_cpu_decode_cacheMiss) && (! _zz_51__0));
  assign _zz_168_ = ((_zz_155_ && IBusCachedPlugin_cache_io_cpu_decode_mmuRefilling) && (! IBusCachedPlugin_rsp_issueDetected));
  assign _zz_169_ = (CsrPlugin_hadException || CsrPlugin_interruptJump);
  assign _zz_170_ = (writeBack_arbitration_isValid && (writeBack_ENV_CTRL == `EnvCtrlEnum_defaultEncoding_XRET));
  assign _zz_171_ = writeBack_INSTRUCTION[29 : 28];
  assign _zz_172_ = (! ((memory_arbitration_isValid && memory_MEMORY_ENABLE) && (1'b1 || (! memory_arbitration_isStuckByOthers))));
  assign _zz_173_ = (writeBack_arbitration_isValid && writeBack_REGFILE_WRITE_VALID);
  assign _zz_174_ = (1'b0 || (! 1'b1));
  assign _zz_175_ = (memory_arbitration_isValid && memory_REGFILE_WRITE_VALID);
  assign _zz_176_ = (1'b0 || (! memory_BYPASSABLE_MEMORY_STAGE));
  assign _zz_177_ = (execute_arbitration_isValid && execute_REGFILE_WRITE_VALID);
  assign _zz_178_ = (1'b0 || (! execute_BYPASSABLE_EXECUTE_STAGE));
  assign _zz_179_ = (execute_arbitration_isValid && (execute_ENV_CTRL == `EnvCtrlEnum_defaultEncoding_ECALL));
  assign _zz_180_ = (CsrPlugin_mstatus_MIE || (CsrPlugin_privilege < (2'b11)));
  assign _zz_181_ = ((_zz_137_ && 1'b1) && (! 1'b0));
  assign _zz_182_ = ((_zz_138_ && 1'b1) && (! 1'b0));
  assign _zz_183_ = ((_zz_139_ && 1'b1) && (! 1'b0));
  assign _zz_184_ = (! dBus_cmd_halfPipe_regs_valid);
  assign _zz_185_ = writeBack_INSTRUCTION[13 : 12];
  assign _zz_186_ = execute_INSTRUCTION[13];
  assign _zz_187_ = _zz_88_[22 : 22];
  assign _zz_188_ = _zz_88_[1 : 1];
  assign _zz_189_ = _zz_88_[5 : 5];
  assign _zz_190_ = ($signed(_zz_192_) >>> execute_FullBarrelShifterPlugin_amplitude);
  assign _zz_191_ = _zz_190_[31 : 0];
  assign _zz_192_ = {((execute_SHIFT_CTRL == `ShiftCtrlEnum_defaultEncoding_SRA_1) && execute_FullBarrelShifterPlugin_reversed[31]),execute_FullBarrelShifterPlugin_reversed};
  assign _zz_193_ = _zz_88_[0 : 0];
  assign _zz_194_ = _zz_88_[19 : 19];
  assign _zz_195_ = _zz_88_[16 : 16];
  assign _zz_196_ = _zz_88_[25 : 25];
  assign _zz_197_ = _zz_88_[26 : 26];
  assign _zz_198_ = _zz_88_[20 : 20];
  assign _zz_199_ = _zz_88_[4 : 4];
  assign _zz_200_ = _zz_88_[10 : 10];
  assign _zz_201_ = _zz_88_[21 : 21];
  assign _zz_202_ = (_zz_55_ - (4'b0001));
  assign _zz_203_ = {IBusCachedPlugin_fetchPc_inc,(2'b00)};
  assign _zz_204_ = {29'd0, _zz_203_};
  assign _zz_205_ = {{{decode_INSTRUCTION[31],decode_INSTRUCTION[7]},decode_INSTRUCTION[30 : 25]},decode_INSTRUCTION[11 : 8]};
  assign _zz_206_ = {{_zz_70_,{{{decode_INSTRUCTION[31],decode_INSTRUCTION[7]},decode_INSTRUCTION[30 : 25]},decode_INSTRUCTION[11 : 8]}},1'b0};
  assign _zz_207_ = {{{decode_INSTRUCTION[31],decode_INSTRUCTION[19 : 12]},decode_INSTRUCTION[20]},decode_INSTRUCTION[30 : 21]};
  assign _zz_208_ = {{{decode_INSTRUCTION[31],decode_INSTRUCTION[7]},decode_INSTRUCTION[30 : 25]},decode_INSTRUCTION[11 : 8]};
  assign _zz_209_ = {{_zz_72_,{{{decode_INSTRUCTION[31],decode_INSTRUCTION[19 : 12]},decode_INSTRUCTION[20]},decode_INSTRUCTION[30 : 21]}},1'b0};
  assign _zz_210_ = {{_zz_74_,{{{decode_INSTRUCTION[31],decode_INSTRUCTION[7]},decode_INSTRUCTION[30 : 25]},decode_INSTRUCTION[11 : 8]}},1'b0};
  assign _zz_211_ = {{{decode_INSTRUCTION[31],decode_INSTRUCTION[19 : 12]},decode_INSTRUCTION[20]},decode_INSTRUCTION[30 : 21]};
  assign _zz_212_ = {{{decode_INSTRUCTION[31],decode_INSTRUCTION[7]},decode_INSTRUCTION[30 : 25]},decode_INSTRUCTION[11 : 8]};
  assign _zz_213_ = execute_SRC_LESS;
  assign _zz_214_ = (3'b100);
  assign _zz_215_ = execute_INSTRUCTION[19 : 15];
  assign _zz_216_ = execute_INSTRUCTION[31 : 20];
  assign _zz_217_ = {execute_INSTRUCTION[31 : 25],execute_INSTRUCTION[11 : 7]};
  assign _zz_218_ = ($signed(_zz_219_) + $signed(_zz_222_));
  assign _zz_219_ = ($signed(_zz_220_) + $signed(_zz_221_));
  assign _zz_220_ = execute_SRC1;
  assign _zz_221_ = (execute_SRC_USE_SUB_LESS ? (~ execute_SRC2) : execute_SRC2);
  assign _zz_222_ = (execute_SRC_USE_SUB_LESS ? _zz_223_ : _zz_224_);
  assign _zz_223_ = 32'h00000001;
  assign _zz_224_ = 32'h0;
  assign _zz_225_ = execute_INSTRUCTION[31 : 20];
  assign _zz_226_ = {{{execute_INSTRUCTION[31],execute_INSTRUCTION[19 : 12]},execute_INSTRUCTION[20]},execute_INSTRUCTION[30 : 21]};
  assign _zz_227_ = {{{execute_INSTRUCTION[31],execute_INSTRUCTION[7]},execute_INSTRUCTION[30 : 25]},execute_INSTRUCTION[11 : 8]};
  assign _zz_228_ = {_zz_125_,execute_INSTRUCTION[31 : 20]};
  assign _zz_229_ = {{_zz_127_,{{{execute_INSTRUCTION[31],execute_INSTRUCTION[19 : 12]},execute_INSTRUCTION[20]},execute_INSTRUCTION[30 : 21]}},1'b0};
  assign _zz_230_ = {{_zz_129_,{{{execute_INSTRUCTION[31],execute_INSTRUCTION[7]},execute_INSTRUCTION[30 : 25]},execute_INSTRUCTION[11 : 8]}},1'b0};
  assign _zz_231_ = execute_INSTRUCTION[31 : 20];
  assign _zz_232_ = {{{execute_INSTRUCTION[31],execute_INSTRUCTION[19 : 12]},execute_INSTRUCTION[20]},execute_INSTRUCTION[30 : 21]};
  assign _zz_233_ = {{{execute_INSTRUCTION[31],execute_INSTRUCTION[7]},execute_INSTRUCTION[30 : 25]},execute_INSTRUCTION[11 : 8]};
  assign _zz_234_ = (3'b100);
  assign _zz_235_ = execute_CsrPlugin_writeData[2 : 2];
  assign _zz_236_ = execute_CsrPlugin_writeData[1 : 1];
  assign _zz_237_ = execute_CsrPlugin_writeData[0 : 0];
  assign _zz_238_ = execute_CsrPlugin_writeData[7 : 7];
  assign _zz_239_ = execute_CsrPlugin_writeData[3 : 3];
  assign _zz_240_ = execute_CsrPlugin_writeData[3 : 3];
  assign _zz_241_ = execute_CsrPlugin_writeData[11 : 11];
  assign _zz_242_ = execute_CsrPlugin_writeData[7 : 7];
  assign _zz_243_ = execute_CsrPlugin_writeData[3 : 3];
  assign _zz_244_ = ({3'd0,_zz_150_} <<< dBus_cmd_halfPipe_payload_address[1 : 0]);
  assign _zz_245_ = 1'b1;
  assign _zz_246_ = 1'b1;
  assign _zz_247_ = {_zz_59_,_zz_58_};
  assign _zz_248_ = decode_INSTRUCTION[31];
  assign _zz_249_ = decode_INSTRUCTION[31];
  assign _zz_250_ = decode_INSTRUCTION[7];
  assign _zz_251_ = (decode_INSTRUCTION & 32'h00000044);
  assign _zz_252_ = 32'h00000040;
  assign _zz_253_ = ((decode_INSTRUCTION & _zz_264_) == 32'h00002010);
  assign _zz_254_ = ((decode_INSTRUCTION & _zz_265_) == 32'h40000030);
  assign _zz_255_ = ((decode_INSTRUCTION & _zz_266_) == 32'h0);
  assign _zz_256_ = (_zz_267_ == _zz_268_);
  assign _zz_257_ = {_zz_92_,_zz_269_};
  assign _zz_258_ = ((decode_INSTRUCTION & _zz_270_) == 32'h00004000);
  assign _zz_259_ = _zz_92_;
  assign _zz_260_ = (1'b0);
  assign _zz_261_ = ({_zz_271_,_zz_272_} != (2'b00));
  assign _zz_262_ = (_zz_273_ != _zz_274_);
  assign _zz_263_ = {_zz_275_,{_zz_276_,_zz_277_}};
  assign _zz_264_ = 32'h00002014;
  assign _zz_265_ = 32'h40000034;
  assign _zz_266_ = 32'h00000044;
  assign _zz_267_ = (decode_INSTRUCTION & 32'h00000018);
  assign _zz_268_ = 32'h0;
  assign _zz_269_ = ((decode_INSTRUCTION & 32'h00005004) == 32'h00001000);
  assign _zz_270_ = 32'h00004004;
  assign _zz_271_ = ((decode_INSTRUCTION & _zz_278_) == 32'h00001050);
  assign _zz_272_ = ((decode_INSTRUCTION & _zz_279_) == 32'h00002050);
  assign _zz_273_ = ((decode_INSTRUCTION & _zz_280_) == 32'h00001008);
  assign _zz_274_ = (1'b0);
  assign _zz_275_ = ((_zz_281_ == _zz_282_) != (1'b0));
  assign _zz_276_ = ({_zz_283_,_zz_284_} != (3'b000));
  assign _zz_277_ = {(_zz_285_ != _zz_286_),{_zz_287_,{_zz_288_,_zz_289_}}};
  assign _zz_278_ = 32'h00001050;
  assign _zz_279_ = 32'h00002050;
  assign _zz_280_ = 32'h00001048;
  assign _zz_281_ = (decode_INSTRUCTION & 32'h00000064);
  assign _zz_282_ = 32'h00000024;
  assign _zz_283_ = _zz_90_;
  assign _zz_284_ = {(_zz_290_ == _zz_291_),(_zz_292_ == _zz_293_)};
  assign _zz_285_ = ((decode_INSTRUCTION & _zz_294_) == 32'h00000050);
  assign _zz_286_ = (1'b0);
  assign _zz_287_ = ((_zz_295_ == _zz_296_) != (1'b0));
  assign _zz_288_ = ({_zz_297_,_zz_298_} != (2'b00));
  assign _zz_289_ = {(_zz_299_ != _zz_300_),{_zz_301_,{_zz_302_,_zz_303_}}};
  assign _zz_290_ = (decode_INSTRUCTION & 32'h00002050);
  assign _zz_291_ = 32'h00002010;
  assign _zz_292_ = (decode_INSTRUCTION & 32'h00001050);
  assign _zz_293_ = 32'h00000010;
  assign _zz_294_ = 32'h10003050;
  assign _zz_295_ = (decode_INSTRUCTION & 32'h10403050);
  assign _zz_296_ = 32'h10000050;
  assign _zz_297_ = ((decode_INSTRUCTION & _zz_304_) == 32'h00000020);
  assign _zz_298_ = ((decode_INSTRUCTION & _zz_305_) == 32'h00000020);
  assign _zz_299_ = ((decode_INSTRUCTION & _zz_306_) == 32'h00005010);
  assign _zz_300_ = (1'b0);
  assign _zz_301_ = ({_zz_307_,_zz_308_} != (2'b00));
  assign _zz_302_ = ({_zz_309_,_zz_310_} != (2'b00));
  assign _zz_303_ = {(_zz_311_ != _zz_312_),{_zz_313_,{_zz_314_,_zz_315_}}};
  assign _zz_304_ = 32'h00000034;
  assign _zz_305_ = 32'h00000064;
  assign _zz_306_ = 32'h00007054;
  assign _zz_307_ = ((decode_INSTRUCTION & 32'h40003054) == 32'h40001010);
  assign _zz_308_ = ((decode_INSTRUCTION & 32'h00007054) == 32'h00001010);
  assign _zz_309_ = ((decode_INSTRUCTION & _zz_316_) == 32'h00000040);
  assign _zz_310_ = ((decode_INSTRUCTION & _zz_317_) == 32'h00000040);
  assign _zz_311_ = {(_zz_318_ == _zz_319_),_zz_91_};
  assign _zz_312_ = (2'b00);
  assign _zz_313_ = ({_zz_320_,_zz_91_} != (2'b00));
  assign _zz_314_ = (_zz_321_ != (1'b0));
  assign _zz_315_ = {(_zz_322_ != _zz_323_),{_zz_324_,{_zz_325_,_zz_326_}}};
  assign _zz_316_ = 32'h00000050;
  assign _zz_317_ = 32'h00403040;
  assign _zz_318_ = (decode_INSTRUCTION & 32'h00000014);
  assign _zz_319_ = 32'h00000004;
  assign _zz_320_ = ((decode_INSTRUCTION & 32'h00000044) == 32'h00000004);
  assign _zz_321_ = ((decode_INSTRUCTION & 32'h00000058) == 32'h0);
  assign _zz_322_ = {_zz_90_,(_zz_327_ == _zz_328_)};
  assign _zz_323_ = (2'b00);
  assign _zz_324_ = ({_zz_90_,_zz_329_} != (2'b00));
  assign _zz_325_ = ({_zz_330_,_zz_331_} != (2'b00));
  assign _zz_326_ = {(_zz_332_ != _zz_333_),{_zz_334_,{_zz_335_,_zz_336_}}};
  assign _zz_327_ = (decode_INSTRUCTION & 32'h00000070);
  assign _zz_328_ = 32'h00000020;
  assign _zz_329_ = ((decode_INSTRUCTION & 32'h00000020) == 32'h0);
  assign _zz_330_ = _zz_89_;
  assign _zz_331_ = ((decode_INSTRUCTION & _zz_337_) == 32'h00000004);
  assign _zz_332_ = ((decode_INSTRUCTION & _zz_338_) == 32'h00000040);
  assign _zz_333_ = (1'b0);
  assign _zz_334_ = ({_zz_339_,_zz_340_} != (2'b00));
  assign _zz_335_ = ({_zz_341_,_zz_342_} != 6'h0);
  assign _zz_336_ = {(_zz_343_ != _zz_344_),{_zz_345_,{_zz_346_,_zz_347_}}};
  assign _zz_337_ = 32'h0000001c;
  assign _zz_338_ = 32'h00000058;
  assign _zz_339_ = ((decode_INSTRUCTION & 32'h00002010) == 32'h00002000);
  assign _zz_340_ = ((decode_INSTRUCTION & 32'h00005000) == 32'h00001000);
  assign _zz_341_ = _zz_89_;
  assign _zz_342_ = {(_zz_348_ == _zz_349_),{_zz_350_,{_zz_351_,_zz_352_}}};
  assign _zz_343_ = ((decode_INSTRUCTION & _zz_353_) == 32'h00001000);
  assign _zz_344_ = (1'b0);
  assign _zz_345_ = ((_zz_354_ == _zz_355_) != (1'b0));
  assign _zz_346_ = (_zz_356_ != (1'b0));
  assign _zz_347_ = (_zz_357_ != (1'b0));
  assign _zz_348_ = (decode_INSTRUCTION & 32'h00001010);
  assign _zz_349_ = 32'h00001010;
  assign _zz_350_ = ((decode_INSTRUCTION & 32'h00002010) == 32'h00002010);
  assign _zz_351_ = ((decode_INSTRUCTION & 32'h00000050) == 32'h00000010);
  assign _zz_352_ = {((decode_INSTRUCTION & 32'h0000000c) == 32'h00000004),((decode_INSTRUCTION & 32'h00000028) == 32'h0)};
  assign _zz_353_ = 32'h00001000;
  assign _zz_354_ = (decode_INSTRUCTION & 32'h00003000);
  assign _zz_355_ = 32'h00002000;
  assign _zz_356_ = ((decode_INSTRUCTION & 32'h00000020) == 32'h00000020);
  assign _zz_357_ = ((decode_INSTRUCTION & 32'h00000010) == 32'h00000010);
  assign _zz_358_ = execute_INSTRUCTION[31];
  assign _zz_359_ = execute_INSTRUCTION[31];
  assign _zz_360_ = execute_INSTRUCTION[7];
  always @ (posedge clk) begin
    if(_zz_245_) begin
      _zz_159_ <= RegFilePlugin_regFile[decode_RegFilePlugin_regFileReadAddress1];
    end
  end

  always @ (posedge clk) begin
    if(_zz_246_) begin
      _zz_160_ <= RegFilePlugin_regFile[decode_RegFilePlugin_regFileReadAddress2];
    end
  end

  always @ (posedge clk) begin
    if(_zz_42_) begin
      RegFilePlugin_regFile[lastStageRegFileWrite_payload_address] <= lastStageRegFileWrite_payload_data;
    end
  end

  InstructionCache IBusCachedPlugin_cache ( 
    .io_flush                                     (_zz_151_                                                             ), //i
    .io_cpu_prefetch_isValid                      (_zz_152_                                                             ), //i
    .io_cpu_prefetch_haltIt                       (IBusCachedPlugin_cache_io_cpu_prefetch_haltIt                        ), //o
    .io_cpu_prefetch_pc                           (IBusCachedPlugin_iBusRsp_stages_0_input_payload[31:0]                ), //i
    .io_cpu_fetch_isValid                         (_zz_153_                                                             ), //i
    .io_cpu_fetch_isStuck                         (_zz_154_                                                             ), //i
    .io_cpu_fetch_isRemoved                       (IBusCachedPlugin_externalFlush                                       ), //i
    .io_cpu_fetch_pc                              (IBusCachedPlugin_iBusRsp_stages_1_input_payload[31:0]                ), //i
    .io_cpu_fetch_data                            (IBusCachedPlugin_cache_io_cpu_fetch_data[31:0]                       ), //o
    .io_cpu_fetch_mmuBus_cmd_isValid              (IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_isValid               ), //o
    .io_cpu_fetch_mmuBus_cmd_virtualAddress       (IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_virtualAddress[31:0]  ), //o
    .io_cpu_fetch_mmuBus_cmd_bypassTranslation    (IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_bypassTranslation     ), //o
    .io_cpu_fetch_mmuBus_rsp_physicalAddress      (IBusCachedPlugin_mmuBus_rsp_physicalAddress[31:0]                    ), //i
    .io_cpu_fetch_mmuBus_rsp_isIoAccess           (IBusCachedPlugin_mmuBus_rsp_isIoAccess                               ), //i
    .io_cpu_fetch_mmuBus_rsp_allowRead            (IBusCachedPlugin_mmuBus_rsp_allowRead                                ), //i
    .io_cpu_fetch_mmuBus_rsp_allowWrite           (IBusCachedPlugin_mmuBus_rsp_allowWrite                               ), //i
    .io_cpu_fetch_mmuBus_rsp_allowExecute         (IBusCachedPlugin_mmuBus_rsp_allowExecute                             ), //i
    .io_cpu_fetch_mmuBus_rsp_exception            (IBusCachedPlugin_mmuBus_rsp_exception                                ), //i
    .io_cpu_fetch_mmuBus_rsp_refilling            (IBusCachedPlugin_mmuBus_rsp_refilling                                ), //i
    .io_cpu_fetch_mmuBus_end                      (IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_end                       ), //o
    .io_cpu_fetch_mmuBus_busy                     (IBusCachedPlugin_mmuBus_busy                                         ), //i
    .io_cpu_fetch_physicalAddress                 (IBusCachedPlugin_cache_io_cpu_fetch_physicalAddress[31:0]            ), //o
    .io_cpu_fetch_haltIt                          (IBusCachedPlugin_cache_io_cpu_fetch_haltIt                           ), //o
    .io_cpu_decode_isValid                        (_zz_155_                                                             ), //i
    .io_cpu_decode_isStuck                        (_zz_156_                                                             ), //i
    .io_cpu_decode_pc                             (IBusCachedPlugin_iBusRsp_stages_2_input_payload[31:0]                ), //i
    .io_cpu_decode_physicalAddress                (IBusCachedPlugin_cache_io_cpu_decode_physicalAddress[31:0]           ), //o
    .io_cpu_decode_data                           (IBusCachedPlugin_cache_io_cpu_decode_data[31:0]                      ), //o
    .io_cpu_decode_cacheMiss                      (IBusCachedPlugin_cache_io_cpu_decode_cacheMiss                       ), //o
    .io_cpu_decode_error                          (IBusCachedPlugin_cache_io_cpu_decode_error                           ), //o
    .io_cpu_decode_mmuRefilling                   (IBusCachedPlugin_cache_io_cpu_decode_mmuRefilling                    ), //o
    .io_cpu_decode_mmuException                   (IBusCachedPlugin_cache_io_cpu_decode_mmuException                    ), //o
    .io_cpu_decode_isUser                         (_zz_157_                                                             ), //i
    .io_cpu_fill_valid                            (_zz_158_                                                             ), //i
    .io_cpu_fill_payload                          (IBusCachedPlugin_cache_io_cpu_decode_physicalAddress[31:0]           ), //i
    .io_mem_cmd_valid                             (IBusCachedPlugin_cache_io_mem_cmd_valid                              ), //o
    .io_mem_cmd_ready                             (iBus_cmd_ready                                                       ), //i
    .io_mem_cmd_payload_address                   (IBusCachedPlugin_cache_io_mem_cmd_payload_address[31:0]              ), //o
    .io_mem_cmd_payload_size                      (IBusCachedPlugin_cache_io_mem_cmd_payload_size[2:0]                  ), //o
    .io_mem_rsp_valid                             (iBus_rsp_valid                                                       ), //i
    .io_mem_rsp_payload_data                      (iBus_rsp_payload_data[31:0]                                          ), //i
    .io_mem_rsp_payload_error                     (iBus_rsp_payload_error                                               ), //i
    .clk                                          (clk                                                                  ), //i
    .reset                                        (reset                                                                )  //i
  );
  always @(*) begin
    case(_zz_247_)
      2'b00 : begin
        _zz_161_ = CsrPlugin_jumpInterface_payload;
      end
      2'b01 : begin
        _zz_161_ = DBusSimplePlugin_redoBranch_payload;
      end
      2'b10 : begin
        _zz_161_ = BranchPlugin_jumpInterface_payload;
      end
      default : begin
        _zz_161_ = IBusCachedPlugin_predictionJumpInterface_payload;
      end
    endcase
  end

  `ifndef SYNTHESIS
  always @(*) begin
    case(_zz_1_)
      `BranchCtrlEnum_defaultEncoding_INC : _zz_1__string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : _zz_1__string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : _zz_1__string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : _zz_1__string = "JALR";
      default : _zz_1__string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_2_)
      `BranchCtrlEnum_defaultEncoding_INC : _zz_2__string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : _zz_2__string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : _zz_2__string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : _zz_2__string = "JALR";
      default : _zz_2__string = "????";
    endcase
  end
  always @(*) begin
    case(decode_SRC1_CTRL)
      `Src1CtrlEnum_defaultEncoding_RS : decode_SRC1_CTRL_string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : decode_SRC1_CTRL_string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : decode_SRC1_CTRL_string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : decode_SRC1_CTRL_string = "URS1        ";
      default : decode_SRC1_CTRL_string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_3_)
      `Src1CtrlEnum_defaultEncoding_RS : _zz_3__string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : _zz_3__string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : _zz_3__string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : _zz_3__string = "URS1        ";
      default : _zz_3__string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_4_)
      `Src1CtrlEnum_defaultEncoding_RS : _zz_4__string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : _zz_4__string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : _zz_4__string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : _zz_4__string = "URS1        ";
      default : _zz_4__string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_5_)
      `Src1CtrlEnum_defaultEncoding_RS : _zz_5__string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : _zz_5__string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : _zz_5__string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : _zz_5__string = "URS1        ";
      default : _zz_5__string = "????????????";
    endcase
  end
  always @(*) begin
    case(decode_ALU_BITWISE_CTRL)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : decode_ALU_BITWISE_CTRL_string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : decode_ALU_BITWISE_CTRL_string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : decode_ALU_BITWISE_CTRL_string = "AND_1";
      default : decode_ALU_BITWISE_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_6_)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : _zz_6__string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : _zz_6__string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : _zz_6__string = "AND_1";
      default : _zz_6__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_7_)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : _zz_7__string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : _zz_7__string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : _zz_7__string = "AND_1";
      default : _zz_7__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_8_)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : _zz_8__string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : _zz_8__string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : _zz_8__string = "AND_1";
      default : _zz_8__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_9_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_9__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_9__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_9__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_9__string = "SRA_1    ";
      default : _zz_9__string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_10_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_10__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_10__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_10__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_10__string = "SRA_1    ";
      default : _zz_10__string = "?????????";
    endcase
  end
  always @(*) begin
    case(decode_SHIFT_CTRL)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : decode_SHIFT_CTRL_string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : decode_SHIFT_CTRL_string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : decode_SHIFT_CTRL_string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : decode_SHIFT_CTRL_string = "SRA_1    ";
      default : decode_SHIFT_CTRL_string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_11_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_11__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_11__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_11__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_11__string = "SRA_1    ";
      default : _zz_11__string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_12_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_12__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_12__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_12__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_12__string = "SRA_1    ";
      default : _zz_12__string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_13_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_13__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_13__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_13__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_13__string = "SRA_1    ";
      default : _zz_13__string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_14_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_14__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_14__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_14__string = "ECALL";
      default : _zz_14__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_15_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_15__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_15__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_15__string = "ECALL";
      default : _zz_15__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_16_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_16__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_16__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_16__string = "ECALL";
      default : _zz_16__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_17_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_17__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_17__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_17__string = "ECALL";
      default : _zz_17__string = "?????";
    endcase
  end
  always @(*) begin
    case(decode_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : decode_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : decode_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : decode_ENV_CTRL_string = "ECALL";
      default : decode_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_18_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_18__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_18__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_18__string = "ECALL";
      default : _zz_18__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_19_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_19__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_19__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_19__string = "ECALL";
      default : _zz_19__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_20_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_20__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_20__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_20__string = "ECALL";
      default : _zz_20__string = "?????";
    endcase
  end
  always @(*) begin
    case(decode_ALU_CTRL)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : decode_ALU_CTRL_string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : decode_ALU_CTRL_string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : decode_ALU_CTRL_string = "BITWISE ";
      default : decode_ALU_CTRL_string = "????????";
    endcase
  end
  always @(*) begin
    case(_zz_21_)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : _zz_21__string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : _zz_21__string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : _zz_21__string = "BITWISE ";
      default : _zz_21__string = "????????";
    endcase
  end
  always @(*) begin
    case(_zz_22_)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : _zz_22__string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : _zz_22__string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : _zz_22__string = "BITWISE ";
      default : _zz_22__string = "????????";
    endcase
  end
  always @(*) begin
    case(_zz_23_)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : _zz_23__string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : _zz_23__string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : _zz_23__string = "BITWISE ";
      default : _zz_23__string = "????????";
    endcase
  end
  always @(*) begin
    case(decode_SRC2_CTRL)
      `Src2CtrlEnum_defaultEncoding_RS : decode_SRC2_CTRL_string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : decode_SRC2_CTRL_string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : decode_SRC2_CTRL_string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : decode_SRC2_CTRL_string = "PC ";
      default : decode_SRC2_CTRL_string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_24_)
      `Src2CtrlEnum_defaultEncoding_RS : _zz_24__string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : _zz_24__string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : _zz_24__string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : _zz_24__string = "PC ";
      default : _zz_24__string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_25_)
      `Src2CtrlEnum_defaultEncoding_RS : _zz_25__string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : _zz_25__string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : _zz_25__string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : _zz_25__string = "PC ";
      default : _zz_25__string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_26_)
      `Src2CtrlEnum_defaultEncoding_RS : _zz_26__string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : _zz_26__string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : _zz_26__string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : _zz_26__string = "PC ";
      default : _zz_26__string = "???";
    endcase
  end
  always @(*) begin
    case(memory_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : memory_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : memory_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : memory_ENV_CTRL_string = "ECALL";
      default : memory_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_27_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_27__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_27__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_27__string = "ECALL";
      default : _zz_27__string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : execute_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : execute_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : execute_ENV_CTRL_string = "ECALL";
      default : execute_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_28_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_28__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_28__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_28__string = "ECALL";
      default : _zz_28__string = "?????";
    endcase
  end
  always @(*) begin
    case(writeBack_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : writeBack_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : writeBack_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : writeBack_ENV_CTRL_string = "ECALL";
      default : writeBack_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_29_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_29__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_29__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_29__string = "ECALL";
      default : _zz_29__string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_INC : execute_BRANCH_CTRL_string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : execute_BRANCH_CTRL_string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : execute_BRANCH_CTRL_string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : execute_BRANCH_CTRL_string = "JALR";
      default : execute_BRANCH_CTRL_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_30_)
      `BranchCtrlEnum_defaultEncoding_INC : _zz_30__string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : _zz_30__string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : _zz_30__string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : _zz_30__string = "JALR";
      default : _zz_30__string = "????";
    endcase
  end
  always @(*) begin
    case(memory_SHIFT_CTRL)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : memory_SHIFT_CTRL_string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : memory_SHIFT_CTRL_string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : memory_SHIFT_CTRL_string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : memory_SHIFT_CTRL_string = "SRA_1    ";
      default : memory_SHIFT_CTRL_string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_33_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_33__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_33__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_33__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_33__string = "SRA_1    ";
      default : _zz_33__string = "?????????";
    endcase
  end
  always @(*) begin
    case(execute_SHIFT_CTRL)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : execute_SHIFT_CTRL_string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : execute_SHIFT_CTRL_string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : execute_SHIFT_CTRL_string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : execute_SHIFT_CTRL_string = "SRA_1    ";
      default : execute_SHIFT_CTRL_string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_34_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_34__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_34__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_34__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_34__string = "SRA_1    ";
      default : _zz_34__string = "?????????";
    endcase
  end
  always @(*) begin
    case(execute_SRC2_CTRL)
      `Src2CtrlEnum_defaultEncoding_RS : execute_SRC2_CTRL_string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : execute_SRC2_CTRL_string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : execute_SRC2_CTRL_string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : execute_SRC2_CTRL_string = "PC ";
      default : execute_SRC2_CTRL_string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_36_)
      `Src2CtrlEnum_defaultEncoding_RS : _zz_36__string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : _zz_36__string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : _zz_36__string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : _zz_36__string = "PC ";
      default : _zz_36__string = "???";
    endcase
  end
  always @(*) begin
    case(execute_SRC1_CTRL)
      `Src1CtrlEnum_defaultEncoding_RS : execute_SRC1_CTRL_string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : execute_SRC1_CTRL_string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : execute_SRC1_CTRL_string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : execute_SRC1_CTRL_string = "URS1        ";
      default : execute_SRC1_CTRL_string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_37_)
      `Src1CtrlEnum_defaultEncoding_RS : _zz_37__string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : _zz_37__string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : _zz_37__string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : _zz_37__string = "URS1        ";
      default : _zz_37__string = "????????????";
    endcase
  end
  always @(*) begin
    case(execute_ALU_CTRL)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : execute_ALU_CTRL_string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : execute_ALU_CTRL_string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : execute_ALU_CTRL_string = "BITWISE ";
      default : execute_ALU_CTRL_string = "????????";
    endcase
  end
  always @(*) begin
    case(_zz_38_)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : _zz_38__string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : _zz_38__string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : _zz_38__string = "BITWISE ";
      default : _zz_38__string = "????????";
    endcase
  end
  always @(*) begin
    case(execute_ALU_BITWISE_CTRL)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : execute_ALU_BITWISE_CTRL_string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : execute_ALU_BITWISE_CTRL_string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : execute_ALU_BITWISE_CTRL_string = "AND_1";
      default : execute_ALU_BITWISE_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_39_)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : _zz_39__string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : _zz_39__string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : _zz_39__string = "AND_1";
      default : _zz_39__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_43_)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : _zz_43__string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : _zz_43__string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : _zz_43__string = "BITWISE ";
      default : _zz_43__string = "????????";
    endcase
  end
  always @(*) begin
    case(_zz_44_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_44__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_44__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_44__string = "ECALL";
      default : _zz_44__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_45_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_45__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_45__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_45__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_45__string = "SRA_1    ";
      default : _zz_45__string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_46_)
      `Src1CtrlEnum_defaultEncoding_RS : _zz_46__string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : _zz_46__string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : _zz_46__string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : _zz_46__string = "URS1        ";
      default : _zz_46__string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_47_)
      `Src2CtrlEnum_defaultEncoding_RS : _zz_47__string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : _zz_47__string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : _zz_47__string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : _zz_47__string = "PC ";
      default : _zz_47__string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_48_)
      `BranchCtrlEnum_defaultEncoding_INC : _zz_48__string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : _zz_48__string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : _zz_48__string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : _zz_48__string = "JALR";
      default : _zz_48__string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_49_)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : _zz_49__string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : _zz_49__string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : _zz_49__string = "AND_1";
      default : _zz_49__string = "?????";
    endcase
  end
  always @(*) begin
    case(decode_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_INC : decode_BRANCH_CTRL_string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : decode_BRANCH_CTRL_string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : decode_BRANCH_CTRL_string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : decode_BRANCH_CTRL_string = "JALR";
      default : decode_BRANCH_CTRL_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_52_)
      `BranchCtrlEnum_defaultEncoding_INC : _zz_52__string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : _zz_52__string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : _zz_52__string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : _zz_52__string = "JALR";
      default : _zz_52__string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_93_)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : _zz_93__string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : _zz_93__string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : _zz_93__string = "AND_1";
      default : _zz_93__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_94_)
      `BranchCtrlEnum_defaultEncoding_INC : _zz_94__string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : _zz_94__string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : _zz_94__string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : _zz_94__string = "JALR";
      default : _zz_94__string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_95_)
      `Src2CtrlEnum_defaultEncoding_RS : _zz_95__string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : _zz_95__string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : _zz_95__string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : _zz_95__string = "PC ";
      default : _zz_95__string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_96_)
      `Src1CtrlEnum_defaultEncoding_RS : _zz_96__string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : _zz_96__string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : _zz_96__string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : _zz_96__string = "URS1        ";
      default : _zz_96__string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_97_)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : _zz_97__string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : _zz_97__string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : _zz_97__string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : _zz_97__string = "SRA_1    ";
      default : _zz_97__string = "?????????";
    endcase
  end
  always @(*) begin
    case(_zz_98_)
      `EnvCtrlEnum_defaultEncoding_NONE : _zz_98__string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : _zz_98__string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : _zz_98__string = "ECALL";
      default : _zz_98__string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_99_)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : _zz_99__string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : _zz_99__string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : _zz_99__string = "BITWISE ";
      default : _zz_99__string = "????????";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_SRC2_CTRL)
      `Src2CtrlEnum_defaultEncoding_RS : decode_to_execute_SRC2_CTRL_string = "RS ";
      `Src2CtrlEnum_defaultEncoding_IMI : decode_to_execute_SRC2_CTRL_string = "IMI";
      `Src2CtrlEnum_defaultEncoding_IMS : decode_to_execute_SRC2_CTRL_string = "IMS";
      `Src2CtrlEnum_defaultEncoding_PC : decode_to_execute_SRC2_CTRL_string = "PC ";
      default : decode_to_execute_SRC2_CTRL_string = "???";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_ALU_CTRL)
      `AluCtrlEnum_defaultEncoding_ADD_SUB : decode_to_execute_ALU_CTRL_string = "ADD_SUB ";
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : decode_to_execute_ALU_CTRL_string = "SLT_SLTU";
      `AluCtrlEnum_defaultEncoding_BITWISE : decode_to_execute_ALU_CTRL_string = "BITWISE ";
      default : decode_to_execute_ALU_CTRL_string = "????????";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : decode_to_execute_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : decode_to_execute_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : decode_to_execute_ENV_CTRL_string = "ECALL";
      default : decode_to_execute_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_to_memory_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : execute_to_memory_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : execute_to_memory_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : execute_to_memory_ENV_CTRL_string = "ECALL";
      default : execute_to_memory_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(memory_to_writeBack_ENV_CTRL)
      `EnvCtrlEnum_defaultEncoding_NONE : memory_to_writeBack_ENV_CTRL_string = "NONE ";
      `EnvCtrlEnum_defaultEncoding_XRET : memory_to_writeBack_ENV_CTRL_string = "XRET ";
      `EnvCtrlEnum_defaultEncoding_ECALL : memory_to_writeBack_ENV_CTRL_string = "ECALL";
      default : memory_to_writeBack_ENV_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_SHIFT_CTRL)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : decode_to_execute_SHIFT_CTRL_string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : decode_to_execute_SHIFT_CTRL_string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : decode_to_execute_SHIFT_CTRL_string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : decode_to_execute_SHIFT_CTRL_string = "SRA_1    ";
      default : decode_to_execute_SHIFT_CTRL_string = "?????????";
    endcase
  end
  always @(*) begin
    case(execute_to_memory_SHIFT_CTRL)
      `ShiftCtrlEnum_defaultEncoding_DISABLE_1 : execute_to_memory_SHIFT_CTRL_string = "DISABLE_1";
      `ShiftCtrlEnum_defaultEncoding_SLL_1 : execute_to_memory_SHIFT_CTRL_string = "SLL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRL_1 : execute_to_memory_SHIFT_CTRL_string = "SRL_1    ";
      `ShiftCtrlEnum_defaultEncoding_SRA_1 : execute_to_memory_SHIFT_CTRL_string = "SRA_1    ";
      default : execute_to_memory_SHIFT_CTRL_string = "?????????";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_ALU_BITWISE_CTRL)
      `AluBitwiseCtrlEnum_defaultEncoding_XOR_1 : decode_to_execute_ALU_BITWISE_CTRL_string = "XOR_1";
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : decode_to_execute_ALU_BITWISE_CTRL_string = "OR_1 ";
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : decode_to_execute_ALU_BITWISE_CTRL_string = "AND_1";
      default : decode_to_execute_ALU_BITWISE_CTRL_string = "?????";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_SRC1_CTRL)
      `Src1CtrlEnum_defaultEncoding_RS : decode_to_execute_SRC1_CTRL_string = "RS          ";
      `Src1CtrlEnum_defaultEncoding_IMU : decode_to_execute_SRC1_CTRL_string = "IMU         ";
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : decode_to_execute_SRC1_CTRL_string = "PC_INCREMENT";
      `Src1CtrlEnum_defaultEncoding_URS1 : decode_to_execute_SRC1_CTRL_string = "URS1        ";
      default : decode_to_execute_SRC1_CTRL_string = "????????????";
    endcase
  end
  always @(*) begin
    case(decode_to_execute_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_INC : decode_to_execute_BRANCH_CTRL_string = "INC ";
      `BranchCtrlEnum_defaultEncoding_B : decode_to_execute_BRANCH_CTRL_string = "B   ";
      `BranchCtrlEnum_defaultEncoding_JAL : decode_to_execute_BRANCH_CTRL_string = "JAL ";
      `BranchCtrlEnum_defaultEncoding_JALR : decode_to_execute_BRANCH_CTRL_string = "JALR";
      default : decode_to_execute_BRANCH_CTRL_string = "????";
    endcase
  end
  `endif

  assign writeBack_FORMAL_PC_NEXT = memory_to_writeBack_FORMAL_PC_NEXT;
  assign memory_FORMAL_PC_NEXT = execute_to_memory_FORMAL_PC_NEXT;
  assign execute_FORMAL_PC_NEXT = decode_to_execute_FORMAL_PC_NEXT;
  assign decode_FORMAL_PC_NEXT = (decode_PC + 32'h00000004);
  assign _zz_1_ = _zz_2_;
  assign decode_PREDICTION_HAD_BRANCHED2 = IBusCachedPlugin_decodePrediction_cmd_hadBranch;
  assign decode_SRC1_CTRL = _zz_3_;
  assign _zz_4_ = _zz_5_;
  assign decode_IS_CSR = _zz_187_[0];
  assign decode_ALU_BITWISE_CTRL = _zz_6_;
  assign _zz_7_ = _zz_8_;
  assign decode_SRC2_FORCE_ZERO = (decode_SRC_ADD_ZERO && (! decode_SRC_USE_SUB_LESS));
  assign _zz_9_ = _zz_10_;
  assign decode_SHIFT_CTRL = _zz_11_;
  assign _zz_12_ = _zz_13_;
  assign memory_MEMORY_READ_DATA = dBus_rsp_data;
  assign _zz_14_ = _zz_15_;
  assign _zz_16_ = _zz_17_;
  assign decode_ENV_CTRL = _zz_18_;
  assign _zz_19_ = _zz_20_;
  assign decode_MEMORY_STORE = _zz_188_[0];
  assign decode_SRC_LESS_UNSIGNED = _zz_189_[0];
  assign execute_SHIFT_RIGHT = _zz_191_;
  assign decode_CSR_READ_OPCODE = (decode_INSTRUCTION[13 : 7] != 7'h20);
  assign execute_BYPASSABLE_MEMORY_STAGE = decode_to_execute_BYPASSABLE_MEMORY_STAGE;
  assign decode_BYPASSABLE_MEMORY_STAGE = _zz_193_[0];
  assign memory_MEMORY_ADDRESS_LOW = execute_to_memory_MEMORY_ADDRESS_LOW;
  assign execute_MEMORY_ADDRESS_LOW = dBus_cmd_payload_address[1 : 0];
  assign execute_BRANCH_DO = ((execute_PREDICTION_HAD_BRANCHED2 != execute_BRANCH_COND_RESULT) || execute_BranchPlugin_missAlignedTarget);
  assign decode_BYPASSABLE_EXECUTE_STAGE = _zz_194_[0];
  assign execute_BRANCH_CALC = {execute_BranchPlugin_branchAdder[31 : 1],(1'b0)};
  assign decode_ALU_CTRL = _zz_21_;
  assign _zz_22_ = _zz_23_;
  assign decode_SRC2_CTRL = _zz_24_;
  assign _zz_25_ = _zz_26_;
  assign decode_CSR_WRITE_OPCODE = (! (((decode_INSTRUCTION[14 : 13] == (2'b01)) && (decode_INSTRUCTION[19 : 15] == 5'h0)) || ((decode_INSTRUCTION[14 : 13] == (2'b11)) && (decode_INSTRUCTION[19 : 15] == 5'h0))));
  assign writeBack_REGFILE_WRITE_DATA = memory_to_writeBack_REGFILE_WRITE_DATA;
  assign execute_REGFILE_WRITE_DATA = _zz_101_;
  assign execute_CSR_READ_OPCODE = decode_to_execute_CSR_READ_OPCODE;
  assign execute_CSR_WRITE_OPCODE = decode_to_execute_CSR_WRITE_OPCODE;
  assign execute_IS_CSR = decode_to_execute_IS_CSR;
  assign memory_ENV_CTRL = _zz_27_;
  assign execute_ENV_CTRL = _zz_28_;
  assign writeBack_ENV_CTRL = _zz_29_;
  assign memory_BRANCH_CALC = execute_to_memory_BRANCH_CALC;
  assign memory_BRANCH_DO = execute_to_memory_BRANCH_DO;
  assign execute_PC = decode_to_execute_PC;
  assign execute_PREDICTION_HAD_BRANCHED2 = decode_to_execute_PREDICTION_HAD_BRANCHED2;
  assign execute_RS1 = decode_to_execute_RS1;
  assign execute_BRANCH_COND_RESULT = _zz_123_;
  assign execute_BRANCH_CTRL = _zz_30_;
  assign decode_RS2_USE = _zz_195_[0];
  assign decode_RS1_USE = _zz_196_[0];
  always @ (*) begin
    _zz_31_ = execute_REGFILE_WRITE_DATA;
    if(_zz_162_)begin
      _zz_31_ = execute_CsrPlugin_readData;
    end
  end

  assign execute_REGFILE_WRITE_VALID = decode_to_execute_REGFILE_WRITE_VALID;
  assign execute_BYPASSABLE_EXECUTE_STAGE = decode_to_execute_BYPASSABLE_EXECUTE_STAGE;
  assign memory_REGFILE_WRITE_VALID = execute_to_memory_REGFILE_WRITE_VALID;
  assign memory_INSTRUCTION = execute_to_memory_INSTRUCTION;
  assign memory_BYPASSABLE_MEMORY_STAGE = execute_to_memory_BYPASSABLE_MEMORY_STAGE;
  assign writeBack_REGFILE_WRITE_VALID = memory_to_writeBack_REGFILE_WRITE_VALID;
  always @ (*) begin
    decode_RS2 = decode_RegFilePlugin_rs2Data;
    if(_zz_112_)begin
      if((_zz_113_ == decode_INSTRUCTION[24 : 20]))begin
        decode_RS2 = _zz_114_;
      end
    end
    if(_zz_163_)begin
      if(_zz_164_)begin
        if(_zz_116_)begin
          decode_RS2 = _zz_50_;
        end
      end
    end
    if(_zz_165_)begin
      if(memory_BYPASSABLE_MEMORY_STAGE)begin
        if(_zz_118_)begin
          decode_RS2 = _zz_32_;
        end
      end
    end
    if(_zz_166_)begin
      if(execute_BYPASSABLE_EXECUTE_STAGE)begin
        if(_zz_120_)begin
          decode_RS2 = _zz_31_;
        end
      end
    end
  end

  always @ (*) begin
    decode_RS1 = decode_RegFilePlugin_rs1Data;
    if(_zz_112_)begin
      if((_zz_113_ == decode_INSTRUCTION[19 : 15]))begin
        decode_RS1 = _zz_114_;
      end
    end
    if(_zz_163_)begin
      if(_zz_164_)begin
        if(_zz_115_)begin
          decode_RS1 = _zz_50_;
        end
      end
    end
    if(_zz_165_)begin
      if(memory_BYPASSABLE_MEMORY_STAGE)begin
        if(_zz_117_)begin
          decode_RS1 = _zz_32_;
        end
      end
    end
    if(_zz_166_)begin
      if(execute_BYPASSABLE_EXECUTE_STAGE)begin
        if(_zz_119_)begin
          decode_RS1 = _zz_31_;
        end
      end
    end
  end

  assign memory_SHIFT_RIGHT = execute_to_memory_SHIFT_RIGHT;
  always @ (*) begin
    _zz_32_ = memory_REGFILE_WRITE_DATA;
    if(memory_arbitration_isValid)begin
      case(memory_SHIFT_CTRL)
        `ShiftCtrlEnum_defaultEncoding_SLL_1 : begin
          _zz_32_ = _zz_109_;
        end
        `ShiftCtrlEnum_defaultEncoding_SRL_1, `ShiftCtrlEnum_defaultEncoding_SRA_1 : begin
          _zz_32_ = memory_SHIFT_RIGHT;
        end
        default : begin
        end
      endcase
    end
  end

  assign memory_SHIFT_CTRL = _zz_33_;
  assign execute_SHIFT_CTRL = _zz_34_;
  assign execute_SRC_LESS_UNSIGNED = decode_to_execute_SRC_LESS_UNSIGNED;
  assign execute_SRC2_FORCE_ZERO = decode_to_execute_SRC2_FORCE_ZERO;
  assign execute_SRC_USE_SUB_LESS = decode_to_execute_SRC_USE_SUB_LESS;
  assign _zz_35_ = execute_PC;
  assign execute_SRC2_CTRL = _zz_36_;
  assign execute_SRC1_CTRL = _zz_37_;
  assign decode_SRC_USE_SUB_LESS = _zz_197_[0];
  assign decode_SRC_ADD_ZERO = _zz_198_[0];
  assign execute_SRC_ADD_SUB = execute_SrcPlugin_addSub;
  assign execute_SRC_LESS = execute_SrcPlugin_less;
  assign execute_ALU_CTRL = _zz_38_;
  assign execute_SRC2 = _zz_107_;
  assign execute_SRC1 = _zz_102_;
  assign execute_ALU_BITWISE_CTRL = _zz_39_;
  assign _zz_40_ = writeBack_INSTRUCTION;
  assign _zz_41_ = writeBack_REGFILE_WRITE_VALID;
  always @ (*) begin
    _zz_42_ = 1'b0;
    if(lastStageRegFileWrite_valid)begin
      _zz_42_ = 1'b1;
    end
  end

  assign decode_INSTRUCTION_ANTICIPATED = (decode_arbitration_isStuck ? decode_INSTRUCTION : IBusCachedPlugin_cache_io_cpu_fetch_data);
  always @ (*) begin
    decode_REGFILE_WRITE_VALID = _zz_199_[0];
    if((decode_INSTRUCTION[11 : 7] == 5'h0))begin
      decode_REGFILE_WRITE_VALID = 1'b0;
    end
  end

  assign writeBack_MEMORY_STORE = memory_to_writeBack_MEMORY_STORE;
  always @ (*) begin
    _zz_50_ = writeBack_REGFILE_WRITE_DATA;
    if((writeBack_arbitration_isValid && writeBack_MEMORY_ENABLE))begin
      _zz_50_ = writeBack_DBusSimplePlugin_rspFormated;
    end
  end

  assign writeBack_MEMORY_ENABLE = memory_to_writeBack_MEMORY_ENABLE;
  assign writeBack_MEMORY_ADDRESS_LOW = memory_to_writeBack_MEMORY_ADDRESS_LOW;
  assign writeBack_MEMORY_READ_DATA = memory_to_writeBack_MEMORY_READ_DATA;
  assign memory_MMU_FAULT = execute_to_memory_MMU_FAULT;
  assign memory_MMU_RSP_physicalAddress = execute_to_memory_MMU_RSP_physicalAddress;
  assign memory_MMU_RSP_isIoAccess = execute_to_memory_MMU_RSP_isIoAccess;
  assign memory_MMU_RSP_allowRead = execute_to_memory_MMU_RSP_allowRead;
  assign memory_MMU_RSP_allowWrite = execute_to_memory_MMU_RSP_allowWrite;
  assign memory_MMU_RSP_allowExecute = execute_to_memory_MMU_RSP_allowExecute;
  assign memory_MMU_RSP_exception = execute_to_memory_MMU_RSP_exception;
  assign memory_MMU_RSP_refilling = execute_to_memory_MMU_RSP_refilling;
  assign memory_PC = execute_to_memory_PC;
  assign memory_REGFILE_WRITE_DATA = execute_to_memory_REGFILE_WRITE_DATA;
  assign memory_MEMORY_STORE = execute_to_memory_MEMORY_STORE;
  assign memory_MEMORY_ENABLE = execute_to_memory_MEMORY_ENABLE;
  assign execute_MMU_FAULT = ((execute_MMU_RSP_exception || ((! execute_MMU_RSP_allowWrite) && execute_MEMORY_STORE)) || ((! execute_MMU_RSP_allowRead) && (! execute_MEMORY_STORE)));
  assign execute_MMU_RSP_physicalAddress = DBusSimplePlugin_mmuBus_rsp_physicalAddress;
  assign execute_MMU_RSP_isIoAccess = DBusSimplePlugin_mmuBus_rsp_isIoAccess;
  assign execute_MMU_RSP_allowRead = DBusSimplePlugin_mmuBus_rsp_allowRead;
  assign execute_MMU_RSP_allowWrite = DBusSimplePlugin_mmuBus_rsp_allowWrite;
  assign execute_MMU_RSP_allowExecute = DBusSimplePlugin_mmuBus_rsp_allowExecute;
  assign execute_MMU_RSP_exception = DBusSimplePlugin_mmuBus_rsp_exception;
  assign execute_MMU_RSP_refilling = DBusSimplePlugin_mmuBus_rsp_refilling;
  assign execute_SRC_ADD = execute_SrcPlugin_addSub;
  assign execute_RS2 = decode_to_execute_RS2;
  assign execute_INSTRUCTION = decode_to_execute_INSTRUCTION;
  assign execute_MEMORY_STORE = decode_to_execute_MEMORY_STORE;
  assign execute_MEMORY_ENABLE = decode_to_execute_MEMORY_ENABLE;
  assign execute_ALIGNEMENT_FAULT = 1'b0;
  assign decode_MEMORY_ENABLE = _zz_200_[0];
  assign decode_FLUSH_ALL = _zz_201_[0];
  always @ (*) begin
    _zz_51_ = _zz_51__0;
    if(_zz_167_)begin
      _zz_51_ = 1'b1;
    end
  end

  always @ (*) begin
    _zz_51__0 = IBusCachedPlugin_rsp_issueDetected;
    if(_zz_168_)begin
      _zz_51__0 = 1'b1;
    end
  end

  assign decode_BRANCH_CTRL = _zz_52_;
  assign decode_INSTRUCTION = IBusCachedPlugin_iBusRsp_output_payload_rsp_inst;
  always @ (*) begin
    _zz_53_ = memory_FORMAL_PC_NEXT;
    if(DBusSimplePlugin_redoBranch_valid)begin
      _zz_53_ = DBusSimplePlugin_redoBranch_payload;
    end
    if(BranchPlugin_jumpInterface_valid)begin
      _zz_53_ = BranchPlugin_jumpInterface_payload;
    end
  end

  always @ (*) begin
    _zz_54_ = decode_FORMAL_PC_NEXT;
    if(IBusCachedPlugin_predictionJumpInterface_valid)begin
      _zz_54_ = IBusCachedPlugin_predictionJumpInterface_payload;
    end
  end

  assign decode_PC = IBusCachedPlugin_iBusRsp_output_payload_pc;
  assign writeBack_PC = memory_to_writeBack_PC;
  assign writeBack_INSTRUCTION = memory_to_writeBack_INSTRUCTION;
  always @ (*) begin
    decode_arbitration_haltItself = 1'b0;
    if(((DBusSimplePlugin_mmuBus_busy && decode_arbitration_isValid) && decode_MEMORY_ENABLE))begin
      decode_arbitration_haltItself = 1'b1;
    end
  end

  always @ (*) begin
    decode_arbitration_haltByOther = 1'b0;
    if((decode_arbitration_isValid && (_zz_110_ || _zz_111_)))begin
      decode_arbitration_haltByOther = 1'b1;
    end
    if(CsrPlugin_pipelineLiberator_active)begin
      decode_arbitration_haltByOther = 1'b1;
    end
    if(({(writeBack_arbitration_isValid && (writeBack_ENV_CTRL == `EnvCtrlEnum_defaultEncoding_XRET)),{(memory_arbitration_isValid && (memory_ENV_CTRL == `EnvCtrlEnum_defaultEncoding_XRET)),(execute_arbitration_isValid && (execute_ENV_CTRL == `EnvCtrlEnum_defaultEncoding_XRET))}} != (3'b000)))begin
      decode_arbitration_haltByOther = 1'b1;
    end
  end

  always @ (*) begin
    decode_arbitration_removeIt = 1'b0;
    if(decode_arbitration_isFlushed)begin
      decode_arbitration_removeIt = 1'b1;
    end
  end

  assign decode_arbitration_flushIt = 1'b0;
  always @ (*) begin
    decode_arbitration_flushNext = 1'b0;
    if(IBusCachedPlugin_predictionJumpInterface_valid)begin
      decode_arbitration_flushNext = 1'b1;
    end
  end

  always @ (*) begin
    execute_arbitration_haltItself = 1'b0;
    if(((((execute_arbitration_isValid && execute_MEMORY_ENABLE) && (! dBus_cmd_ready)) && (! execute_DBusSimplePlugin_skipCmd)) && (! _zz_81_)))begin
      execute_arbitration_haltItself = 1'b1;
    end
    if(_zz_162_)begin
      if(execute_CsrPlugin_blockedBySideEffects)begin
        execute_arbitration_haltItself = 1'b1;
      end
    end
  end

  assign execute_arbitration_haltByOther = 1'b0;
  always @ (*) begin
    execute_arbitration_removeIt = 1'b0;
    if(CsrPlugin_selfException_valid)begin
      execute_arbitration_removeIt = 1'b1;
    end
    if(execute_arbitration_isFlushed)begin
      execute_arbitration_removeIt = 1'b1;
    end
  end

  assign execute_arbitration_flushIt = 1'b0;
  always @ (*) begin
    execute_arbitration_flushNext = 1'b0;
    if(CsrPlugin_selfException_valid)begin
      execute_arbitration_flushNext = 1'b1;
    end
  end

  always @ (*) begin
    memory_arbitration_haltItself = 1'b0;
    if((((memory_arbitration_isValid && memory_MEMORY_ENABLE) && (! memory_MEMORY_STORE)) && ((! dBus_rsp_ready) || 1'b0)))begin
      memory_arbitration_haltItself = 1'b1;
    end
  end

  assign memory_arbitration_haltByOther = 1'b0;
  always @ (*) begin
    memory_arbitration_removeIt = 1'b0;
    if(DBusSimplePlugin_memoryExceptionPort_valid)begin
      memory_arbitration_removeIt = 1'b1;
    end
    if(memory_arbitration_isFlushed)begin
      memory_arbitration_removeIt = 1'b1;
    end
  end

  always @ (*) begin
    memory_arbitration_flushIt = 1'b0;
    if(DBusSimplePlugin_redoBranch_valid)begin
      memory_arbitration_flushIt = 1'b1;
    end
  end

  always @ (*) begin
    memory_arbitration_flushNext = 1'b0;
    if(DBusSimplePlugin_redoBranch_valid)begin
      memory_arbitration_flushNext = 1'b1;
    end
    if(BranchPlugin_jumpInterface_valid)begin
      memory_arbitration_flushNext = 1'b1;
    end
    if(DBusSimplePlugin_memoryExceptionPort_valid)begin
      memory_arbitration_flushNext = 1'b1;
    end
  end

  assign writeBack_arbitration_haltItself = 1'b0;
  assign writeBack_arbitration_haltByOther = 1'b0;
  always @ (*) begin
    writeBack_arbitration_removeIt = 1'b0;
    if(writeBack_arbitration_isFlushed)begin
      writeBack_arbitration_removeIt = 1'b1;
    end
  end

  assign writeBack_arbitration_flushIt = 1'b0;
  always @ (*) begin
    writeBack_arbitration_flushNext = 1'b0;
    if(_zz_169_)begin
      writeBack_arbitration_flushNext = 1'b1;
    end
    if(_zz_170_)begin
      writeBack_arbitration_flushNext = 1'b1;
    end
  end

  assign lastStageInstruction = writeBack_INSTRUCTION;
  assign lastStagePc = writeBack_PC;
  assign lastStageIsValid = writeBack_arbitration_isValid;
  assign lastStageIsFiring = writeBack_arbitration_isFiring;
  always @ (*) begin
    IBusCachedPlugin_fetcherHalt = 1'b0;
    if(({CsrPlugin_exceptionPortCtrl_exceptionValids_writeBack,{CsrPlugin_exceptionPortCtrl_exceptionValids_memory,{CsrPlugin_exceptionPortCtrl_exceptionValids_execute,CsrPlugin_exceptionPortCtrl_exceptionValids_decode}}} != (4'b0000)))begin
      IBusCachedPlugin_fetcherHalt = 1'b1;
    end
    if(_zz_169_)begin
      IBusCachedPlugin_fetcherHalt = 1'b1;
    end
    if(_zz_170_)begin
      IBusCachedPlugin_fetcherHalt = 1'b1;
    end
  end

  always @ (*) begin
    IBusCachedPlugin_incomingInstruction = 1'b0;
    if((IBusCachedPlugin_iBusRsp_stages_1_input_valid || IBusCachedPlugin_iBusRsp_stages_2_input_valid))begin
      IBusCachedPlugin_incomingInstruction = 1'b1;
    end
  end

  assign CsrPlugin_inWfi = 1'b0;
  assign CsrPlugin_thirdPartyWake = 1'b0;
  always @ (*) begin
    CsrPlugin_jumpInterface_valid = 1'b0;
    if(_zz_169_)begin
      CsrPlugin_jumpInterface_valid = 1'b1;
    end
    if(_zz_170_)begin
      CsrPlugin_jumpInterface_valid = 1'b1;
    end
  end

  always @ (*) begin
    CsrPlugin_jumpInterface_payload = 32'h0;
    if(_zz_169_)begin
      CsrPlugin_jumpInterface_payload = {CsrPlugin_xtvec_base,(2'b00)};
    end
    if(_zz_170_)begin
      case(_zz_171_)
        2'b11 : begin
          CsrPlugin_jumpInterface_payload = CsrPlugin_mepc;
        end
        default : begin
        end
      endcase
    end
  end

  assign CsrPlugin_forceMachineWire = 1'b0;
  assign CsrPlugin_allowInterrupts = 1'b1;
  assign CsrPlugin_allowException = 1'b1;
  assign IBusCachedPlugin_externalFlush = ({writeBack_arbitration_flushNext,{memory_arbitration_flushNext,{execute_arbitration_flushNext,decode_arbitration_flushNext}}} != (4'b0000));
  assign IBusCachedPlugin_jump_pcLoad_valid = ({CsrPlugin_jumpInterface_valid,{BranchPlugin_jumpInterface_valid,{DBusSimplePlugin_redoBranch_valid,IBusCachedPlugin_predictionJumpInterface_valid}}} != (4'b0000));
  assign _zz_55_ = {IBusCachedPlugin_predictionJumpInterface_valid,{BranchPlugin_jumpInterface_valid,{DBusSimplePlugin_redoBranch_valid,CsrPlugin_jumpInterface_valid}}};
  assign _zz_56_ = (_zz_55_ & (~ _zz_202_));
  assign _zz_57_ = _zz_56_[3];
  assign _zz_58_ = (_zz_56_[1] || _zz_57_);
  assign _zz_59_ = (_zz_56_[2] || _zz_57_);
  assign IBusCachedPlugin_jump_pcLoad_payload = _zz_161_;
  always @ (*) begin
    IBusCachedPlugin_fetchPc_correction = 1'b0;
    if(IBusCachedPlugin_fetchPc_redo_valid)begin
      IBusCachedPlugin_fetchPc_correction = 1'b1;
    end
    if(IBusCachedPlugin_jump_pcLoad_valid)begin
      IBusCachedPlugin_fetchPc_correction = 1'b1;
    end
  end

  assign IBusCachedPlugin_fetchPc_corrected = (IBusCachedPlugin_fetchPc_correction || IBusCachedPlugin_fetchPc_correctionReg);
  always @ (*) begin
    IBusCachedPlugin_fetchPc_pcRegPropagate = 1'b0;
    if(IBusCachedPlugin_iBusRsp_stages_1_input_ready)begin
      IBusCachedPlugin_fetchPc_pcRegPropagate = 1'b1;
    end
  end

  always @ (*) begin
    IBusCachedPlugin_fetchPc_pc = (IBusCachedPlugin_fetchPc_pcReg + _zz_204_);
    if(IBusCachedPlugin_fetchPc_redo_valid)begin
      IBusCachedPlugin_fetchPc_pc = IBusCachedPlugin_fetchPc_redo_payload;
    end
    if(IBusCachedPlugin_jump_pcLoad_valid)begin
      IBusCachedPlugin_fetchPc_pc = IBusCachedPlugin_jump_pcLoad_payload;
    end
    IBusCachedPlugin_fetchPc_pc[0] = 1'b0;
    IBusCachedPlugin_fetchPc_pc[1] = 1'b0;
  end

  always @ (*) begin
    IBusCachedPlugin_fetchPc_flushed = 1'b0;
    if(IBusCachedPlugin_fetchPc_redo_valid)begin
      IBusCachedPlugin_fetchPc_flushed = 1'b1;
    end
    if(IBusCachedPlugin_jump_pcLoad_valid)begin
      IBusCachedPlugin_fetchPc_flushed = 1'b1;
    end
  end

  assign IBusCachedPlugin_fetchPc_output_valid = ((! IBusCachedPlugin_fetcherHalt) && IBusCachedPlugin_fetchPc_booted);
  assign IBusCachedPlugin_fetchPc_output_payload = IBusCachedPlugin_fetchPc_pc;
  always @ (*) begin
    IBusCachedPlugin_iBusRsp_redoFetch = 1'b0;
    if(IBusCachedPlugin_rsp_redoFetch)begin
      IBusCachedPlugin_iBusRsp_redoFetch = 1'b1;
    end
  end

  assign IBusCachedPlugin_iBusRsp_stages_0_input_valid = IBusCachedPlugin_fetchPc_output_valid;
  assign IBusCachedPlugin_fetchPc_output_ready = IBusCachedPlugin_iBusRsp_stages_0_input_ready;
  assign IBusCachedPlugin_iBusRsp_stages_0_input_payload = IBusCachedPlugin_fetchPc_output_payload;
  always @ (*) begin
    IBusCachedPlugin_iBusRsp_stages_0_halt = 1'b0;
    if(IBusCachedPlugin_cache_io_cpu_prefetch_haltIt)begin
      IBusCachedPlugin_iBusRsp_stages_0_halt = 1'b1;
    end
  end

  assign _zz_60_ = (! IBusCachedPlugin_iBusRsp_stages_0_halt);
  assign IBusCachedPlugin_iBusRsp_stages_0_input_ready = (IBusCachedPlugin_iBusRsp_stages_0_output_ready && _zz_60_);
  assign IBusCachedPlugin_iBusRsp_stages_0_output_valid = (IBusCachedPlugin_iBusRsp_stages_0_input_valid && _zz_60_);
  assign IBusCachedPlugin_iBusRsp_stages_0_output_payload = IBusCachedPlugin_iBusRsp_stages_0_input_payload;
  always @ (*) begin
    IBusCachedPlugin_iBusRsp_stages_1_halt = 1'b0;
    if(IBusCachedPlugin_cache_io_cpu_fetch_haltIt)begin
      IBusCachedPlugin_iBusRsp_stages_1_halt = 1'b1;
    end
  end

  assign _zz_61_ = (! IBusCachedPlugin_iBusRsp_stages_1_halt);
  assign IBusCachedPlugin_iBusRsp_stages_1_input_ready = (IBusCachedPlugin_iBusRsp_stages_1_output_ready && _zz_61_);
  assign IBusCachedPlugin_iBusRsp_stages_1_output_valid = (IBusCachedPlugin_iBusRsp_stages_1_input_valid && _zz_61_);
  assign IBusCachedPlugin_iBusRsp_stages_1_output_payload = IBusCachedPlugin_iBusRsp_stages_1_input_payload;
  always @ (*) begin
    IBusCachedPlugin_iBusRsp_stages_2_halt = 1'b0;
    if((_zz_51_ || IBusCachedPlugin_rsp_iBusRspOutputHalt))begin
      IBusCachedPlugin_iBusRsp_stages_2_halt = 1'b1;
    end
  end

  assign _zz_62_ = (! IBusCachedPlugin_iBusRsp_stages_2_halt);
  assign IBusCachedPlugin_iBusRsp_stages_2_input_ready = (IBusCachedPlugin_iBusRsp_stages_2_output_ready && _zz_62_);
  assign IBusCachedPlugin_iBusRsp_stages_2_output_valid = (IBusCachedPlugin_iBusRsp_stages_2_input_valid && _zz_62_);
  assign IBusCachedPlugin_iBusRsp_stages_2_output_payload = IBusCachedPlugin_iBusRsp_stages_2_input_payload;
  assign IBusCachedPlugin_fetchPc_redo_valid = IBusCachedPlugin_iBusRsp_redoFetch;
  assign IBusCachedPlugin_fetchPc_redo_payload = IBusCachedPlugin_iBusRsp_stages_2_input_payload;
  assign IBusCachedPlugin_iBusRsp_flush = ((decode_arbitration_removeIt || (decode_arbitration_flushNext && (! decode_arbitration_isStuck))) || IBusCachedPlugin_iBusRsp_redoFetch);
  assign IBusCachedPlugin_iBusRsp_stages_0_output_ready = _zz_63_;
  assign _zz_63_ = ((1'b0 && (! _zz_64_)) || IBusCachedPlugin_iBusRsp_stages_1_input_ready);
  assign _zz_64_ = _zz_65_;
  assign IBusCachedPlugin_iBusRsp_stages_1_input_valid = _zz_64_;
  assign IBusCachedPlugin_iBusRsp_stages_1_input_payload = IBusCachedPlugin_fetchPc_pcReg;
  assign IBusCachedPlugin_iBusRsp_stages_1_output_ready = ((1'b0 && (! _zz_66_)) || IBusCachedPlugin_iBusRsp_stages_2_input_ready);
  assign _zz_66_ = _zz_67_;
  assign IBusCachedPlugin_iBusRsp_stages_2_input_valid = _zz_66_;
  assign IBusCachedPlugin_iBusRsp_stages_2_input_payload = _zz_68_;
  always @ (*) begin
    IBusCachedPlugin_iBusRsp_readyForError = 1'b1;
    if((! IBusCachedPlugin_pcValids_0))begin
      IBusCachedPlugin_iBusRsp_readyForError = 1'b0;
    end
  end

  assign IBusCachedPlugin_pcValids_0 = IBusCachedPlugin_injector_nextPcCalc_valids_1;
  assign IBusCachedPlugin_pcValids_1 = IBusCachedPlugin_injector_nextPcCalc_valids_2;
  assign IBusCachedPlugin_pcValids_2 = IBusCachedPlugin_injector_nextPcCalc_valids_3;
  assign IBusCachedPlugin_pcValids_3 = IBusCachedPlugin_injector_nextPcCalc_valids_4;
  assign IBusCachedPlugin_iBusRsp_output_ready = (! decode_arbitration_isStuck);
  assign decode_arbitration_isValid = IBusCachedPlugin_iBusRsp_output_valid;
  assign _zz_69_ = _zz_205_[11];
  always @ (*) begin
    _zz_70_[18] = _zz_69_;
    _zz_70_[17] = _zz_69_;
    _zz_70_[16] = _zz_69_;
    _zz_70_[15] = _zz_69_;
    _zz_70_[14] = _zz_69_;
    _zz_70_[13] = _zz_69_;
    _zz_70_[12] = _zz_69_;
    _zz_70_[11] = _zz_69_;
    _zz_70_[10] = _zz_69_;
    _zz_70_[9] = _zz_69_;
    _zz_70_[8] = _zz_69_;
    _zz_70_[7] = _zz_69_;
    _zz_70_[6] = _zz_69_;
    _zz_70_[5] = _zz_69_;
    _zz_70_[4] = _zz_69_;
    _zz_70_[3] = _zz_69_;
    _zz_70_[2] = _zz_69_;
    _zz_70_[1] = _zz_69_;
    _zz_70_[0] = _zz_69_;
  end

  always @ (*) begin
    IBusCachedPlugin_decodePrediction_cmd_hadBranch = ((decode_BRANCH_CTRL == `BranchCtrlEnum_defaultEncoding_JAL) || ((decode_BRANCH_CTRL == `BranchCtrlEnum_defaultEncoding_B) && _zz_206_[31]));
    if(_zz_75_)begin
      IBusCachedPlugin_decodePrediction_cmd_hadBranch = 1'b0;
    end
  end

  assign _zz_71_ = _zz_207_[19];
  always @ (*) begin
    _zz_72_[10] = _zz_71_;
    _zz_72_[9] = _zz_71_;
    _zz_72_[8] = _zz_71_;
    _zz_72_[7] = _zz_71_;
    _zz_72_[6] = _zz_71_;
    _zz_72_[5] = _zz_71_;
    _zz_72_[4] = _zz_71_;
    _zz_72_[3] = _zz_71_;
    _zz_72_[2] = _zz_71_;
    _zz_72_[1] = _zz_71_;
    _zz_72_[0] = _zz_71_;
  end

  assign _zz_73_ = _zz_208_[11];
  always @ (*) begin
    _zz_74_[18] = _zz_73_;
    _zz_74_[17] = _zz_73_;
    _zz_74_[16] = _zz_73_;
    _zz_74_[15] = _zz_73_;
    _zz_74_[14] = _zz_73_;
    _zz_74_[13] = _zz_73_;
    _zz_74_[12] = _zz_73_;
    _zz_74_[11] = _zz_73_;
    _zz_74_[10] = _zz_73_;
    _zz_74_[9] = _zz_73_;
    _zz_74_[8] = _zz_73_;
    _zz_74_[7] = _zz_73_;
    _zz_74_[6] = _zz_73_;
    _zz_74_[5] = _zz_73_;
    _zz_74_[4] = _zz_73_;
    _zz_74_[3] = _zz_73_;
    _zz_74_[2] = _zz_73_;
    _zz_74_[1] = _zz_73_;
    _zz_74_[0] = _zz_73_;
  end

  always @ (*) begin
    case(decode_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_JAL : begin
        _zz_75_ = _zz_209_[1];
      end
      default : begin
        _zz_75_ = _zz_210_[1];
      end
    endcase
  end

  assign IBusCachedPlugin_predictionJumpInterface_valid = (decode_arbitration_isValid && IBusCachedPlugin_decodePrediction_cmd_hadBranch);
  assign _zz_76_ = _zz_211_[19];
  always @ (*) begin
    _zz_77_[10] = _zz_76_;
    _zz_77_[9] = _zz_76_;
    _zz_77_[8] = _zz_76_;
    _zz_77_[7] = _zz_76_;
    _zz_77_[6] = _zz_76_;
    _zz_77_[5] = _zz_76_;
    _zz_77_[4] = _zz_76_;
    _zz_77_[3] = _zz_76_;
    _zz_77_[2] = _zz_76_;
    _zz_77_[1] = _zz_76_;
    _zz_77_[0] = _zz_76_;
  end

  assign _zz_78_ = _zz_212_[11];
  always @ (*) begin
    _zz_79_[18] = _zz_78_;
    _zz_79_[17] = _zz_78_;
    _zz_79_[16] = _zz_78_;
    _zz_79_[15] = _zz_78_;
    _zz_79_[14] = _zz_78_;
    _zz_79_[13] = _zz_78_;
    _zz_79_[12] = _zz_78_;
    _zz_79_[11] = _zz_78_;
    _zz_79_[10] = _zz_78_;
    _zz_79_[9] = _zz_78_;
    _zz_79_[8] = _zz_78_;
    _zz_79_[7] = _zz_78_;
    _zz_79_[6] = _zz_78_;
    _zz_79_[5] = _zz_78_;
    _zz_79_[4] = _zz_78_;
    _zz_79_[3] = _zz_78_;
    _zz_79_[2] = _zz_78_;
    _zz_79_[1] = _zz_78_;
    _zz_79_[0] = _zz_78_;
  end

  assign IBusCachedPlugin_predictionJumpInterface_payload = (decode_PC + ((decode_BRANCH_CTRL == `BranchCtrlEnum_defaultEncoding_JAL) ? {{_zz_77_,{{{_zz_248_,decode_INSTRUCTION[19 : 12]},decode_INSTRUCTION[20]},decode_INSTRUCTION[30 : 21]}},1'b0} : {{_zz_79_,{{{_zz_249_,_zz_250_},decode_INSTRUCTION[30 : 25]},decode_INSTRUCTION[11 : 8]}},1'b0}));
  assign iBus_cmd_valid = IBusCachedPlugin_cache_io_mem_cmd_valid;
  always @ (*) begin
    iBus_cmd_payload_address = IBusCachedPlugin_cache_io_mem_cmd_payload_address;
    iBus_cmd_payload_address = IBusCachedPlugin_cache_io_mem_cmd_payload_address;
  end

  assign iBus_cmd_payload_size = IBusCachedPlugin_cache_io_mem_cmd_payload_size;
  assign IBusCachedPlugin_s0_tightlyCoupledHit = 1'b0;
  assign _zz_152_ = (IBusCachedPlugin_iBusRsp_stages_0_input_valid && (! IBusCachedPlugin_s0_tightlyCoupledHit));
  assign _zz_153_ = (IBusCachedPlugin_iBusRsp_stages_1_input_valid && (! IBusCachedPlugin_s1_tightlyCoupledHit));
  assign _zz_154_ = (! IBusCachedPlugin_iBusRsp_stages_1_input_ready);
  assign _zz_155_ = (IBusCachedPlugin_iBusRsp_stages_2_input_valid && (! IBusCachedPlugin_s2_tightlyCoupledHit));
  assign _zz_156_ = (! IBusCachedPlugin_iBusRsp_stages_2_input_ready);
  assign _zz_157_ = (CsrPlugin_privilege == (2'b00));
  assign IBusCachedPlugin_rsp_iBusRspOutputHalt = 1'b0;
  assign IBusCachedPlugin_rsp_issueDetected = 1'b0;
  always @ (*) begin
    IBusCachedPlugin_rsp_redoFetch = 1'b0;
    if(_zz_168_)begin
      IBusCachedPlugin_rsp_redoFetch = 1'b1;
    end
    if(_zz_167_)begin
      IBusCachedPlugin_rsp_redoFetch = 1'b1;
    end
  end

  always @ (*) begin
    _zz_158_ = (IBusCachedPlugin_rsp_redoFetch && (! IBusCachedPlugin_cache_io_cpu_decode_mmuRefilling));
    if(_zz_167_)begin
      _zz_158_ = 1'b1;
    end
  end

  assign IBusCachedPlugin_iBusRsp_output_valid = IBusCachedPlugin_iBusRsp_stages_2_output_valid;
  assign IBusCachedPlugin_iBusRsp_stages_2_output_ready = IBusCachedPlugin_iBusRsp_output_ready;
  assign IBusCachedPlugin_iBusRsp_output_payload_rsp_inst = IBusCachedPlugin_cache_io_cpu_decode_data;
  assign IBusCachedPlugin_iBusRsp_output_payload_pc = IBusCachedPlugin_iBusRsp_stages_2_output_payload;
  assign IBusCachedPlugin_mmuBus_cmd_isValid = IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_isValid;
  assign IBusCachedPlugin_mmuBus_cmd_virtualAddress = IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_virtualAddress;
  assign IBusCachedPlugin_mmuBus_cmd_bypassTranslation = IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_cmd_bypassTranslation;
  assign IBusCachedPlugin_mmuBus_end = IBusCachedPlugin_cache_io_cpu_fetch_mmuBus_end;
  assign _zz_151_ = (decode_arbitration_isValid && decode_FLUSH_ALL);
  assign _zz_81_ = 1'b0;
  always @ (*) begin
    execute_DBusSimplePlugin_skipCmd = 1'b0;
    if(execute_ALIGNEMENT_FAULT)begin
      execute_DBusSimplePlugin_skipCmd = 1'b1;
    end
    if((execute_MMU_FAULT || execute_MMU_RSP_refilling))begin
      execute_DBusSimplePlugin_skipCmd = 1'b1;
    end
  end

  assign dBus_cmd_valid = (((((execute_arbitration_isValid && execute_MEMORY_ENABLE) && (! execute_arbitration_isStuckByOthers)) && (! execute_arbitration_isFlushed)) && (! execute_DBusSimplePlugin_skipCmd)) && (! _zz_81_));
  assign dBus_cmd_payload_wr = execute_MEMORY_STORE;
  assign dBus_cmd_payload_size = execute_INSTRUCTION[13 : 12];
  always @ (*) begin
    case(dBus_cmd_payload_size)
      2'b00 : begin
        _zz_82_ = {{{execute_RS2[7 : 0],execute_RS2[7 : 0]},execute_RS2[7 : 0]},execute_RS2[7 : 0]};
      end
      2'b01 : begin
        _zz_82_ = {execute_RS2[15 : 0],execute_RS2[15 : 0]};
      end
      default : begin
        _zz_82_ = execute_RS2[31 : 0];
      end
    endcase
  end

  assign dBus_cmd_payload_data = _zz_82_;
  always @ (*) begin
    case(dBus_cmd_payload_size)
      2'b00 : begin
        _zz_83_ = (4'b0001);
      end
      2'b01 : begin
        _zz_83_ = (4'b0011);
      end
      default : begin
        _zz_83_ = (4'b1111);
      end
    endcase
  end

  assign execute_DBusSimplePlugin_formalMask = (_zz_83_ <<< dBus_cmd_payload_address[1 : 0]);
  assign DBusSimplePlugin_mmuBus_cmd_isValid = (execute_arbitration_isValid && execute_MEMORY_ENABLE);
  assign DBusSimplePlugin_mmuBus_cmd_virtualAddress = execute_SRC_ADD;
  assign DBusSimplePlugin_mmuBus_cmd_bypassTranslation = 1'b0;
  assign DBusSimplePlugin_mmuBus_end = ((! execute_arbitration_isStuck) || execute_arbitration_removeIt);
  assign dBus_cmd_payload_address = DBusSimplePlugin_mmuBus_rsp_physicalAddress;
  always @ (*) begin
    DBusSimplePlugin_memoryExceptionPort_valid = 1'b0;
    if(memory_MMU_RSP_refilling)begin
      DBusSimplePlugin_memoryExceptionPort_valid = 1'b0;
    end else begin
      if(memory_MMU_FAULT)begin
        DBusSimplePlugin_memoryExceptionPort_valid = 1'b1;
      end
    end
    if(_zz_172_)begin
      DBusSimplePlugin_memoryExceptionPort_valid = 1'b0;
    end
  end

  always @ (*) begin
    DBusSimplePlugin_memoryExceptionPort_payload_code = (4'bxxxx);
    if(! memory_MMU_RSP_refilling) begin
      if(memory_MMU_FAULT)begin
        DBusSimplePlugin_memoryExceptionPort_payload_code = (memory_MEMORY_STORE ? (4'b1111) : (4'b1101));
      end
    end
  end

  assign DBusSimplePlugin_memoryExceptionPort_payload_badAddr = memory_REGFILE_WRITE_DATA;
  always @ (*) begin
    DBusSimplePlugin_redoBranch_valid = 1'b0;
    if(memory_MMU_RSP_refilling)begin
      DBusSimplePlugin_redoBranch_valid = 1'b1;
    end
    if(_zz_172_)begin
      DBusSimplePlugin_redoBranch_valid = 1'b0;
    end
  end

  assign DBusSimplePlugin_redoBranch_payload = memory_PC;
  always @ (*) begin
    writeBack_DBusSimplePlugin_rspShifted = writeBack_MEMORY_READ_DATA;
    case(writeBack_MEMORY_ADDRESS_LOW)
      2'b01 : begin
        writeBack_DBusSimplePlugin_rspShifted[7 : 0] = writeBack_MEMORY_READ_DATA[15 : 8];
      end
      2'b10 : begin
        writeBack_DBusSimplePlugin_rspShifted[15 : 0] = writeBack_MEMORY_READ_DATA[31 : 16];
      end
      2'b11 : begin
        writeBack_DBusSimplePlugin_rspShifted[7 : 0] = writeBack_MEMORY_READ_DATA[31 : 24];
      end
      default : begin
      end
    endcase
  end

  assign _zz_84_ = (writeBack_DBusSimplePlugin_rspShifted[7] && (! writeBack_INSTRUCTION[14]));
  always @ (*) begin
    _zz_85_[31] = _zz_84_;
    _zz_85_[30] = _zz_84_;
    _zz_85_[29] = _zz_84_;
    _zz_85_[28] = _zz_84_;
    _zz_85_[27] = _zz_84_;
    _zz_85_[26] = _zz_84_;
    _zz_85_[25] = _zz_84_;
    _zz_85_[24] = _zz_84_;
    _zz_85_[23] = _zz_84_;
    _zz_85_[22] = _zz_84_;
    _zz_85_[21] = _zz_84_;
    _zz_85_[20] = _zz_84_;
    _zz_85_[19] = _zz_84_;
    _zz_85_[18] = _zz_84_;
    _zz_85_[17] = _zz_84_;
    _zz_85_[16] = _zz_84_;
    _zz_85_[15] = _zz_84_;
    _zz_85_[14] = _zz_84_;
    _zz_85_[13] = _zz_84_;
    _zz_85_[12] = _zz_84_;
    _zz_85_[11] = _zz_84_;
    _zz_85_[10] = _zz_84_;
    _zz_85_[9] = _zz_84_;
    _zz_85_[8] = _zz_84_;
    _zz_85_[7 : 0] = writeBack_DBusSimplePlugin_rspShifted[7 : 0];
  end

  assign _zz_86_ = (writeBack_DBusSimplePlugin_rspShifted[15] && (! writeBack_INSTRUCTION[14]));
  always @ (*) begin
    _zz_87_[31] = _zz_86_;
    _zz_87_[30] = _zz_86_;
    _zz_87_[29] = _zz_86_;
    _zz_87_[28] = _zz_86_;
    _zz_87_[27] = _zz_86_;
    _zz_87_[26] = _zz_86_;
    _zz_87_[25] = _zz_86_;
    _zz_87_[24] = _zz_86_;
    _zz_87_[23] = _zz_86_;
    _zz_87_[22] = _zz_86_;
    _zz_87_[21] = _zz_86_;
    _zz_87_[20] = _zz_86_;
    _zz_87_[19] = _zz_86_;
    _zz_87_[18] = _zz_86_;
    _zz_87_[17] = _zz_86_;
    _zz_87_[16] = _zz_86_;
    _zz_87_[15 : 0] = writeBack_DBusSimplePlugin_rspShifted[15 : 0];
  end

  always @ (*) begin
    case(_zz_185_)
      2'b00 : begin
        writeBack_DBusSimplePlugin_rspFormated = _zz_85_;
      end
      2'b01 : begin
        writeBack_DBusSimplePlugin_rspFormated = _zz_87_;
      end
      default : begin
        writeBack_DBusSimplePlugin_rspFormated = writeBack_DBusSimplePlugin_rspShifted;
      end
    endcase
  end

  assign IBusCachedPlugin_mmuBus_rsp_physicalAddress = IBusCachedPlugin_mmuBus_cmd_virtualAddress;
  assign IBusCachedPlugin_mmuBus_rsp_allowRead = 1'b1;
  assign IBusCachedPlugin_mmuBus_rsp_allowWrite = 1'b1;
  assign IBusCachedPlugin_mmuBus_rsp_allowExecute = 1'b1;
  assign IBusCachedPlugin_mmuBus_rsp_isIoAccess = IBusCachedPlugin_mmuBus_rsp_physicalAddress[31];
  assign IBusCachedPlugin_mmuBus_rsp_exception = 1'b0;
  assign IBusCachedPlugin_mmuBus_rsp_refilling = 1'b0;
  assign IBusCachedPlugin_mmuBus_busy = 1'b0;
  assign DBusSimplePlugin_mmuBus_rsp_physicalAddress = DBusSimplePlugin_mmuBus_cmd_virtualAddress;
  assign DBusSimplePlugin_mmuBus_rsp_allowRead = 1'b1;
  assign DBusSimplePlugin_mmuBus_rsp_allowWrite = 1'b1;
  assign DBusSimplePlugin_mmuBus_rsp_allowExecute = 1'b1;
  assign DBusSimplePlugin_mmuBus_rsp_isIoAccess = DBusSimplePlugin_mmuBus_rsp_physicalAddress[31];
  assign DBusSimplePlugin_mmuBus_rsp_exception = 1'b0;
  assign DBusSimplePlugin_mmuBus_rsp_refilling = 1'b0;
  assign DBusSimplePlugin_mmuBus_busy = 1'b0;
  assign _zz_89_ = ((decode_INSTRUCTION & 32'h00000048) == 32'h00000048);
  assign _zz_90_ = ((decode_INSTRUCTION & 32'h00000004) == 32'h00000004);
  assign _zz_91_ = ((decode_INSTRUCTION & 32'h00004050) == 32'h00004050);
  assign _zz_92_ = ((decode_INSTRUCTION & 32'h00006004) == 32'h00002000);
  assign _zz_88_ = {({(_zz_251_ == _zz_252_),{_zz_253_,_zz_254_}} != (3'b000)),{({_zz_255_,{_zz_256_,_zz_257_}} != (4'b0000)),{(_zz_258_ != (1'b0)),{(_zz_259_ != _zz_260_),{_zz_261_,{_zz_262_,_zz_263_}}}}}};
  assign _zz_93_ = _zz_88_[3 : 2];
  assign _zz_49_ = _zz_93_;
  assign _zz_94_ = _zz_88_[7 : 6];
  assign _zz_48_ = _zz_94_;
  assign _zz_95_ = _zz_88_[9 : 8];
  assign _zz_47_ = _zz_95_;
  assign _zz_96_ = _zz_88_[12 : 11];
  assign _zz_46_ = _zz_96_;
  assign _zz_97_ = _zz_88_[15 : 14];
  assign _zz_45_ = _zz_97_;
  assign _zz_98_ = _zz_88_[18 : 17];
  assign _zz_44_ = _zz_98_;
  assign _zz_99_ = _zz_88_[24 : 23];
  assign _zz_43_ = _zz_99_;
  assign decode_RegFilePlugin_regFileReadAddress1 = {RegFilePlugin_shadow_read,decode_INSTRUCTION_ANTICIPATED[19 : 15]};
  assign decode_RegFilePlugin_regFileReadAddress2 = {RegFilePlugin_shadow_read,decode_INSTRUCTION_ANTICIPATED[24 : 20]};
  assign decode_RegFilePlugin_rs1Data = _zz_159_;
  assign decode_RegFilePlugin_rs2Data = _zz_160_;
  always @ (*) begin
    lastStageRegFileWrite_valid = (_zz_41_ && writeBack_arbitration_isFiring);
    if(_zz_100_)begin
      lastStageRegFileWrite_valid = 1'b1;
    end
  end

  assign lastStageRegFileWrite_payload_address = {RegFilePlugin_shadow_write,_zz_40_[11 : 7]};
  assign lastStageRegFileWrite_payload_data = _zz_50_;
  always @ (*) begin
    case(execute_ALU_BITWISE_CTRL)
      `AluBitwiseCtrlEnum_defaultEncoding_AND_1 : begin
        execute_IntAluPlugin_bitwise = (execute_SRC1 & execute_SRC2);
      end
      `AluBitwiseCtrlEnum_defaultEncoding_OR_1 : begin
        execute_IntAluPlugin_bitwise = (execute_SRC1 | execute_SRC2);
      end
      default : begin
        execute_IntAluPlugin_bitwise = (execute_SRC1 ^ execute_SRC2);
      end
    endcase
  end

  always @ (*) begin
    case(execute_ALU_CTRL)
      `AluCtrlEnum_defaultEncoding_BITWISE : begin
        _zz_101_ = execute_IntAluPlugin_bitwise;
      end
      `AluCtrlEnum_defaultEncoding_SLT_SLTU : begin
        _zz_101_ = {31'd0, _zz_213_};
      end
      default : begin
        _zz_101_ = execute_SRC_ADD_SUB;
      end
    endcase
  end

  always @ (*) begin
    case(execute_SRC1_CTRL)
      `Src1CtrlEnum_defaultEncoding_RS : begin
        _zz_102_ = execute_RS1;
      end
      `Src1CtrlEnum_defaultEncoding_PC_INCREMENT : begin
        _zz_102_ = {29'd0, _zz_214_};
      end
      `Src1CtrlEnum_defaultEncoding_IMU : begin
        _zz_102_ = {execute_INSTRUCTION[31 : 12],12'h0};
      end
      default : begin
        _zz_102_ = {27'd0, _zz_215_};
      end
    endcase
  end

  assign _zz_103_ = _zz_216_[11];
  always @ (*) begin
    _zz_104_[19] = _zz_103_;
    _zz_104_[18] = _zz_103_;
    _zz_104_[17] = _zz_103_;
    _zz_104_[16] = _zz_103_;
    _zz_104_[15] = _zz_103_;
    _zz_104_[14] = _zz_103_;
    _zz_104_[13] = _zz_103_;
    _zz_104_[12] = _zz_103_;
    _zz_104_[11] = _zz_103_;
    _zz_104_[10] = _zz_103_;
    _zz_104_[9] = _zz_103_;
    _zz_104_[8] = _zz_103_;
    _zz_104_[7] = _zz_103_;
    _zz_104_[6] = _zz_103_;
    _zz_104_[5] = _zz_103_;
    _zz_104_[4] = _zz_103_;
    _zz_104_[3] = _zz_103_;
    _zz_104_[2] = _zz_103_;
    _zz_104_[1] = _zz_103_;
    _zz_104_[0] = _zz_103_;
  end

  assign _zz_105_ = _zz_217_[11];
  always @ (*) begin
    _zz_106_[19] = _zz_105_;
    _zz_106_[18] = _zz_105_;
    _zz_106_[17] = _zz_105_;
    _zz_106_[16] = _zz_105_;
    _zz_106_[15] = _zz_105_;
    _zz_106_[14] = _zz_105_;
    _zz_106_[13] = _zz_105_;
    _zz_106_[12] = _zz_105_;
    _zz_106_[11] = _zz_105_;
    _zz_106_[10] = _zz_105_;
    _zz_106_[9] = _zz_105_;
    _zz_106_[8] = _zz_105_;
    _zz_106_[7] = _zz_105_;
    _zz_106_[6] = _zz_105_;
    _zz_106_[5] = _zz_105_;
    _zz_106_[4] = _zz_105_;
    _zz_106_[3] = _zz_105_;
    _zz_106_[2] = _zz_105_;
    _zz_106_[1] = _zz_105_;
    _zz_106_[0] = _zz_105_;
  end

  always @ (*) begin
    case(execute_SRC2_CTRL)
      `Src2CtrlEnum_defaultEncoding_RS : begin
        _zz_107_ = execute_RS2;
      end
      `Src2CtrlEnum_defaultEncoding_IMI : begin
        _zz_107_ = {_zz_104_,execute_INSTRUCTION[31 : 20]};
      end
      `Src2CtrlEnum_defaultEncoding_IMS : begin
        _zz_107_ = {_zz_106_,{execute_INSTRUCTION[31 : 25],execute_INSTRUCTION[11 : 7]}};
      end
      default : begin
        _zz_107_ = _zz_35_;
      end
    endcase
  end

  always @ (*) begin
    execute_SrcPlugin_addSub = _zz_218_;
    if(execute_SRC2_FORCE_ZERO)begin
      execute_SrcPlugin_addSub = execute_SRC1;
    end
  end

  assign execute_SrcPlugin_less = ((execute_SRC1[31] == execute_SRC2[31]) ? execute_SrcPlugin_addSub[31] : (execute_SRC_LESS_UNSIGNED ? execute_SRC2[31] : execute_SRC1[31]));
  assign execute_FullBarrelShifterPlugin_amplitude = execute_SRC2[4 : 0];
  always @ (*) begin
    _zz_108_[0] = execute_SRC1[31];
    _zz_108_[1] = execute_SRC1[30];
    _zz_108_[2] = execute_SRC1[29];
    _zz_108_[3] = execute_SRC1[28];
    _zz_108_[4] = execute_SRC1[27];
    _zz_108_[5] = execute_SRC1[26];
    _zz_108_[6] = execute_SRC1[25];
    _zz_108_[7] = execute_SRC1[24];
    _zz_108_[8] = execute_SRC1[23];
    _zz_108_[9] = execute_SRC1[22];
    _zz_108_[10] = execute_SRC1[21];
    _zz_108_[11] = execute_SRC1[20];
    _zz_108_[12] = execute_SRC1[19];
    _zz_108_[13] = execute_SRC1[18];
    _zz_108_[14] = execute_SRC1[17];
    _zz_108_[15] = execute_SRC1[16];
    _zz_108_[16] = execute_SRC1[15];
    _zz_108_[17] = execute_SRC1[14];
    _zz_108_[18] = execute_SRC1[13];
    _zz_108_[19] = execute_SRC1[12];
    _zz_108_[20] = execute_SRC1[11];
    _zz_108_[21] = execute_SRC1[10];
    _zz_108_[22] = execute_SRC1[9];
    _zz_108_[23] = execute_SRC1[8];
    _zz_108_[24] = execute_SRC1[7];
    _zz_108_[25] = execute_SRC1[6];
    _zz_108_[26] = execute_SRC1[5];
    _zz_108_[27] = execute_SRC1[4];
    _zz_108_[28] = execute_SRC1[3];
    _zz_108_[29] = execute_SRC1[2];
    _zz_108_[30] = execute_SRC1[1];
    _zz_108_[31] = execute_SRC1[0];
  end

  assign execute_FullBarrelShifterPlugin_reversed = ((execute_SHIFT_CTRL == `ShiftCtrlEnum_defaultEncoding_SLL_1) ? _zz_108_ : execute_SRC1);
  always @ (*) begin
    _zz_109_[0] = memory_SHIFT_RIGHT[31];
    _zz_109_[1] = memory_SHIFT_RIGHT[30];
    _zz_109_[2] = memory_SHIFT_RIGHT[29];
    _zz_109_[3] = memory_SHIFT_RIGHT[28];
    _zz_109_[4] = memory_SHIFT_RIGHT[27];
    _zz_109_[5] = memory_SHIFT_RIGHT[26];
    _zz_109_[6] = memory_SHIFT_RIGHT[25];
    _zz_109_[7] = memory_SHIFT_RIGHT[24];
    _zz_109_[8] = memory_SHIFT_RIGHT[23];
    _zz_109_[9] = memory_SHIFT_RIGHT[22];
    _zz_109_[10] = memory_SHIFT_RIGHT[21];
    _zz_109_[11] = memory_SHIFT_RIGHT[20];
    _zz_109_[12] = memory_SHIFT_RIGHT[19];
    _zz_109_[13] = memory_SHIFT_RIGHT[18];
    _zz_109_[14] = memory_SHIFT_RIGHT[17];
    _zz_109_[15] = memory_SHIFT_RIGHT[16];
    _zz_109_[16] = memory_SHIFT_RIGHT[15];
    _zz_109_[17] = memory_SHIFT_RIGHT[14];
    _zz_109_[18] = memory_SHIFT_RIGHT[13];
    _zz_109_[19] = memory_SHIFT_RIGHT[12];
    _zz_109_[20] = memory_SHIFT_RIGHT[11];
    _zz_109_[21] = memory_SHIFT_RIGHT[10];
    _zz_109_[22] = memory_SHIFT_RIGHT[9];
    _zz_109_[23] = memory_SHIFT_RIGHT[8];
    _zz_109_[24] = memory_SHIFT_RIGHT[7];
    _zz_109_[25] = memory_SHIFT_RIGHT[6];
    _zz_109_[26] = memory_SHIFT_RIGHT[5];
    _zz_109_[27] = memory_SHIFT_RIGHT[4];
    _zz_109_[28] = memory_SHIFT_RIGHT[3];
    _zz_109_[29] = memory_SHIFT_RIGHT[2];
    _zz_109_[30] = memory_SHIFT_RIGHT[1];
    _zz_109_[31] = memory_SHIFT_RIGHT[0];
  end

  always @ (*) begin
    _zz_110_ = 1'b0;
    if(_zz_173_)begin
      if(_zz_174_)begin
        if(_zz_115_)begin
          _zz_110_ = 1'b1;
        end
      end
    end
    if(_zz_175_)begin
      if(_zz_176_)begin
        if(_zz_117_)begin
          _zz_110_ = 1'b1;
        end
      end
    end
    if(_zz_177_)begin
      if(_zz_178_)begin
        if(_zz_119_)begin
          _zz_110_ = 1'b1;
        end
      end
    end
    if((! decode_RS1_USE))begin
      _zz_110_ = 1'b0;
    end
  end

  always @ (*) begin
    _zz_111_ = 1'b0;
    if(_zz_173_)begin
      if(_zz_174_)begin
        if(_zz_116_)begin
          _zz_111_ = 1'b1;
        end
      end
    end
    if(_zz_175_)begin
      if(_zz_176_)begin
        if(_zz_118_)begin
          _zz_111_ = 1'b1;
        end
      end
    end
    if(_zz_177_)begin
      if(_zz_178_)begin
        if(_zz_120_)begin
          _zz_111_ = 1'b1;
        end
      end
    end
    if((! decode_RS2_USE))begin
      _zz_111_ = 1'b0;
    end
  end

  assign _zz_115_ = (writeBack_INSTRUCTION[11 : 7] == decode_INSTRUCTION[19 : 15]);
  assign _zz_116_ = (writeBack_INSTRUCTION[11 : 7] == decode_INSTRUCTION[24 : 20]);
  assign _zz_117_ = (memory_INSTRUCTION[11 : 7] == decode_INSTRUCTION[19 : 15]);
  assign _zz_118_ = (memory_INSTRUCTION[11 : 7] == decode_INSTRUCTION[24 : 20]);
  assign _zz_119_ = (execute_INSTRUCTION[11 : 7] == decode_INSTRUCTION[19 : 15]);
  assign _zz_120_ = (execute_INSTRUCTION[11 : 7] == decode_INSTRUCTION[24 : 20]);
  assign execute_BranchPlugin_eq = (execute_SRC1 == execute_SRC2);
  assign _zz_121_ = execute_INSTRUCTION[14 : 12];
  always @ (*) begin
    if((_zz_121_ == (3'b000))) begin
        _zz_122_ = execute_BranchPlugin_eq;
    end else if((_zz_121_ == (3'b001))) begin
        _zz_122_ = (! execute_BranchPlugin_eq);
    end else if((((_zz_121_ & (3'b101)) == (3'b101)))) begin
        _zz_122_ = (! execute_SRC_LESS);
    end else begin
        _zz_122_ = execute_SRC_LESS;
    end
  end

  always @ (*) begin
    case(execute_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_INC : begin
        _zz_123_ = 1'b0;
      end
      `BranchCtrlEnum_defaultEncoding_JAL : begin
        _zz_123_ = 1'b1;
      end
      `BranchCtrlEnum_defaultEncoding_JALR : begin
        _zz_123_ = 1'b1;
      end
      default : begin
        _zz_123_ = _zz_122_;
      end
    endcase
  end

  assign _zz_124_ = _zz_225_[11];
  always @ (*) begin
    _zz_125_[19] = _zz_124_;
    _zz_125_[18] = _zz_124_;
    _zz_125_[17] = _zz_124_;
    _zz_125_[16] = _zz_124_;
    _zz_125_[15] = _zz_124_;
    _zz_125_[14] = _zz_124_;
    _zz_125_[13] = _zz_124_;
    _zz_125_[12] = _zz_124_;
    _zz_125_[11] = _zz_124_;
    _zz_125_[10] = _zz_124_;
    _zz_125_[9] = _zz_124_;
    _zz_125_[8] = _zz_124_;
    _zz_125_[7] = _zz_124_;
    _zz_125_[6] = _zz_124_;
    _zz_125_[5] = _zz_124_;
    _zz_125_[4] = _zz_124_;
    _zz_125_[3] = _zz_124_;
    _zz_125_[2] = _zz_124_;
    _zz_125_[1] = _zz_124_;
    _zz_125_[0] = _zz_124_;
  end

  assign _zz_126_ = _zz_226_[19];
  always @ (*) begin
    _zz_127_[10] = _zz_126_;
    _zz_127_[9] = _zz_126_;
    _zz_127_[8] = _zz_126_;
    _zz_127_[7] = _zz_126_;
    _zz_127_[6] = _zz_126_;
    _zz_127_[5] = _zz_126_;
    _zz_127_[4] = _zz_126_;
    _zz_127_[3] = _zz_126_;
    _zz_127_[2] = _zz_126_;
    _zz_127_[1] = _zz_126_;
    _zz_127_[0] = _zz_126_;
  end

  assign _zz_128_ = _zz_227_[11];
  always @ (*) begin
    _zz_129_[18] = _zz_128_;
    _zz_129_[17] = _zz_128_;
    _zz_129_[16] = _zz_128_;
    _zz_129_[15] = _zz_128_;
    _zz_129_[14] = _zz_128_;
    _zz_129_[13] = _zz_128_;
    _zz_129_[12] = _zz_128_;
    _zz_129_[11] = _zz_128_;
    _zz_129_[10] = _zz_128_;
    _zz_129_[9] = _zz_128_;
    _zz_129_[8] = _zz_128_;
    _zz_129_[7] = _zz_128_;
    _zz_129_[6] = _zz_128_;
    _zz_129_[5] = _zz_128_;
    _zz_129_[4] = _zz_128_;
    _zz_129_[3] = _zz_128_;
    _zz_129_[2] = _zz_128_;
    _zz_129_[1] = _zz_128_;
    _zz_129_[0] = _zz_128_;
  end

  always @ (*) begin
    case(execute_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_JALR : begin
        _zz_130_ = (_zz_228_[1] ^ execute_RS1[1]);
      end
      `BranchCtrlEnum_defaultEncoding_JAL : begin
        _zz_130_ = _zz_229_[1];
      end
      default : begin
        _zz_130_ = _zz_230_[1];
      end
    endcase
  end

  assign execute_BranchPlugin_missAlignedTarget = (execute_BRANCH_COND_RESULT && _zz_130_);
  always @ (*) begin
    case(execute_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_JALR : begin
        execute_BranchPlugin_branch_src1 = execute_RS1;
      end
      default : begin
        execute_BranchPlugin_branch_src1 = execute_PC;
      end
    endcase
  end

  assign _zz_131_ = _zz_231_[11];
  always @ (*) begin
    _zz_132_[19] = _zz_131_;
    _zz_132_[18] = _zz_131_;
    _zz_132_[17] = _zz_131_;
    _zz_132_[16] = _zz_131_;
    _zz_132_[15] = _zz_131_;
    _zz_132_[14] = _zz_131_;
    _zz_132_[13] = _zz_131_;
    _zz_132_[12] = _zz_131_;
    _zz_132_[11] = _zz_131_;
    _zz_132_[10] = _zz_131_;
    _zz_132_[9] = _zz_131_;
    _zz_132_[8] = _zz_131_;
    _zz_132_[7] = _zz_131_;
    _zz_132_[6] = _zz_131_;
    _zz_132_[5] = _zz_131_;
    _zz_132_[4] = _zz_131_;
    _zz_132_[3] = _zz_131_;
    _zz_132_[2] = _zz_131_;
    _zz_132_[1] = _zz_131_;
    _zz_132_[0] = _zz_131_;
  end

  always @ (*) begin
    case(execute_BRANCH_CTRL)
      `BranchCtrlEnum_defaultEncoding_JALR : begin
        execute_BranchPlugin_branch_src2 = {_zz_132_,execute_INSTRUCTION[31 : 20]};
      end
      default : begin
        execute_BranchPlugin_branch_src2 = ((execute_BRANCH_CTRL == `BranchCtrlEnum_defaultEncoding_JAL) ? {{_zz_134_,{{{_zz_358_,execute_INSTRUCTION[19 : 12]},execute_INSTRUCTION[20]},execute_INSTRUCTION[30 : 21]}},1'b0} : {{_zz_136_,{{{_zz_359_,_zz_360_},execute_INSTRUCTION[30 : 25]},execute_INSTRUCTION[11 : 8]}},1'b0});
        if(execute_PREDICTION_HAD_BRANCHED2)begin
          execute_BranchPlugin_branch_src2 = {29'd0, _zz_234_};
        end
      end
    endcase
  end

  assign _zz_133_ = _zz_232_[19];
  always @ (*) begin
    _zz_134_[10] = _zz_133_;
    _zz_134_[9] = _zz_133_;
    _zz_134_[8] = _zz_133_;
    _zz_134_[7] = _zz_133_;
    _zz_134_[6] = _zz_133_;
    _zz_134_[5] = _zz_133_;
    _zz_134_[4] = _zz_133_;
    _zz_134_[3] = _zz_133_;
    _zz_134_[2] = _zz_133_;
    _zz_134_[1] = _zz_133_;
    _zz_134_[0] = _zz_133_;
  end

  assign _zz_135_ = _zz_233_[11];
  always @ (*) begin
    _zz_136_[18] = _zz_135_;
    _zz_136_[17] = _zz_135_;
    _zz_136_[16] = _zz_135_;
    _zz_136_[15] = _zz_135_;
    _zz_136_[14] = _zz_135_;
    _zz_136_[13] = _zz_135_;
    _zz_136_[12] = _zz_135_;
    _zz_136_[11] = _zz_135_;
    _zz_136_[10] = _zz_135_;
    _zz_136_[9] = _zz_135_;
    _zz_136_[8] = _zz_135_;
    _zz_136_[7] = _zz_135_;
    _zz_136_[6] = _zz_135_;
    _zz_136_[5] = _zz_135_;
    _zz_136_[4] = _zz_135_;
    _zz_136_[3] = _zz_135_;
    _zz_136_[2] = _zz_135_;
    _zz_136_[1] = _zz_135_;
    _zz_136_[0] = _zz_135_;
  end

  assign execute_BranchPlugin_branchAdder = (execute_BranchPlugin_branch_src1 + execute_BranchPlugin_branch_src2);
  assign BranchPlugin_jumpInterface_valid = ((memory_arbitration_isValid && memory_BRANCH_DO) && (! 1'b0));
  assign BranchPlugin_jumpInterface_payload = memory_BRANCH_CALC;
  assign IBusCachedPlugin_decodePrediction_rsp_wasWrong = BranchPlugin_jumpInterface_valid;
  always @ (*) begin
    CsrPlugin_privilege = (2'b11);
    if(CsrPlugin_forceMachineWire)begin
      CsrPlugin_privilege = (2'b11);
    end
  end

  assign CsrPlugin_misa_base = (2'b01);
  assign CsrPlugin_misa_extensions = 26'h0000042;
  assign _zz_137_ = (CsrPlugin_mip_MTIP && CsrPlugin_mie_MTIE);
  assign _zz_138_ = (CsrPlugin_mip_MSIP && CsrPlugin_mie_MSIE);
  assign _zz_139_ = (CsrPlugin_mip_MEIP && CsrPlugin_mie_MEIE);
  assign CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_decode = 1'b0;
  assign CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilegeUncapped = (2'b11);
  assign CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilege = ((CsrPlugin_privilege < CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilegeUncapped) ? CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilegeUncapped : CsrPlugin_privilege);
  assign CsrPlugin_exceptionPortCtrl_exceptionValids_decode = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_decode;
  always @ (*) begin
    CsrPlugin_exceptionPortCtrl_exceptionValids_execute = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute;
    if(CsrPlugin_selfException_valid)begin
      CsrPlugin_exceptionPortCtrl_exceptionValids_execute = 1'b1;
    end
    if(execute_arbitration_isFlushed)begin
      CsrPlugin_exceptionPortCtrl_exceptionValids_execute = 1'b0;
    end
  end

  always @ (*) begin
    CsrPlugin_exceptionPortCtrl_exceptionValids_memory = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory;
    if(DBusSimplePlugin_memoryExceptionPort_valid)begin
      CsrPlugin_exceptionPortCtrl_exceptionValids_memory = 1'b1;
    end
    if(memory_arbitration_isFlushed)begin
      CsrPlugin_exceptionPortCtrl_exceptionValids_memory = 1'b0;
    end
  end

  always @ (*) begin
    CsrPlugin_exceptionPortCtrl_exceptionValids_writeBack = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack;
    if(writeBack_arbitration_isFlushed)begin
      CsrPlugin_exceptionPortCtrl_exceptionValids_writeBack = 1'b0;
    end
  end

  assign CsrPlugin_exceptionPendings_0 = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_decode;
  assign CsrPlugin_exceptionPendings_1 = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute;
  assign CsrPlugin_exceptionPendings_2 = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory;
  assign CsrPlugin_exceptionPendings_3 = CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack;
  assign CsrPlugin_exception = (CsrPlugin_exceptionPortCtrl_exceptionValids_writeBack && CsrPlugin_allowException);
  assign CsrPlugin_lastStageWasWfi = 1'b0;
  assign CsrPlugin_pipelineLiberator_active = ((CsrPlugin_interrupt_valid && CsrPlugin_allowInterrupts) && decode_arbitration_isValid);
  always @ (*) begin
    CsrPlugin_pipelineLiberator_done = CsrPlugin_pipelineLiberator_pcValids_2;
    if(({CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack,{CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory,CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute}} != (3'b000)))begin
      CsrPlugin_pipelineLiberator_done = 1'b0;
    end
    if(CsrPlugin_hadException)begin
      CsrPlugin_pipelineLiberator_done = 1'b0;
    end
  end

  assign CsrPlugin_interruptJump = ((CsrPlugin_interrupt_valid && CsrPlugin_pipelineLiberator_done) && CsrPlugin_allowInterrupts);
  always @ (*) begin
    CsrPlugin_targetPrivilege = CsrPlugin_interrupt_targetPrivilege;
    if(CsrPlugin_hadException)begin
      CsrPlugin_targetPrivilege = CsrPlugin_exceptionPortCtrl_exceptionTargetPrivilege;
    end
  end

  always @ (*) begin
    CsrPlugin_trapCause = CsrPlugin_interrupt_code;
    if(CsrPlugin_hadException)begin
      CsrPlugin_trapCause = CsrPlugin_exceptionPortCtrl_exceptionContext_code;
    end
  end

  always @ (*) begin
    CsrPlugin_xtvec_mode = (2'bxx);
    case(CsrPlugin_targetPrivilege)
      2'b11 : begin
        CsrPlugin_xtvec_mode = CsrPlugin_mtvec_mode;
      end
      default : begin
      end
    endcase
  end

  always @ (*) begin
    CsrPlugin_xtvec_base = 30'h0;
    case(CsrPlugin_targetPrivilege)
      2'b11 : begin
        CsrPlugin_xtvec_base = CsrPlugin_mtvec_base;
      end
      default : begin
      end
    endcase
  end

  assign contextSwitching = CsrPlugin_jumpInterface_valid;
  assign execute_CsrPlugin_blockedBySideEffects = ({writeBack_arbitration_isValid,memory_arbitration_isValid} != (2'b00));
  always @ (*) begin
    execute_CsrPlugin_illegalAccess = 1'b1;
    if(execute_CsrPlugin_csr_1984)begin
      if(execute_CSR_WRITE_OPCODE)begin
        execute_CsrPlugin_illegalAccess = 1'b0;
      end
    end
    if(execute_CsrPlugin_csr_768)begin
      execute_CsrPlugin_illegalAccess = 1'b0;
    end
    if(execute_CsrPlugin_csr_836)begin
      execute_CsrPlugin_illegalAccess = 1'b0;
    end
    if(execute_CsrPlugin_csr_772)begin
      execute_CsrPlugin_illegalAccess = 1'b0;
    end
    if(execute_CsrPlugin_csr_773)begin
      if(execute_CSR_WRITE_OPCODE)begin
        execute_CsrPlugin_illegalAccess = 1'b0;
      end
    end
    if(execute_CsrPlugin_csr_833)begin
      execute_CsrPlugin_illegalAccess = 1'b0;
    end
    if(execute_CsrPlugin_csr_834)begin
      if(execute_CSR_READ_OPCODE)begin
        execute_CsrPlugin_illegalAccess = 1'b0;
      end
    end
    if(execute_CsrPlugin_csr_835)begin
      if(execute_CSR_READ_OPCODE)begin
        execute_CsrPlugin_illegalAccess = 1'b0;
      end
    end
    if(execute_CsrPlugin_csr_3008)begin
      execute_CsrPlugin_illegalAccess = 1'b0;
    end
    if(execute_CsrPlugin_csr_4032)begin
      if(execute_CSR_READ_OPCODE)begin
        execute_CsrPlugin_illegalAccess = 1'b0;
      end
    end
    if((CsrPlugin_privilege < execute_CsrPlugin_csrAddress[9 : 8]))begin
      execute_CsrPlugin_illegalAccess = 1'b1;
    end
    if(((! execute_arbitration_isValid) || (! execute_IS_CSR)))begin
      execute_CsrPlugin_illegalAccess = 1'b0;
    end
  end

  always @ (*) begin
    execute_CsrPlugin_illegalInstruction = 1'b0;
    if((execute_arbitration_isValid && (execute_ENV_CTRL == `EnvCtrlEnum_defaultEncoding_XRET)))begin
      if((CsrPlugin_privilege < execute_INSTRUCTION[29 : 28]))begin
        execute_CsrPlugin_illegalInstruction = 1'b1;
      end
    end
  end

  always @ (*) begin
    CsrPlugin_selfException_valid = 1'b0;
    if(_zz_179_)begin
      CsrPlugin_selfException_valid = 1'b1;
    end
  end

  always @ (*) begin
    CsrPlugin_selfException_payload_code = (4'bxxxx);
    if(_zz_179_)begin
      case(CsrPlugin_privilege)
        2'b00 : begin
          CsrPlugin_selfException_payload_code = (4'b1000);
        end
        default : begin
          CsrPlugin_selfException_payload_code = (4'b1011);
        end
      endcase
    end
  end

  assign CsrPlugin_selfException_payload_badAddr = execute_INSTRUCTION;
  assign execute_CsrPlugin_writeInstruction = ((execute_arbitration_isValid && execute_IS_CSR) && execute_CSR_WRITE_OPCODE);
  assign execute_CsrPlugin_readInstruction = ((execute_arbitration_isValid && execute_IS_CSR) && execute_CSR_READ_OPCODE);
  assign execute_CsrPlugin_writeEnable = ((execute_CsrPlugin_writeInstruction && (! execute_CsrPlugin_blockedBySideEffects)) && (! execute_arbitration_isStuckByOthers));
  assign execute_CsrPlugin_readEnable = ((execute_CsrPlugin_readInstruction && (! execute_CsrPlugin_blockedBySideEffects)) && (! execute_arbitration_isStuckByOthers));
  assign execute_CsrPlugin_readToWriteData = execute_CsrPlugin_readData;
  always @ (*) begin
    case(_zz_186_)
      1'b0 : begin
        execute_CsrPlugin_writeData = execute_SRC1;
      end
      default : begin
        execute_CsrPlugin_writeData = (execute_INSTRUCTION[12] ? (execute_CsrPlugin_readToWriteData & (~ execute_SRC1)) : (execute_CsrPlugin_readToWriteData | execute_SRC1));
      end
    endcase
  end

  assign execute_CsrPlugin_csrAddress = execute_INSTRUCTION[31 : 20];
  assign _zz_141_ = (_zz_140_ & externalInterruptArray_regNext);
  assign externalInterrupt = (_zz_141_ != 32'h0);
  assign _zz_26_ = decode_SRC2_CTRL;
  assign _zz_24_ = _zz_47_;
  assign _zz_36_ = decode_to_execute_SRC2_CTRL;
  assign _zz_23_ = decode_ALU_CTRL;
  assign _zz_21_ = _zz_43_;
  assign _zz_38_ = decode_to_execute_ALU_CTRL;
  assign _zz_20_ = decode_ENV_CTRL;
  assign _zz_17_ = execute_ENV_CTRL;
  assign _zz_15_ = memory_ENV_CTRL;
  assign _zz_18_ = _zz_44_;
  assign _zz_28_ = decode_to_execute_ENV_CTRL;
  assign _zz_27_ = execute_to_memory_ENV_CTRL;
  assign _zz_29_ = memory_to_writeBack_ENV_CTRL;
  assign _zz_13_ = decode_SHIFT_CTRL;
  assign _zz_10_ = execute_SHIFT_CTRL;
  assign _zz_11_ = _zz_45_;
  assign _zz_34_ = decode_to_execute_SHIFT_CTRL;
  assign _zz_33_ = execute_to_memory_SHIFT_CTRL;
  assign _zz_8_ = decode_ALU_BITWISE_CTRL;
  assign _zz_6_ = _zz_49_;
  assign _zz_39_ = decode_to_execute_ALU_BITWISE_CTRL;
  assign _zz_5_ = decode_SRC1_CTRL;
  assign _zz_3_ = _zz_46_;
  assign _zz_37_ = decode_to_execute_SRC1_CTRL;
  assign _zz_2_ = decode_BRANCH_CTRL;
  assign _zz_52_ = _zz_48_;
  assign _zz_30_ = decode_to_execute_BRANCH_CTRL;
  assign decode_arbitration_isFlushed = (({writeBack_arbitration_flushNext,{memory_arbitration_flushNext,execute_arbitration_flushNext}} != (3'b000)) || ({writeBack_arbitration_flushIt,{memory_arbitration_flushIt,{execute_arbitration_flushIt,decode_arbitration_flushIt}}} != (4'b0000)));
  assign execute_arbitration_isFlushed = (({writeBack_arbitration_flushNext,memory_arbitration_flushNext} != (2'b00)) || ({writeBack_arbitration_flushIt,{memory_arbitration_flushIt,execute_arbitration_flushIt}} != (3'b000)));
  assign memory_arbitration_isFlushed = ((writeBack_arbitration_flushNext != (1'b0)) || ({writeBack_arbitration_flushIt,memory_arbitration_flushIt} != (2'b00)));
  assign writeBack_arbitration_isFlushed = (1'b0 || (writeBack_arbitration_flushIt != (1'b0)));
  assign decode_arbitration_isStuckByOthers = (decode_arbitration_haltByOther || (((1'b0 || execute_arbitration_isStuck) || memory_arbitration_isStuck) || writeBack_arbitration_isStuck));
  assign decode_arbitration_isStuck = (decode_arbitration_haltItself || decode_arbitration_isStuckByOthers);
  assign decode_arbitration_isMoving = ((! decode_arbitration_isStuck) && (! decode_arbitration_removeIt));
  assign decode_arbitration_isFiring = ((decode_arbitration_isValid && (! decode_arbitration_isStuck)) && (! decode_arbitration_removeIt));
  assign execute_arbitration_isStuckByOthers = (execute_arbitration_haltByOther || ((1'b0 || memory_arbitration_isStuck) || writeBack_arbitration_isStuck));
  assign execute_arbitration_isStuck = (execute_arbitration_haltItself || execute_arbitration_isStuckByOthers);
  assign execute_arbitration_isMoving = ((! execute_arbitration_isStuck) && (! execute_arbitration_removeIt));
  assign execute_arbitration_isFiring = ((execute_arbitration_isValid && (! execute_arbitration_isStuck)) && (! execute_arbitration_removeIt));
  assign memory_arbitration_isStuckByOthers = (memory_arbitration_haltByOther || (1'b0 || writeBack_arbitration_isStuck));
  assign memory_arbitration_isStuck = (memory_arbitration_haltItself || memory_arbitration_isStuckByOthers);
  assign memory_arbitration_isMoving = ((! memory_arbitration_isStuck) && (! memory_arbitration_removeIt));
  assign memory_arbitration_isFiring = ((memory_arbitration_isValid && (! memory_arbitration_isStuck)) && (! memory_arbitration_removeIt));
  assign writeBack_arbitration_isStuckByOthers = (writeBack_arbitration_haltByOther || 1'b0);
  assign writeBack_arbitration_isStuck = (writeBack_arbitration_haltItself || writeBack_arbitration_isStuckByOthers);
  assign writeBack_arbitration_isMoving = ((! writeBack_arbitration_isStuck) && (! writeBack_arbitration_removeIt));
  assign writeBack_arbitration_isFiring = ((writeBack_arbitration_isValid && (! writeBack_arbitration_isStuck)) && (! writeBack_arbitration_removeIt));
  always @ (*) begin
    _zz_142_ = 32'h0;
    if(execute_CsrPlugin_csr_768)begin
      _zz_142_[12 : 11] = CsrPlugin_mstatus_MPP;
      _zz_142_[7 : 7] = CsrPlugin_mstatus_MPIE;
      _zz_142_[3 : 3] = CsrPlugin_mstatus_MIE;
    end
  end

  always @ (*) begin
    _zz_143_ = 32'h0;
    if(execute_CsrPlugin_csr_836)begin
      _zz_143_[11 : 11] = CsrPlugin_mip_MEIP;
      _zz_143_[7 : 7] = CsrPlugin_mip_MTIP;
      _zz_143_[3 : 3] = CsrPlugin_mip_MSIP;
    end
  end

  always @ (*) begin
    _zz_144_ = 32'h0;
    if(execute_CsrPlugin_csr_772)begin
      _zz_144_[11 : 11] = CsrPlugin_mie_MEIE;
      _zz_144_[7 : 7] = CsrPlugin_mie_MTIE;
      _zz_144_[3 : 3] = CsrPlugin_mie_MSIE;
    end
  end

  always @ (*) begin
    _zz_145_ = 32'h0;
    if(execute_CsrPlugin_csr_833)begin
      _zz_145_[31 : 0] = CsrPlugin_mepc;
    end
  end

  always @ (*) begin
    _zz_146_ = 32'h0;
    if(execute_CsrPlugin_csr_834)begin
      _zz_146_[31 : 31] = CsrPlugin_mcause_interrupt;
      _zz_146_[3 : 0] = CsrPlugin_mcause_exceptionCode;
    end
  end

  always @ (*) begin
    _zz_147_ = 32'h0;
    if(execute_CsrPlugin_csr_835)begin
      _zz_147_[31 : 0] = CsrPlugin_mtval;
    end
  end

  always @ (*) begin
    _zz_148_ = 32'h0;
    if(execute_CsrPlugin_csr_3008)begin
      _zz_148_[31 : 0] = _zz_140_;
    end
  end

  always @ (*) begin
    _zz_149_ = 32'h0;
    if(execute_CsrPlugin_csr_4032)begin
      _zz_149_[31 : 0] = _zz_141_;
    end
  end

  assign execute_CsrPlugin_readData = (((_zz_142_ | _zz_143_) | (_zz_144_ | _zz_145_)) | ((_zz_146_ | _zz_147_) | (_zz_148_ | _zz_149_)));
  assign iBusAXI_ar_valid = iBus_cmd_valid;
  assign iBusAXI_ar_payload_len = 8'h07;
  assign iBusAXI_ar_payload_addr = iBus_cmd_payload_address;
  assign iBusAXI_ar_payload_prot = (3'b110);
  assign iBusAXI_ar_payload_cache = (4'b1111);
  assign iBusAXI_ar_payload_burst = (2'b01);
  assign iBus_cmd_ready = iBusAXI_ar_ready;
  assign iBus_rsp_valid = iBusAXI_r_valid;
  assign iBus_rsp_payload_data = iBusAXI_r_payload_data;
  assign iBus_rsp_payload_error = (! (iBusAXI_r_payload_resp == (2'b00)));
  assign iBusAXI_r_ready = 1'b1;
  assign dBus_cmd_halfPipe_valid = dBus_cmd_halfPipe_regs_valid;
  assign dBus_cmd_halfPipe_payload_wr = dBus_cmd_halfPipe_regs_payload_wr;
  assign dBus_cmd_halfPipe_payload_address = dBus_cmd_halfPipe_regs_payload_address;
  assign dBus_cmd_halfPipe_payload_data = dBus_cmd_halfPipe_regs_payload_data;
  assign dBus_cmd_halfPipe_payload_size = dBus_cmd_halfPipe_regs_payload_size;
  assign dBus_cmd_ready = dBus_cmd_halfPipe_regs_ready;
  assign dBusWishbone_ADR = (dBus_cmd_halfPipe_payload_address >>> 2);
  assign dBusWishbone_CTI = (3'b000);
  assign dBusWishbone_BTE = (2'b00);
  always @ (*) begin
    case(dBus_cmd_halfPipe_payload_size)
      2'b00 : begin
        _zz_150_ = (4'b0001);
      end
      2'b01 : begin
        _zz_150_ = (4'b0011);
      end
      default : begin
        _zz_150_ = (4'b1111);
      end
    endcase
  end

  always @ (*) begin
    dBusWishbone_SEL = _zz_244_[3:0];
    if((! dBus_cmd_halfPipe_payload_wr))begin
      dBusWishbone_SEL = (4'b1111);
    end
  end

  assign dBusWishbone_WE = dBus_cmd_halfPipe_payload_wr;
  assign dBusWishbone_DAT_MOSI = dBus_cmd_halfPipe_payload_data;
  assign dBus_cmd_halfPipe_ready = (dBus_cmd_halfPipe_valid && dBusWishbone_ACK);
  assign dBusWishbone_CYC = dBus_cmd_halfPipe_valid;
  assign dBusWishbone_STB = dBus_cmd_halfPipe_valid;
  assign dBus_rsp_ready = ((dBus_cmd_halfPipe_valid && (! dBusWishbone_WE)) && dBusWishbone_ACK);
  assign dBus_rsp_data = dBusWishbone_DAT_MISO;
  assign dBus_rsp_error = 1'b0;
  always @ (posedge clk or posedge reset) begin
    if (reset) begin
      IBusCachedPlugin_fetchPc_pcReg <= externalResetVector;
      IBusCachedPlugin_fetchPc_correctionReg <= 1'b0;
      IBusCachedPlugin_fetchPc_booted <= 1'b0;
      IBusCachedPlugin_fetchPc_inc <= 1'b0;
      _zz_65_ <= 1'b0;
      _zz_67_ <= 1'b0;
      IBusCachedPlugin_injector_nextPcCalc_valids_0 <= 1'b0;
      IBusCachedPlugin_injector_nextPcCalc_valids_1 <= 1'b0;
      IBusCachedPlugin_injector_nextPcCalc_valids_2 <= 1'b0;
      IBusCachedPlugin_injector_nextPcCalc_valids_3 <= 1'b0;
      IBusCachedPlugin_injector_nextPcCalc_valids_4 <= 1'b0;
      IBusCachedPlugin_rspCounter <= _zz_80_;
      IBusCachedPlugin_rspCounter <= 32'h0;
      RegFilePlugin_shadow_write <= 1'b0;
      RegFilePlugin_shadow_read <= 1'b0;
      RegFilePlugin_shadow_clear <= 1'b0;
      _zz_100_ <= 1'b1;
      _zz_112_ <= 1'b0;
      CsrPlugin_mstatus_MIE <= 1'b0;
      CsrPlugin_mstatus_MPIE <= 1'b0;
      CsrPlugin_mstatus_MPP <= (2'b11);
      CsrPlugin_mie_MEIE <= 1'b0;
      CsrPlugin_mie_MTIE <= 1'b0;
      CsrPlugin_mie_MSIE <= 1'b0;
      CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute <= 1'b0;
      CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory <= 1'b0;
      CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack <= 1'b0;
      CsrPlugin_interrupt_valid <= 1'b0;
      CsrPlugin_pipelineLiberator_pcValids_0 <= 1'b0;
      CsrPlugin_pipelineLiberator_pcValids_1 <= 1'b0;
      CsrPlugin_pipelineLiberator_pcValids_2 <= 1'b0;
      CsrPlugin_hadException <= 1'b0;
      execute_CsrPlugin_wfiWake <= 1'b0;
      _zz_140_ <= 32'h0;
      execute_arbitration_isValid <= 1'b0;
      memory_arbitration_isValid <= 1'b0;
      writeBack_arbitration_isValid <= 1'b0;
      memory_to_writeBack_REGFILE_WRITE_DATA <= 32'h0;
      memory_to_writeBack_INSTRUCTION <= 32'h0;
      dBus_cmd_halfPipe_regs_valid <= 1'b0;
      dBus_cmd_halfPipe_regs_ready <= 1'b1;
    end else begin
      if(IBusCachedPlugin_fetchPc_correction)begin
        IBusCachedPlugin_fetchPc_correctionReg <= 1'b1;
      end
      if((IBusCachedPlugin_fetchPc_output_valid && IBusCachedPlugin_fetchPc_output_ready))begin
        IBusCachedPlugin_fetchPc_correctionReg <= 1'b0;
      end
      IBusCachedPlugin_fetchPc_booted <= 1'b1;
      if((IBusCachedPlugin_fetchPc_correction || IBusCachedPlugin_fetchPc_pcRegPropagate))begin
        IBusCachedPlugin_fetchPc_inc <= 1'b0;
      end
      if((IBusCachedPlugin_fetchPc_output_valid && IBusCachedPlugin_fetchPc_output_ready))begin
        IBusCachedPlugin_fetchPc_inc <= 1'b1;
      end
      if(((! IBusCachedPlugin_fetchPc_output_valid) && IBusCachedPlugin_fetchPc_output_ready))begin
        IBusCachedPlugin_fetchPc_inc <= 1'b0;
      end
      if((IBusCachedPlugin_fetchPc_booted && ((IBusCachedPlugin_fetchPc_output_ready || IBusCachedPlugin_fetchPc_correction) || IBusCachedPlugin_fetchPc_pcRegPropagate)))begin
        IBusCachedPlugin_fetchPc_pcReg <= IBusCachedPlugin_fetchPc_pc;
      end
      if(IBusCachedPlugin_iBusRsp_flush)begin
        _zz_65_ <= 1'b0;
      end
      if(_zz_63_)begin
        _zz_65_ <= (IBusCachedPlugin_iBusRsp_stages_0_output_valid && (! 1'b0));
      end
      if(IBusCachedPlugin_iBusRsp_flush)begin
        _zz_67_ <= 1'b0;
      end
      if(IBusCachedPlugin_iBusRsp_stages_1_output_ready)begin
        _zz_67_ <= (IBusCachedPlugin_iBusRsp_stages_1_output_valid && (! IBusCachedPlugin_iBusRsp_flush));
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_0 <= 1'b0;
      end
      if((! (! IBusCachedPlugin_iBusRsp_stages_1_input_ready)))begin
        IBusCachedPlugin_injector_nextPcCalc_valids_0 <= 1'b1;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_1 <= 1'b0;
      end
      if((! (! IBusCachedPlugin_iBusRsp_stages_2_input_ready)))begin
        IBusCachedPlugin_injector_nextPcCalc_valids_1 <= IBusCachedPlugin_injector_nextPcCalc_valids_0;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_1 <= 1'b0;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_2 <= 1'b0;
      end
      if((! execute_arbitration_isStuck))begin
        IBusCachedPlugin_injector_nextPcCalc_valids_2 <= IBusCachedPlugin_injector_nextPcCalc_valids_1;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_2 <= 1'b0;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_3 <= 1'b0;
      end
      if((! memory_arbitration_isStuck))begin
        IBusCachedPlugin_injector_nextPcCalc_valids_3 <= IBusCachedPlugin_injector_nextPcCalc_valids_2;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_3 <= 1'b0;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_4 <= 1'b0;
      end
      if((! writeBack_arbitration_isStuck))begin
        IBusCachedPlugin_injector_nextPcCalc_valids_4 <= IBusCachedPlugin_injector_nextPcCalc_valids_3;
      end
      if(IBusCachedPlugin_fetchPc_flushed)begin
        IBusCachedPlugin_injector_nextPcCalc_valids_4 <= 1'b0;
      end
      if(iBus_rsp_valid)begin
        IBusCachedPlugin_rspCounter <= (IBusCachedPlugin_rspCounter + 32'h00000001);
      end
      if((RegFilePlugin_shadow_clear && (! decode_arbitration_isStuck)))begin
        RegFilePlugin_shadow_read <= 1'b0;
      end
      if((RegFilePlugin_shadow_clear && (! writeBack_arbitration_isStuck)))begin
        RegFilePlugin_shadow_write <= 1'b0;
      end
      _zz_100_ <= 1'b0;
      _zz_112_ <= (_zz_41_ && writeBack_arbitration_isFiring);
      if((! execute_arbitration_isStuck))begin
        CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute <= 1'b0;
      end else begin
        CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_execute <= CsrPlugin_exceptionPortCtrl_exceptionValids_execute;
      end
      if((! memory_arbitration_isStuck))begin
        CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory <= (CsrPlugin_exceptionPortCtrl_exceptionValids_execute && (! execute_arbitration_isStuck));
      end else begin
        CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_memory <= CsrPlugin_exceptionPortCtrl_exceptionValids_memory;
      end
      if((! writeBack_arbitration_isStuck))begin
        CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack <= (CsrPlugin_exceptionPortCtrl_exceptionValids_memory && (! memory_arbitration_isStuck));
      end else begin
        CsrPlugin_exceptionPortCtrl_exceptionValidsRegs_writeBack <= 1'b0;
      end
      CsrPlugin_interrupt_valid <= 1'b0;
      if(_zz_180_)begin
        if(_zz_181_)begin
          CsrPlugin_interrupt_valid <= 1'b1;
        end
        if(_zz_182_)begin
          CsrPlugin_interrupt_valid <= 1'b1;
        end
        if(_zz_183_)begin
          CsrPlugin_interrupt_valid <= 1'b1;
        end
      end
      if(CsrPlugin_pipelineLiberator_active)begin
        if((! execute_arbitration_isStuck))begin
          CsrPlugin_pipelineLiberator_pcValids_0 <= 1'b1;
        end
        if((! memory_arbitration_isStuck))begin
          CsrPlugin_pipelineLiberator_pcValids_1 <= CsrPlugin_pipelineLiberator_pcValids_0;
        end
        if((! writeBack_arbitration_isStuck))begin
          CsrPlugin_pipelineLiberator_pcValids_2 <= CsrPlugin_pipelineLiberator_pcValids_1;
        end
      end
      if(((! CsrPlugin_pipelineLiberator_active) || decode_arbitration_removeIt))begin
        CsrPlugin_pipelineLiberator_pcValids_0 <= 1'b0;
        CsrPlugin_pipelineLiberator_pcValids_1 <= 1'b0;
        CsrPlugin_pipelineLiberator_pcValids_2 <= 1'b0;
      end
      if(CsrPlugin_interruptJump)begin
        CsrPlugin_interrupt_valid <= 1'b0;
      end
      CsrPlugin_hadException <= CsrPlugin_exception;
      if(_zz_169_)begin
        case(CsrPlugin_targetPrivilege)
          2'b11 : begin
            CsrPlugin_mstatus_MIE <= 1'b0;
            CsrPlugin_mstatus_MPIE <= CsrPlugin_mstatus_MIE;
            CsrPlugin_mstatus_MPP <= CsrPlugin_privilege;
          end
          default : begin
          end
        endcase
      end
      if(_zz_170_)begin
        case(_zz_171_)
          2'b11 : begin
            CsrPlugin_mstatus_MPP <= (2'b00);
            CsrPlugin_mstatus_MIE <= CsrPlugin_mstatus_MPIE;
            CsrPlugin_mstatus_MPIE <= 1'b1;
          end
          default : begin
          end
        endcase
      end
      execute_CsrPlugin_wfiWake <= (({_zz_139_,{_zz_138_,_zz_137_}} != (3'b000)) || CsrPlugin_thirdPartyWake);
      if((! writeBack_arbitration_isStuck))begin
        memory_to_writeBack_REGFILE_WRITE_DATA <= _zz_32_;
      end
      if((! writeBack_arbitration_isStuck))begin
        memory_to_writeBack_INSTRUCTION <= memory_INSTRUCTION;
      end
      if(((! execute_arbitration_isStuck) || execute_arbitration_removeIt))begin
        execute_arbitration_isValid <= 1'b0;
      end
      if(((! decode_arbitration_isStuck) && (! decode_arbitration_removeIt)))begin
        execute_arbitration_isValid <= decode_arbitration_isValid;
      end
      if(((! memory_arbitration_isStuck) || memory_arbitration_removeIt))begin
        memory_arbitration_isValid <= 1'b0;
      end
      if(((! execute_arbitration_isStuck) && (! execute_arbitration_removeIt)))begin
        memory_arbitration_isValid <= execute_arbitration_isValid;
      end
      if(((! writeBack_arbitration_isStuck) || writeBack_arbitration_removeIt))begin
        writeBack_arbitration_isValid <= 1'b0;
      end
      if(((! memory_arbitration_isStuck) && (! memory_arbitration_removeIt)))begin
        writeBack_arbitration_isValid <= memory_arbitration_isValid;
      end
      if(execute_CsrPlugin_csr_1984)begin
        if(execute_CsrPlugin_writeEnable)begin
          RegFilePlugin_shadow_clear <= _zz_235_[0];
          RegFilePlugin_shadow_read <= _zz_236_[0];
          RegFilePlugin_shadow_write <= _zz_237_[0];
        end
      end
      if(execute_CsrPlugin_csr_768)begin
        if(execute_CsrPlugin_writeEnable)begin
          CsrPlugin_mstatus_MPP <= execute_CsrPlugin_writeData[12 : 11];
          CsrPlugin_mstatus_MPIE <= _zz_238_[0];
          CsrPlugin_mstatus_MIE <= _zz_239_[0];
        end
      end
      if(execute_CsrPlugin_csr_772)begin
        if(execute_CsrPlugin_writeEnable)begin
          CsrPlugin_mie_MEIE <= _zz_241_[0];
          CsrPlugin_mie_MTIE <= _zz_242_[0];
          CsrPlugin_mie_MSIE <= _zz_243_[0];
        end
      end
      if(execute_CsrPlugin_csr_3008)begin
        if(execute_CsrPlugin_writeEnable)begin
          _zz_140_ <= execute_CsrPlugin_writeData[31 : 0];
        end
      end
      if(_zz_184_)begin
        dBus_cmd_halfPipe_regs_valid <= dBus_cmd_valid;
        dBus_cmd_halfPipe_regs_ready <= (! dBus_cmd_valid);
      end else begin
        dBus_cmd_halfPipe_regs_valid <= (! dBus_cmd_halfPipe_ready);
        dBus_cmd_halfPipe_regs_ready <= dBus_cmd_halfPipe_ready;
      end
    end
  end

  always @ (posedge clk) begin
    if(IBusCachedPlugin_iBusRsp_stages_1_output_ready)begin
      _zz_68_ <= IBusCachedPlugin_iBusRsp_stages_1_output_payload;
    end
    if(IBusCachedPlugin_iBusRsp_stages_1_input_ready)begin
      IBusCachedPlugin_s1_tightlyCoupledHit <= IBusCachedPlugin_s0_tightlyCoupledHit;
    end
    if(IBusCachedPlugin_iBusRsp_stages_2_input_ready)begin
      IBusCachedPlugin_s2_tightlyCoupledHit <= IBusCachedPlugin_s1_tightlyCoupledHit;
    end
    `ifndef SYNTHESIS
      `ifdef FORMAL
        assert((! (((dBus_rsp_ready && memory_MEMORY_ENABLE) && memory_arbitration_isValid) && memory_arbitration_isStuck)))
      `else
        if(!(! (((dBus_rsp_ready && memory_MEMORY_ENABLE) && memory_arbitration_isValid) && memory_arbitration_isStuck))) begin
          $display("FAILURE DBusSimplePlugin doesn't allow memory stage stall when read happend");
          $finish;
        end
      `endif
    `endif
    `ifndef SYNTHESIS
      `ifdef FORMAL
        assert((! (((writeBack_arbitration_isValid && writeBack_MEMORY_ENABLE) && (! writeBack_MEMORY_STORE)) && writeBack_arbitration_isStuck)))
      `else
        if(!(! (((writeBack_arbitration_isValid && writeBack_MEMORY_ENABLE) && (! writeBack_MEMORY_STORE)) && writeBack_arbitration_isStuck))) begin
          $display("FAILURE DBusSimplePlugin doesn't allow writeback stage stall when read happend");
          $finish;
        end
      `endif
    `endif
    _zz_113_ <= _zz_40_[11 : 7];
    _zz_114_ <= _zz_50_;
    CsrPlugin_mip_MEIP <= externalInterrupt;
    CsrPlugin_mip_MTIP <= timerInterrupt;
    CsrPlugin_mip_MSIP <= softwareInterrupt;
    CsrPlugin_mcycle <= (CsrPlugin_mcycle + 64'h0000000000000001);
    if(writeBack_arbitration_isFiring)begin
      CsrPlugin_minstret <= (CsrPlugin_minstret + 64'h0000000000000001);
    end
    if(CsrPlugin_selfException_valid)begin
      CsrPlugin_exceptionPortCtrl_exceptionContext_code <= CsrPlugin_selfException_payload_code;
      CsrPlugin_exceptionPortCtrl_exceptionContext_badAddr <= CsrPlugin_selfException_payload_badAddr;
    end
    if(DBusSimplePlugin_memoryExceptionPort_valid)begin
      CsrPlugin_exceptionPortCtrl_exceptionContext_code <= DBusSimplePlugin_memoryExceptionPort_payload_code;
      CsrPlugin_exceptionPortCtrl_exceptionContext_badAddr <= DBusSimplePlugin_memoryExceptionPort_payload_badAddr;
    end
    if(_zz_180_)begin
      if(_zz_181_)begin
        CsrPlugin_interrupt_code <= (4'b0111);
        CsrPlugin_interrupt_targetPrivilege <= (2'b11);
      end
      if(_zz_182_)begin
        CsrPlugin_interrupt_code <= (4'b0011);
        CsrPlugin_interrupt_targetPrivilege <= (2'b11);
      end
      if(_zz_183_)begin
        CsrPlugin_interrupt_code <= (4'b1011);
        CsrPlugin_interrupt_targetPrivilege <= (2'b11);
      end
    end
    if(_zz_169_)begin
      case(CsrPlugin_targetPrivilege)
        2'b11 : begin
          CsrPlugin_mcause_interrupt <= (! CsrPlugin_hadException);
          CsrPlugin_mcause_exceptionCode <= CsrPlugin_trapCause;
          CsrPlugin_mepc <= writeBack_PC;
          if(CsrPlugin_hadException)begin
            CsrPlugin_mtval <= CsrPlugin_exceptionPortCtrl_exceptionContext_badAddr;
          end
        end
        default : begin
        end
      endcase
    end
    externalInterruptArray_regNext <= externalInterruptArray;
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_REGFILE_WRITE_DATA <= _zz_31_;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_PC <= decode_PC;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_PC <= _zz_35_;
    end
    if(((! writeBack_arbitration_isStuck) && (! CsrPlugin_exceptionPortCtrl_exceptionValids_writeBack)))begin
      memory_to_writeBack_PC <= memory_PC;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_CSR_WRITE_OPCODE <= decode_CSR_WRITE_OPCODE;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_SRC2_CTRL <= _zz_25_;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_MMU_FAULT <= execute_MMU_FAULT;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_ALU_CTRL <= _zz_22_;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_SRC_USE_SUB_LESS <= decode_SRC_USE_SUB_LESS;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_BRANCH_CALC <= execute_BRANCH_CALC;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_BYPASSABLE_EXECUTE_STAGE <= decode_BYPASSABLE_EXECUTE_STAGE;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_BRANCH_DO <= execute_BRANCH_DO;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_INSTRUCTION <= decode_INSTRUCTION;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_INSTRUCTION <= execute_INSTRUCTION;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_MEMORY_ADDRESS_LOW <= execute_MEMORY_ADDRESS_LOW;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_MEMORY_ADDRESS_LOW <= memory_MEMORY_ADDRESS_LOW;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_REGFILE_WRITE_VALID <= decode_REGFILE_WRITE_VALID;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_REGFILE_WRITE_VALID <= execute_REGFILE_WRITE_VALID;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_REGFILE_WRITE_VALID <= memory_REGFILE_WRITE_VALID;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_BYPASSABLE_MEMORY_STAGE <= decode_BYPASSABLE_MEMORY_STAGE;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_BYPASSABLE_MEMORY_STAGE <= execute_BYPASSABLE_MEMORY_STAGE;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_CSR_READ_OPCODE <= decode_CSR_READ_OPCODE;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_SHIFT_RIGHT <= execute_SHIFT_RIGHT;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_SRC_LESS_UNSIGNED <= decode_SRC_LESS_UNSIGNED;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_MEMORY_STORE <= decode_MEMORY_STORE;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_MEMORY_STORE <= execute_MEMORY_STORE;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_MEMORY_STORE <= memory_MEMORY_STORE;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_ENV_CTRL <= _zz_19_;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_ENV_CTRL <= _zz_16_;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_ENV_CTRL <= _zz_14_;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_MEMORY_READ_DATA <= memory_MEMORY_READ_DATA;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_SHIFT_CTRL <= _zz_12_;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_SHIFT_CTRL <= _zz_9_;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_RS1 <= decode_RS1;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_SRC2_FORCE_ZERO <= decode_SRC2_FORCE_ZERO;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_RS2 <= decode_RS2;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_MEMORY_ENABLE <= decode_MEMORY_ENABLE;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_MEMORY_ENABLE <= execute_MEMORY_ENABLE;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_MEMORY_ENABLE <= memory_MEMORY_ENABLE;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_ALU_BITWISE_CTRL <= _zz_7_;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_IS_CSR <= decode_IS_CSR;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_SRC1_CTRL <= _zz_4_;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_MMU_RSP_physicalAddress <= execute_MMU_RSP_physicalAddress;
      execute_to_memory_MMU_RSP_isIoAccess <= execute_MMU_RSP_isIoAccess;
      execute_to_memory_MMU_RSP_allowRead <= execute_MMU_RSP_allowRead;
      execute_to_memory_MMU_RSP_allowWrite <= execute_MMU_RSP_allowWrite;
      execute_to_memory_MMU_RSP_allowExecute <= execute_MMU_RSP_allowExecute;
      execute_to_memory_MMU_RSP_exception <= execute_MMU_RSP_exception;
      execute_to_memory_MMU_RSP_refilling <= execute_MMU_RSP_refilling;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_PREDICTION_HAD_BRANCHED2 <= decode_PREDICTION_HAD_BRANCHED2;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_BRANCH_CTRL <= _zz_1_;
    end
    if((! execute_arbitration_isStuck))begin
      decode_to_execute_FORMAL_PC_NEXT <= _zz_54_;
    end
    if((! memory_arbitration_isStuck))begin
      execute_to_memory_FORMAL_PC_NEXT <= execute_FORMAL_PC_NEXT;
    end
    if((! writeBack_arbitration_isStuck))begin
      memory_to_writeBack_FORMAL_PC_NEXT <= _zz_53_;
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_1984 <= (decode_INSTRUCTION[31 : 20] == 12'h7c0);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_768 <= (decode_INSTRUCTION[31 : 20] == 12'h300);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_836 <= (decode_INSTRUCTION[31 : 20] == 12'h344);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_772 <= (decode_INSTRUCTION[31 : 20] == 12'h304);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_773 <= (decode_INSTRUCTION[31 : 20] == 12'h305);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_833 <= (decode_INSTRUCTION[31 : 20] == 12'h341);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_834 <= (decode_INSTRUCTION[31 : 20] == 12'h342);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_835 <= (decode_INSTRUCTION[31 : 20] == 12'h343);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_3008 <= (decode_INSTRUCTION[31 : 20] == 12'hbc0);
    end
    if((! execute_arbitration_isStuck))begin
      execute_CsrPlugin_csr_4032 <= (decode_INSTRUCTION[31 : 20] == 12'hfc0);
    end
    if(execute_CsrPlugin_csr_836)begin
      if(execute_CsrPlugin_writeEnable)begin
        CsrPlugin_mip_MSIP <= _zz_240_[0];
      end
    end
    if(execute_CsrPlugin_csr_773)begin
      if(execute_CsrPlugin_writeEnable)begin
        CsrPlugin_mtvec_base <= execute_CsrPlugin_writeData[31 : 2];
        CsrPlugin_mtvec_mode <= execute_CsrPlugin_writeData[1 : 0];
      end
    end
    if(execute_CsrPlugin_csr_833)begin
      if(execute_CsrPlugin_writeEnable)begin
        CsrPlugin_mepc <= execute_CsrPlugin_writeData[31 : 0];
      end
    end
    if(_zz_184_)begin
      dBus_cmd_halfPipe_regs_payload_wr <= dBus_cmd_payload_wr;
      dBus_cmd_halfPipe_regs_payload_address <= dBus_cmd_payload_address;
      dBus_cmd_halfPipe_regs_payload_data <= dBus_cmd_payload_data;
      dBus_cmd_halfPipe_regs_payload_size <= dBus_cmd_payload_size;
    end
  end


endmodule
