// OpenHPSDR downstream (PC->Card) protocol unpacker

module dsopenhpsdr1 (
  input               clk,
  input 			  reset,
  
  input        [ 7:0] ds_stream,
  input               ds_stream_valid,		

  output logic        run                  = 1'b0,
  output logic        wide_spectrum        = 1'b0,
  input               msec_pulse,
 
  output logic [ 5:0] ds_cmd_addr          = 6'h0,
  output logic [31:0] ds_cmd_data          = 32'h00,
  output logic        ds_cmd_cnt           = 1'b0,
  output logic        ds_cmd_resprqst      = 1'b0,
  output logic        ds_cmd_ptt           = 1'b0, 
  
  output       [ 7:0] dseth_tdata        ,
  output              dsethiq_tvalid     ,
  output              dsethiq_tlast      ,
  output              dsethiq_tuser      ,
  output              dsethlr_tvalid     ,
  output              dsethlr_tlast      ,
 
  input        [ 5:0] cmd_addr           ,
  input        [31:0] cmd_data           ,
  input               cmd_rqst
);


localparam START        = 'h00,
           PREAMBLE     = 'h01,
           DECODE       = 'h02,
           RUNSTOP      = 'h03,
           ENDPOINT     = 'h05,
           SEQNO3       = 'h06,
           SEQNO2       = 'h07,
           SEQNO1       = 'h08,
           SEQNO0       = 'h09,
           SYNC2        = 'h10,
           SYNC1        = 'h11,
           SYNC0        = 'h12,
           CMDCTRL      = 'h13,
           CMDDATA3     = 'h14,
           CMDDATA2     = 'h15,
           CMDDATA1     = 'h16,
           CMDDATA0     = 'h17,
           PUSHL1       = 'h18,
           PUSHL0       = 'h19,
           PUSHR1       = 'h1a,
           PUSHR0       = 'h1b,
           PUSHI1       = 'h1c,
           PUSHI0       = 'h1d,
           PUSHQ1       = 'h1e,
           PUSHQ0       = 'h1f;
		   
logic [5:0] state        = START;
logic [5:0] state_next          ;
logic [7:0] pushcnt      = 8'h00;
logic [7:0] pushcnt_next        ;

logic        run_next            ;
logic        wide_spectrum_next  ;
logic [ 5:0] ds_cmd_addr_next    ;
logic [31:0] ds_cmd_data_next    ;
logic        ds_cmd_cnt_next     ;
logic        ds_cmd_ptt_next     ;
logic        ds_cmd_resprqst_next;

logic        ds_cmd_rqst                  ;
logic        watchdog_clr                 ;
logic [11:0] watchdog_cnt         = 12'h00;
logic [ 8:0] msec_cnt                     ;
logic        msec_cnt_not_zero            ;
logic        cwx_pushiq           = 1'b0  ;
logic        cwx_pushiq_next              ;
logic [ 1:0] cwx_saved            = 2'b00 ;
logic [ 1:0] cwx_saved_next               ;
logic        cwx_enable           = 1'b0  ;


// State
always @(posedge clk) begin
  pushcnt         <= pushcnt_next;
  ds_cmd_resprqst <= ds_cmd_resprqst_next;
  ds_cmd_addr     <= ds_cmd_addr_next;
  ds_cmd_ptt      <= ds_cmd_ptt_next;
  ds_cmd_data     <= ds_cmd_data_next;
  ds_cmd_cnt      <= ds_cmd_cnt_next;
  cwx_pushiq      <= cwx_pushiq_next;
  cwx_saved       <= cwx_saved_next;

  if (reset) begin
    state         <= START;
    run           <= 1'b0;
    wide_spectrum <= 1'b0;
  
  end else if (ds_stream_valid) begin
    state         <= state_next;
    run           <= run_next;
    wide_spectrum <= wide_spectrum_next;
  end
end

// FSM Combinational
always @(*) begin
  // Next State
  state_next = START;
  run_next = run;
  wide_spectrum_next = wide_spectrum;
  pushcnt_next = pushcnt;
  ds_cmd_resprqst_next = ds_cmd_resprqst;
  ds_cmd_addr_next = ds_cmd_addr;
  ds_cmd_ptt_next = ds_cmd_ptt;
  ds_cmd_data_next = ds_cmd_data;
  ds_cmd_cnt_next = ds_cmd_cnt;

  cwx_pushiq_next = cwx_pushiq;
  cwx_saved_next = cwx_saved;

  // Combinational output
  dsethiq_tvalid = 1'b0;
  dsethlr_tvalid = 1'b0;
  dsethiq_tlast  = 1'b0;
  dsethiq_tuser  = 1'b0;
  dsethlr_tlast  = 1'b0;

  case (state)
    START: begin
	  pushcnt_next = 8'h00;
      if (ds_stream == 8'hef) begin  state_next = PREAMBLE;  end
    end

    PREAMBLE: begin
      if (ds_stream == 8'hfe) state_next = DECODE;
    end

    DECODE: begin
      if (ds_stream == 8'h01) state_next = ENDPOINT;
      else if (ds_stream == 8'h04) state_next = RUNSTOP;
      else if (ds_stream == 8'h05) state_next = SYNC0;
    end

    RUNSTOP: begin
      run_next = ds_stream[0];
      wide_spectrum_next = ds_stream[1];
	  state_next = START;
    end

    ENDPOINT: begin
      if (ds_stream == 8'h02) state_next = SEQNO3;
    end

    SEQNO3: begin
      state_next = SEQNO2;
    end

    SEQNO2: begin
      state_next = SEQNO1;
    end

    SEQNO1: begin
      state_next = SEQNO0;
    end

    SEQNO0: begin
      state_next = SYNC2;
    end

    SYNC2: begin
      if (ds_stream == 8'h7f) state_next = SYNC1;
    end

    SYNC1: begin
      if (ds_stream == 8'h7f) state_next = SYNC0;
    end

    SYNC0: begin   
      if (ds_stream == 8'h7f) state_next = CMDCTRL;
    end

    CMDCTRL: begin
      ds_cmd_resprqst_next = ds_stream[7];
      ds_cmd_addr_next = ds_stream[6:1];
      ds_cmd_ptt_next = ds_stream[0];
      state_next = CMDDATA3;
    end

    CMDDATA3: begin
      cwx_pushiq_next = ~ds_cmd_ptt & cwx_enable & msec_cnt_not_zero;
      ds_cmd_data_next = {ds_stream,ds_cmd_data[23:0]};
      state_next = CMDDATA2;
    end

    CMDDATA2: begin
      ds_cmd_data_next = {ds_cmd_data[31:24],ds_stream,ds_cmd_data[15:0]};
      state_next = CMDDATA1;
    end

    CMDDATA1: begin
      ds_cmd_data_next = {ds_cmd_data[31:16],ds_stream,ds_cmd_data[7:0]};
      state_next = CMDDATA0;
    end

    CMDDATA0: begin
      ds_cmd_data_next = {ds_cmd_data[31:8],ds_stream};
      ds_cmd_cnt_next = ~ds_cmd_cnt;
      state_next = PUSHL1;
    end

    PUSHL1: begin
      dsethlr_tvalid = 1'b1;
      state_next = PUSHL0;
    end

    PUSHL0: begin
      dsethlr_tvalid = 1'b1;
      state_next = PUSHR1;
    end

    PUSHR1: begin
      dsethlr_tvalid = 1'b1;
      state_next = PUSHR0;
    end

    PUSHR0: begin
      dsethlr_tvalid = 1'b1;
      dsethlr_tlast  = 1'b1;
      pushcnt_next = pushcnt + 6'h01;
      state_next = PUSHI1;
    end

    PUSHI1: begin
      dsethiq_tuser  = ds_cmd_ptt;
      dsethiq_tvalid = ds_cmd_ptt | cwx_pushiq;
      state_next = PUSHI0;
    end

    PUSHI0: begin
      dsethiq_tuser  = cwx_saved[0];
      dsethiq_tvalid = ds_cmd_ptt | cwx_pushiq;
      state_next = PUSHQ1;
      cwx_saved_next = {ds_stream[3],ds_stream[0]};
    end

    PUSHQ1: begin
      dsethiq_tuser = cwx_saved[1];
      dsethiq_tvalid = ds_cmd_ptt | cwx_pushiq;
      state_next = PUSHQ0;
    end

    PUSHQ0: begin
      dsethiq_tvalid = ds_cmd_ptt | cwx_pushiq;
      dsethiq_tlast  = 1'b1;
      cwx_pushiq_next = (~ds_cmd_ptt & cwx_enable) & (|cwx_saved | msec_cnt_not_zero);
      if (&pushcnt[5:0]) begin
        if (~pushcnt[6]) begin
          state_next = SYNC2;
        end 
      end else if (&pushcnt[6:1]) state_next = START; else state_next = PUSHL1;
    end

    default: begin
      state_next = START;
    end

  endcase
end

assign dseth_tdata = ds_stream;

// Only enable CWX when keyer is internal
always @(posedge clk) begin
	if (cmd_rqst) begin
		if (cmd_addr == 6'h0f) begin
		  cwx_enable <= cmd_data[24];
		end 
	end
end

assign msec_cnt_not_zero = |msec_cnt;

// CWX spacing hang
always @(posedge clk) begin
  if (ds_cmd_ptt | ~cwx_enable) msec_cnt <= 9'd0;
  else if (|cwx_saved) msec_cnt <= 9'd500;
  else if (msec_cnt_not_zero & msec_pulse) msec_cnt <= msec_cnt - 1;
end

endmodule
