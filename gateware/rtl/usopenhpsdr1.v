
// OpenHPSDR upstream (Card->PC) protocol packer

module usopenhpsdr1 (
  input                         clk                 ,
  input                         have_ip             ,
  input                         run                 ,
  input                         wide_spectrum       ,
  input                         idhermeslite        ,
  input        [          47:0] mac                 ,
  input                         discover_port       ,
  input                         discover_rqst       ,
  input                         udp_tx_enable       ,
  output       [           1:0] udp_tx_request      ,
  output       [           7:0] udp_tx_data         ,
  output logic [          10:0] udp_tx_length         = 'd0,
  input        [          11:0] bs_tdata            ,
  output                        bs_tready           ,
  input                         bs_tvalid           ,
  input        [          23:0] us_tdata            ,
  input                         us_tlast            ,
  output                        us_tready           ,
  input                         us_tvalid           ,
  input        [TUSERWIDTH-1:0] us_tuser            ,
  input        [          10:0] us_tlength          ,
  // Command slave interface
  input        [           5:0] cmd_addr            ,
  input        [          31:0] cmd_data            ,
  input                         cmd_rqst            ,
  input        [          39:0] resp                ,
  output logic                  resp_rqst             = 1'b0,
  input                         stall_req           ,
  output                        stall_ack           ,
  input        [          31:0] static_ip           ,
  input        [          15:0] alt_mac             ,
  input        [           7:0] eeprom_config       ,
  output logic                  watchdog_up           = 1'b0,
  input                         ds_cmd_ptt          ,
  input                         ds_pkt              ,
  input                         ds_wait             ,
  input                         usethasmi_send_more ,
  input                         usethasmi_erase_done,
  output                        usethasmi_ack       ,
  input                         alt_resp_rqst       ,
  input        [          31:0] resp_data           ,
  input        [           7:0] resp_control        ,
  input        [          11:0] temperature         ,
  input        [          11:0] fwdpwr              ,
  input        [          11:0] revpwr              ,
  input        [          11:0] bias                ,
  input        [           7:0] dsiq_status         ,
  input                         master_link_running
);

parameter           NR = 8'h0;
parameter           VERSION_MAJOR = 8'h0;
parameter           VERSION_MINOR = 8'h0;
parameter           BOARD = 5;
parameter           BANDSCOPE_BITS = 2'b01; // See wiki protocol page
parameter           AK4951 = 0;
parameter           EXTENDED_DEBUG_RESP = 1;

localparam          TUSERWIDTH = (AK4951 == 1) ? 16 : 2;

localparam START        = 4'h0,
           WIDE1        = 4'h1,
           WIDE2        = 4'h2,
           WIDE3        = 4'h3,
           WIDE4        = 4'h4,
           DISCOVER1    = 4'h5,
           DISCOVER2    = 4'h6,
           UDP1         = 4'h7,
           UDP2         = 4'h8,
           SYNC_RESP    = 4'h9,
           RXDATA2      = 4'ha,
           RXDATA1      = 4'hb,
           RXDATA0      = 4'hc,
           MIC1         = 4'hd,
           MIC0         = 4'he,
           PAD          = 4'hf;

logic [ 3:0] state              = START                  ;
logic [ 3:0] state_next                                  ;
logic [10:0] byte_no            = 11'h00                 ;
logic [10:0] byte_no_next                                ;
logic [ 5:0] dbyte_no           = 6'h0                   ;
logic [ 5:0] dbyte_no_next                               ;
logic [10:0] udp_tx_length_next                          ;
logic [19:0] ep6_seq_no         = 20'h0                  ;
logic [19:0] ep6_seq_no_next                             ;
logic [19:0] ep4_seq_no         = 20'h0                  ;
logic [19:0] ep4_seq_no_next                             ;
logic [ 7:0] discover_data      = 'd0, discover_data_next;
logic [ 7:0] wide_data          = 'd0, wide_data_next    ;
logic [ 7:0] udp_data           = 'd0, udp_data_next     ;
// Allow for at least 12 receivers in a round of sample data
logic [           6:0] round_bytes      = 7'h00, round_bytes_next;
logic [           6:0] bs_cnt           = 7'h1, bs_cnt_next      ;
logic [           6:0] set_bs_cnt       = 7'h1                   ;
logic                  resp_rqst_next                            ;
logic                  watchdog_up_next                          ;
logic                  vna              = 1'b0                   ;
logic [TUSERWIDTH-1:0] vna_mic          = 0, vna_mic_next        ;
logic [           7:0] vna_mic_msb, vna_mic_lsb;
logic [           1:0] discover_state                            ;
logic                  discover_rst                              ;

logic [6:0] tx_buffer_latency = 7'h0a ; // Default to 10ms
logic [4:0] ptt_hang_time     = 5'h04 ; // Default to 4 ms
logic [9:0] cw_hang_time      = 10'h00;
logic [7:0] pkt_cnt           = 8'h00 ;
logic [1:0] sample_rate       = 2'h0  ;
logic [3:0] receivers         = 4'h0  ;
logic       force_discover            ;
logic       force_discover_en = 1'b0  ;
logic       cmd_ptt           = 1'b0  ;
logic       tx_wait           = 1'b0  ;


generate
if (AK4951 == 1) begin
  assign vna_mic_msb = vna_mic[15:8];
  assign vna_mic_lsb = vna ? {7'h00,vna_mic[0]} : vna_mic[7:0];
end else begin
  assign vna_mic_msb = 8'h00;
  assign vna_mic_lsb = vna ? {7'h00,vna_mic[0]} : 8'h00;
end
endgenerate


// Command Slave State Machine
always @(posedge clk) begin
  if (cmd_rqst) begin
    case (cmd_addr)
      6'h00: begin
        // Shift no of receivers by speed
        set_bs_cnt <= ((cmd_data[7:3] + 1'b1) << cmd_data[25:24]);
      end

      6'h09: begin
        vna <= cmd_data[23];
      end
    endcase
  end

  if (discover_rqst & ~discover_state[1]) discover_state <= {1'b1,discover_port};
  else if (alt_resp_rqst & ~discover_state[1]) discover_state <= 2'b11;
  else if (force_discover) discover_state <= 2'b11;
  else if (discover_rst) discover_state <= 2'b00;

end


// State
always @ (posedge clk) begin
  state <= state_next;

  byte_no <= byte_no_next;
  dbyte_no <= dbyte_no_next;
  discover_data <= discover_data_next;
  wide_data <= wide_data_next;
  udp_data <= udp_data_next;

  udp_tx_length <= udp_tx_length_next;

  bs_cnt <= bs_cnt_next;

  round_bytes <= round_bytes_next;

  resp_rqst <= resp_rqst_next;

  watchdog_up <= watchdog_up_next;

  vna_mic <= vna_mic_next;

  if (~run) begin
    ep6_seq_no <= 20'h0;
    ep4_seq_no <= 20'h0;
  end else begin
    ep6_seq_no <= ep6_seq_no_next;
    // Synchronize sequence number lower 2 bits as some software may require this
    ep4_seq_no <= (bs_tvalid) ? ep4_seq_no_next : {ep4_seq_no_next[19:2],2'b00};
  end
end


// FSM Combinational
always @* begin

  // Next State
  state_next = state;

  byte_no_next = byte_no;
  dbyte_no_next = dbyte_no;
  discover_data_next = discover_data;
  wide_data_next = wide_data;
  udp_data_next = udp_data;

  udp_tx_length_next = udp_tx_length;

  round_bytes_next = round_bytes;

  ep6_seq_no_next = ep6_seq_no;
  ep4_seq_no_next = ep4_seq_no;

  bs_cnt_next = bs_cnt;

  resp_rqst_next = resp_rqst;

  watchdog_up_next = watchdog_up;

  vna_mic_next = vna_mic;

  // Combinational
  udp_tx_data = udp_data;
  udp_tx_request = 2'b00;
  us_tready = 1'b0;
  bs_tready = 1'b0;

  usethasmi_ack = 1'b0;

  stall_ack = 1'b0;

  discover_rst = 1'b0;
  force_discover = 1'b0;

  case (state)
    START: begin

      if (stall_req) begin
        stall_ack = 1'b1;
        ep6_seq_no_next = 20'h0;

      end else if (discover_state[1] | usethasmi_erase_done | usethasmi_send_more) begin
        udp_tx_length_next = 'h3c;
        state_next = DISCOVER1;

      end else if ((us_tlength > 11'd333) & us_tvalid & have_ip & run) begin // wait until there is enough data in fifo
        udp_tx_length_next = 'd1032;
        state_next = UDP1;

      end else if (bs_tvalid & ~(|bs_cnt)) begin
        bs_cnt_next = set_bs_cnt; // Set count until next wide data
        watchdog_up_next = ~watchdog_up;
        udp_tx_length_next = 'd1032;
        if (wide_spectrum) state_next = WIDE1;
      end
    end

    DISCOVER1: begin
      dbyte_no_next = 'h3a;
      udp_tx_data = discover_data;
      udp_tx_request = (usethasmi_erase_done | usethasmi_send_more) ? 2'b10 : discover_state;
      discover_data_next = 8'hef;
      if (udp_tx_enable) begin
        discover_rst = 1'b1;
        state_next = DISCOVER2;
      end
    end // DISCOVER1:

    DISCOVER2: begin
      dbyte_no_next = dbyte_no - 6'd1;
      udp_tx_data = discover_data;
      case (dbyte_no)
        6'h3a: discover_data_next = 8'hfe;
        6'h39: discover_data_next = usethasmi_erase_done ? 8'h03 : (usethasmi_send_more ? 8'h04 : (run ? 8'h03 : 8'h02));
        6'h38: discover_data_next = mac[47:40];
        6'h37: discover_data_next = mac[39:32];
        6'h36: discover_data_next = mac[31:24];
        6'h35: discover_data_next = mac[23:16];
        6'h34: discover_data_next = mac[15:8];
        6'h33: discover_data_next = mac[7:0];
        6'h32: discover_data_next = VERSION_MAJOR;
        6'h31: discover_data_next = idhermeslite ? 8'h06 : 8'h01;
        // FIXME: Really needed for CW skimmer? Why so much?
        6'h30: discover_data_next = {eeprom_config[7:5],5'b0000};
        6'h2f: discover_data_next = 8'h00;
        6'h2e: discover_data_next = static_ip[31:24];
        6'h2d: discover_data_next = static_ip[23:16];
        6'h2c: discover_data_next = static_ip[15:8];
        6'h2b: discover_data_next = static_ip[7:0];
        6'h2a: discover_data_next = alt_mac[15:8];
        6'h29: discover_data_next = alt_mac[7:0];
        6'h28: discover_data_next = master_link_running ? {NR[6:0],1'b0} : NR;
        6'h27: discover_data_next = {BANDSCOPE_BITS, BOARD[5:0]};
        6'h26: discover_data_next = VERSION_MINOR;
        // Additions mainly for port 1025 communication
        6'h24: discover_data_next = resp_data[31:24];
        6'h23: discover_data_next = resp_data[23:16];
        6'h22: discover_data_next = resp_data[15:8];
        6'h21: discover_data_next = resp_data[7:0];
        6'h20: discover_data_next = resp_control;
        6'h1f: discover_data_next = {4'h0,temperature[11:8]};
        6'h1e: discover_data_next = temperature[7:0];
        6'h1d: discover_data_next = {4'h0,fwdpwr[11:8]};
        6'h1c: discover_data_next = fwdpwr[7:0];
        6'h1b: discover_data_next = {4'h0,revpwr[11:8]};
        6'h1a: discover_data_next = revpwr[7:0];
        6'h19: discover_data_next = {4'h0,bias[11:8]};
        6'h18: discover_data_next = bias[7:0];
        6'h17: discover_data_next = dsiq_status;
        6'h16: discover_data_next = pkt_cnt;
        6'h15: discover_data_next = {1'b0,tx_buffer_latency};
        6'h14: discover_data_next = cw_hang_time[7:0];
        6'h13: discover_data_next = {cw_hang_time[9:8],1'b0,ptt_hang_time};
        6'h12: discover_data_next = {sample_rate,cmd_ptt,tx_wait,receivers};

        6'h00: begin
          discover_data_next = 8'h00;
          if (usethasmi_erase_done | usethasmi_send_more) dbyte_no_next = 6'h00;
          else state_next = START;
        end
        default: begin
          discover_data_next = 8'h00;
        end
      endcase

      // Always acknowledge
      usethasmi_ack = dbyte_no <= 6'h38;
    end

    // start sending UDP/IP data
    WIDE1: begin
      byte_no_next = 'h406;
      udp_tx_data = wide_data;
      udp_tx_request = 2'b10;
      wide_data_next = 8'hef;
      if (udp_tx_enable) state_next = WIDE2;
    end

    WIDE2: begin
      byte_no_next = byte_no - 11'd1;
      udp_tx_data = wide_data;
      case (byte_no[2:0])
        3'h6: wide_data_next = 8'hfe;
        3'h5: wide_data_next = 8'h01;
        3'h4: wide_data_next = 8'h04;
        3'h3: wide_data_next = 8'h00; //ep4_seq_no[31:24];
        3'h2: wide_data_next = {4'h0,ep4_seq_no[19:16]};
        3'h1: wide_data_next = ep4_seq_no[15:8];
        3'h0: begin
          wide_data_next = ep4_seq_no[7:0];
          ep4_seq_no_next = ep4_seq_no + 'h1;
          state_next = WIDE3;
        end
        default: wide_data_next = 8'hxx;
      endcase
    end

    WIDE3: begin
      byte_no_next = byte_no - 11'd1;
      udp_tx_data = wide_data;
      wide_data_next = { bs_tdata[3:0],4'b0000 };

      // Allow for one extra to keep udp_tx_data mux stable
      state_next = (&byte_no) ? START : WIDE4;
    end

    WIDE4: begin
      byte_no_next = byte_no - 11'd1;
      udp_tx_data = wide_data;
      wide_data_next = bs_tdata[11:4];
      bs_tready = 1'b1; // Pop data

      // Escape if something goes wrong
      state_next = (&byte_no) ? START : WIDE3;
    end

    UDP1: begin
      byte_no_next = 'h406;
      udp_tx_request = 2'b10;
      udp_data_next = 8'hef;
      force_discover = force_discover_en;
      if (udp_tx_enable) state_next = UDP2;
    end

    UDP2: begin
      byte_no_next = byte_no - 11'd1;
      case (byte_no[2:0])
        3'h6: udp_data_next = 8'hfe;
        3'h5: udp_data_next = 8'h01;
        3'h4: udp_data_next = 8'h06;
        3'h3: udp_data_next = 8'h00; //ep6_seq_no[31:24];
        3'h2: udp_data_next = {4'h00,ep6_seq_no[19:16]};
        3'h1: udp_data_next = ep6_seq_no[15:8];
        3'h0: begin
          udp_data_next = ep6_seq_no[7:0];
          ep6_seq_no_next = ep6_seq_no + 'h1;
          bs_cnt_next = bs_cnt - 7'd1;
          state_next = SYNC_RESP;
        end
        default: udp_data_next = 8'hxx;
      endcase // byte_no
    end // UDP2:

    SYNC_RESP: begin
      byte_no_next = byte_no - 11'd1;
      round_bytes_next = 'd0;
      case (byte_no[8:0])
        9'h1ff: udp_data_next = 8'h7f;
        9'h1fe: udp_data_next = 8'h7f;
        9'h1fd: udp_data_next = 8'h7f;
        9'h1fc: udp_data_next = resp[39:32];
        9'h1fb: udp_data_next = resp[31:24];
        9'h1fa: udp_data_next = resp[23:16];
        9'h1f9: udp_data_next = resp[15:8];
        9'h1f8: begin
          udp_data_next = resp[7:0];
          resp_rqst_next = ~resp_rqst;
          state_next = RXDATA2;
        end
        default: udp_data_next = 8'hxx;
      endcase
    end

    RXDATA2: begin
      byte_no_next = byte_no - 11'd1;
      round_bytes_next = round_bytes + 7'd1;
      udp_data_next = us_tdata[23:16];

      vna_mic_next = us_tuser; // Save mic bit for use later with mic data

      if (|byte_no[8:0]) begin
        state_next = RXDATA1;
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    RXDATA1: begin
      byte_no_next = byte_no - 11'd1;
      round_bytes_next = round_bytes + 7'd1;
      udp_data_next = us_tdata[15:8];

      if (|byte_no[8:0]) begin
        state_next = RXDATA0;
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    RXDATA0: begin
      byte_no_next = byte_no - 11'd1;
      round_bytes_next = round_bytes + 7'd1;
      udp_data_next = us_tdata[7:0];
      us_tready = 1'b1; // Pop next word

      if (|byte_no[8:0]) begin
        if (us_tlast) begin
          state_next = MIC1;
        end else begin
          state_next = RXDATA2;
        end
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    MIC1: begin
      byte_no_next = byte_no - 11'd1;
      round_bytes_next = round_bytes + 7'd1;
      udp_data_next = vna_mic_msb;

      if (|byte_no[8:0]) begin
        state_next = MIC0;
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    MIC0: begin
      byte_no_next = byte_no - 11'd1;
      round_bytes_next = 'd0;
      udp_data_next = vna_mic_lsb;

      if (|byte_no[8:0]) begin
        // Enough room for another round of data?
        state_next = (byte_no[8:0] > round_bytes) ? RXDATA2 : PAD;
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    PAD: begin
      byte_no_next = byte_no - 11'd1;
      udp_data_next = 8'h00;

      if (~(|byte_no[8:0])) begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    default: state_next = START;

  endcase // state
end // always @*



generate if (EXTENDED_DEBUG_RESP==1) begin

  always @(posedge clk) begin
    if (cmd_rqst) begin
      if (cmd_addr == 6'h00) begin
        sample_rate <= cmd_data[25:24];
        receivers <= cmd_data[6:3];
      end else if (cmd_addr == 6'h10) begin
        cw_hang_time <= {cmd_data[31:24], cmd_data[17:16]};
      end else if (cmd_addr == 6'h17) begin
        tx_buffer_latency <= cmd_data[6:0];
        ptt_hang_time <= cmd_data[12:8];
      end else if ((cmd_addr == 6'h39) & (cmd_data[27])) begin
        if (cmd_data[26:24] == 3'h3) force_discover_en <= 1'b1;
        else if (cmd_data[26:24] == 3'h2) force_discover_en <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    cmd_ptt <= ds_cmd_ptt;
    tx_wait <= ds_wait;
    if (ds_pkt) pkt_cnt <= pkt_cnt + 8'h01;
  end

end else begin

  assign tx_wait           = 1'b0;
  assign cmd_ptt           = 1'b0;
  assign cw_hang_time      = 10'h00;
  assign ptt_hang_time     = 5'h00;
  assign tx_buffer_latency = 7'h00;
  assign pkt_cnt           = 8'h00;
  assign receivers         = 4'h0;
  assign sample_rate       = 2'h0;

end
endgenerate


endmodule
