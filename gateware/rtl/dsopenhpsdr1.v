// OpenHPSDR downstream (PC->Card) protocol unpacker

module dsopenhpsdr1 (
  input               clk                ,
  input        [15:0] eth_port           ,
  input               eth_broadcast      ,
  input               eth_valid          ,
  input        [ 7:0] eth_data           ,
  input               eth_unreachable    ,
  output logic        discover_port        = 1'b0,
  output logic        discover_cnt         = 1'b0,
  output logic        run                  = 1'b0,
  output logic        wide_spectrum        = 1'b0,
  input               watchdog_up        ,
  input               msec_pulse         ,
  output logic [ 5:0] ds_cmd_addr          = 6'h0,
  output logic [31:0] ds_cmd_data          = 32'h00,
  output logic        ds_cmd_cnt           = 1'b0,
  output logic        ds_cmd_resprqst      = 1'b0,
  output logic        ds_cmd_is_alt        = 1'b0,
  output logic [ 1:0] ds_cmd_mask          = 2'b11,
  output logic        ds_cmd_ptt           = 1'b0,
  output       [ 7:0] dseth_tdata        ,
  output              dsethiq_tvalid     ,
  output              dsethiq_tlast      ,
  output              dsethiq_tuser      ,
  output              dsethlr_tvalid     ,
  output              dsethlr_tlast      ,
  //output              dsethlr_tuser,
  output              dsethasmi_tvalid   ,
  output              dsethasmi_tlast    ,
  output logic [13:0] asmi_cnt             = 14'h000,
  output              dsethasmi_erase    ,
  input               dsethasmi_erase_ack,
  output logic        ds_pkt_cnt         ,
  input        [ 5:0] cmd_addr           ,
  input        [31:0] cmd_data           ,
  input               cmd_rqst
);


localparam START        = 'h00,
           PREAMBLE     = 'h01,
           DECODE       = 'h02,
           RUNSTOP      = 'h03,
           DISCOVERY    = 'h04,
           ENDPOINT     = 'h05,
           SEQNO3       = 'h06,
           SEQNO2       = 'h07,
           SEQNO1       = 'h08,
           SEQNO0       = 'h09,
           ASMI_DECODE  = 'h2a,
           ASMI_CNT3    = 'h2b,
           ASMI_CNT2    = 'h2c,
           ASMI_CNT1    = 'h2d,
           ASMI_CNT0    = 'h2e,
           ASMI_PROGRAM = 'h2f,
           ASMI_ERASE   = 'h20,
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
//logic           framecnt = 1'b0;
//logic           framecnt_next;
logic        run_next            ;
logic        wide_spectrum_next  ;
logic [ 5:0] ds_cmd_addr_next    ;
logic [31:0] ds_cmd_data_next    ;
logic        ds_cmd_cnt_next     ;
logic        ds_cmd_ptt_next     ;
logic        ds_cmd_resprqst_next;
logic        ds_cmd_is_alt_next  ;
logic [ 1:0] ds_cmd_mask_next     = 2'b11 ;

logic        ds_cmd_rqst                  ;
logic        ds_pkt_cnt_next              ;
logic        watchdog_clr                 ;
logic [11:0] watchdog_cnt         = 12'h00;
logic [13:0] asmi_cnt_next                ;
logic [ 8:0] msec_cnt                     ;
logic        msec_cnt_not_zero            ;
logic        cwx_pushiq           = 1'b0  ;
logic        cwx_pushiq_next              ;
logic [ 1:0] cwx_saved            = 2'b00 ;
logic [ 1:0] cwx_saved_next               ;
logic        cwx_enable           = 1'b0  ;

logic        discover_port_next;
logic        discover_cnt_next;

logic watchdog_disable = 1'b0;
logic runstop_watchdog_valid = 1'b0;

// State
always @(posedge clk) begin
  pushcnt         <= pushcnt_next;
  ds_cmd_resprqst <= ds_cmd_resprqst_next;
  ds_cmd_addr     <= ds_cmd_addr_next;
  ds_cmd_ptt      <= ds_cmd_ptt_next;
  ds_cmd_data     <= ds_cmd_data_next;
  ds_cmd_cnt      <= ds_cmd_cnt_next;
  ds_cmd_is_alt   <= ds_cmd_is_alt_next;
  ds_cmd_mask     <= ds_cmd_mask_next;
  discover_port   <= discover_port_next;
  discover_cnt    <= discover_cnt_next;
  asmi_cnt        <= asmi_cnt_next;
  cwx_pushiq      <= cwx_pushiq_next;
  cwx_saved       <= cwx_saved_next;
  ds_pkt_cnt      <= ds_pkt_cnt_next;

  if ((eth_unreachable) | &watchdog_cnt) begin
    state         <= START;
    run           <= 1'b0;
    wide_spectrum <= 1'b0;
  end else if (~eth_valid) begin
    state <= START;
  end else begin
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
  //framecnt_next = framecnt;
  ds_cmd_resprqst_next = ds_cmd_resprqst;
  ds_cmd_addr_next = ds_cmd_addr;
  ds_cmd_ptt_next = ds_cmd_ptt;
  ds_cmd_data_next = ds_cmd_data;
  ds_cmd_cnt_next = ds_cmd_cnt;
  ds_cmd_is_alt_next = ds_cmd_is_alt;
  ds_cmd_mask_next = ds_cmd_mask;
  asmi_cnt_next = asmi_cnt;
  cwx_pushiq_next = cwx_pushiq;
  cwx_saved_next = cwx_saved;
  ds_pkt_cnt_next = ds_pkt_cnt;

  discover_port_next = discover_port;
  discover_cnt_next = discover_cnt;

  // Combinational output
  dsethiq_tvalid = 1'b0;
  dsethlr_tvalid = 1'b0;
  watchdog_clr   = 1'b0;
  dsethiq_tlast  = 1'b0;
  dsethiq_tuser  = 1'b0;
  dsethlr_tlast  = 1'b0;
  //dsethlr_tuser  = 1'b0;

  dsethasmi_tvalid = 1'b0;
  dsethasmi_tlast  = 1'b0;
  dsethasmi_erase  = 1'b0;

  runstop_watchdog_valid = 1'b0;

  case (state)
    START: begin
      //framecnt_next = 1'b0;
      if ((eth_data == 8'hef) & (eth_port[15:1] == 512)) state_next = PREAMBLE;
    end

    PREAMBLE: begin
      if ((eth_data == 8'hfe) & (eth_port[15:1] == 512)) state_next = DECODE;
    end

    DECODE: begin
      if (eth_data == 8'h01) state_next = ENDPOINT;
      else if (eth_data == 8'h04) state_next = RUNSTOP;
      else if (eth_data == 8'h02) state_next = DISCOVERY;
      else if (eth_data == 8'h03) state_next = ASMI_DECODE;
      else if ((eth_data == 8'h05) & eth_port[0] & ~eth_broadcast) state_next = SYNC0;
    end

    RUNSTOP: begin
      run_next = eth_data[0];
      wide_spectrum_next = eth_data[1];
      runstop_watchdog_valid = 1'b1;
    end

    DISCOVERY: begin
      discover_port_next = eth_port[0];
      discover_cnt_next  = ~discover_cnt;
    end

    ASMI_DECODE: begin
      pushcnt_next = 8'h00;
      if (eth_data == 8'h01) state_next = ASMI_CNT3;
      else if (eth_data == 8'h02) begin
        dsethasmi_erase = 1'b1;
        state_next = ASMI_ERASE;
      end
    end

    ASMI_CNT3: begin
      state_next = ASMI_CNT2;
    end

    ASMI_CNT2: begin
      state_next = ASMI_CNT1;
    end

    ASMI_CNT1: begin
      state_next = ASMI_CNT0;
      asmi_cnt_next = {eth_data[5:0],asmi_cnt[7:0]};
    end

    ASMI_CNT0: begin
      state_next = ASMI_PROGRAM;
      asmi_cnt_next = {asmi_cnt[13:8],eth_data};
    end

    ASMI_PROGRAM: begin
      dsethasmi_tvalid = 1'b1;
      pushcnt_next = pushcnt + 8'h01;
      if (&pushcnt) begin
        dsethasmi_tlast = 1'b1;
      end else begin
        state_next = ASMI_PROGRAM;
      end
    end

    ASMI_ERASE: begin
      dsethasmi_erase = 1'b1;
      if (~dsethasmi_erase_ack) state_next = ASMI_ERASE;
    end

    ENDPOINT: begin
      // FIXME: Can use end point for other information
      if (eth_data == 8'h02) state_next = SEQNO3;
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
      // Decrement watchdog on begin of data packet
      watchdog_clr = 1'b1;
      // Count packets received
      ds_pkt_cnt_next = ~ds_pkt_cnt;
      state_next = SYNC2;
    end

    SYNC2: begin
      pushcnt_next = 6'h00;
      if (eth_data == 8'h7f) state_next = SYNC1;
    end

    SYNC1: begin
      pushcnt_next = 6'h00;
      if (eth_data == 8'h7f) state_next = SYNC0;
    end

    SYNC0: begin
      pushcnt_next = 6'h00;
      if (eth_data[7:2] == 6'h1f) state_next = CMDCTRL;
      ds_cmd_mask_next = eth_data[1:0];
    end

    CMDCTRL: begin
      ds_cmd_resprqst_next = eth_data[7];
      ds_cmd_addr_next = eth_data[6:1];
      ds_cmd_ptt_next = eth_data[0];
      state_next = CMDDATA3;
    end

    CMDDATA3: begin
      cwx_pushiq_next = ~ds_cmd_ptt & cwx_enable & msec_cnt_not_zero;
      ds_cmd_data_next = {eth_data,ds_cmd_data[23:0]};
      state_next = CMDDATA2;
    end

    CMDDATA2: begin
      ds_cmd_data_next = {ds_cmd_data[31:24],eth_data,ds_cmd_data[15:0]};
      state_next = CMDDATA1;
    end

    CMDDATA1: begin
      ds_cmd_data_next = {ds_cmd_data[31:16],eth_data,ds_cmd_data[7:0]};
      state_next = CMDDATA0;
    end

    CMDDATA0: begin
      ds_cmd_data_next = {ds_cmd_data[31:8],eth_data};
      ds_cmd_is_alt_next = eth_port[0];
      ds_cmd_cnt_next = ~ds_cmd_cnt;
      if (eth_port[0]) begin
        state_next = START;
      end else begin
        state_next = PUSHL1;
      end
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
      cwx_saved_next = {eth_data[3],eth_data[0]};
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
          //framecnt_next = 1'b1;
          state_next = SYNC2;
        end
      end else state_next = PUSHL1;
    end

    default: begin
      state_next = START;
    end

  endcase
end

assign dseth_tdata = eth_data;

// Only enable CWX when keyer is internal
always @(posedge clk) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h0f) begin
      cwx_enable <= cmd_data[24];
    end else if ((cmd_addr == 6'h39) & (cmd_data[27])) begin
      if (cmd_data[26:24] == 3'h1) watchdog_disable <= 1'b1;
      else if (cmd_data[26:24] == 3'h0) watchdog_disable <= 1'b0;      
    end
  end else if (runstop_watchdog_valid) begin
    watchdog_disable <= eth_data[7]; // Bit 7 can be used to disable watchdog
  end
end



// Watch dog logic, stop if sending too much
// without receiving packets
always @(posedge clk) begin
  if (~run | watchdog_clr | watchdog_disable) begin
    watchdog_cnt <= 12'h00;
  end else if (watchdog_up) begin
    watchdog_cnt <= watchdog_cnt + 12'h01;
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
