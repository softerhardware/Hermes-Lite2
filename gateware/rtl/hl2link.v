`timescale 1ns/1ns

module hl2link (
  input               clk        ,
  input               rst        ,
  input        [ 1:0] linkrx     ,
  output logic [ 1:0] linktx     ,
  output logic        running    ,
  input               master_sel ,
  input               cl1on_ack  ,
  output              cl1on_rqst ,
  // Send interface
  input               send_tvalid,
  input        [37:0] send_tdata ,
  input        [ 1:0] send_tuser ,
  output logic        send_tready,
  output logic        send_tdone ,
  // Receive interface
  output logic        recv_tvalid,
  output logic [37:0] recv_tdata ,
  output logic [ 1:0] recv_tuser ,
  input               recv_tready,
  output logic        recv_tdone
);


logic [1:0] linkrx_int    = 2'b00;
logic [1:0] linkrx_int2   = 2'b00;
logic [1:0] linkrx_stable = 2'b00;


// Send FSM
localparam
  SEND_IDLE   = 4'b0000,
  SEND_WORK   = 4'b0001,
  SEND_SYNC1  = 4'b0111,
  SEND_SYNC2  = 4'b0110,
  SEND_MLINK0 = 4'b1010,
  SEND_MLINK1 = 4'b1001,
  SEND_MLINK2 = 4'b1011,
  SEND_MLINK3 = 4'b1000,
  SEND_SLINK0 = 4'b1100,
  SEND_SLINK1 = 4'b1101,
  SEND_SLINK2 = 4'b1110,
  SEND_SLINK3 = 4'b1111;


logic [ 3:0] send_state       = SEND_SLINK0;
logic [ 3:0] send_state_next               ;
logic [ 1:0] linktx_next      = 2'b00      ;
logic [ 4:0] send_cnt         = 5'h00      ;
logic [ 4:0] send_cnt_next                 ;
logic [37:0] rsend_tdata                   ;
logic [37:0] rsend_tdata_next              ;
logic        timer_pulse                   ;

always @(posedge clk) begin
  send_state  <= rst ? SEND_SLINK0 : send_state_next;
  linktx      <= linktx_next;
  rsend_tdata <= rsend_tdata_next;
  send_cnt    <= send_cnt_next;
end

assign timer_pulse = (send_cnt == 5'h00);

always @* begin
  send_state_next  = send_state;
  linktx_next      = 2'b00;
  rsend_tdata_next = rsend_tdata;
  send_cnt_next    = send_cnt - 5'h01;

  send_tready = 1'b0;
  send_tdone  = 1'b0;
  running     = 1'b1;
  cl1on_rqst  = 1'b0;

  case(send_state)
    SEND_IDLE : begin
      send_tready = 1'b1;
      if (send_tvalid & (send_tuser != 2'b00)) begin
        linktx_next      = send_tuser;
        rsend_tdata_next = send_tdata;
        if (send_tuser == 2'b01)      send_cnt_next = 5'h12; // Command word 38 bits
        else if (send_tuser == 2'b10) send_cnt_next = 5'h0c; // RX sample 2+24 bits
        else if (send_tuser == 2'b11) send_cnt_next = 5'h0f; // TX IQ sample 16+16 bits
        send_state_next = SEND_WORK;
      end
    end
    SEND_WORK : begin
      linktx_next      = rsend_tdata[37:36];
      send_cnt_next    = send_cnt - 5'h01;
      rsend_tdata_next = {rsend_tdata[35:0],2'bXX};
      if (timer_pulse) send_state_next = SEND_SYNC1;
    end
    // Wait so that send_tready will be synchronized with recv_tvalid in other HL2
    SEND_SYNC1 : begin
      send_state_next = SEND_SYNC2;
    end
    SEND_SYNC2 : begin
      send_tdone = 1'b1;
      send_state_next = SEND_IDLE;
    end

    // Link sequences
    SEND_MLINK0: begin
      running     = 1'b0;
      linktx_next = 2'b10;
      if (linkrx_stable == 2'b01 & timer_pulse) begin
        send_state_next = SEND_MLINK1;
      end
    end

    SEND_MLINK1: begin
      running     = 1'b0;
      linktx_next = 2'b01;
      case(linkrx_stable)
        2'b01 : begin
          if (timer_pulse) send_state_next = SEND_MLINK0;
        end
        2'b10 : begin
          if (timer_pulse) send_state_next = SEND_MLINK2;
        end
        default : send_state_next = SEND_MLINK0;
      endcase
    end

    SEND_MLINK2: begin
      running     = 1'b0;
      linktx_next = 2'b11;
      case(linkrx_stable)
        2'b10 : begin
          if (timer_pulse) send_state_next = SEND_MLINK0;
        end
        2'b11 : begin
          if (timer_pulse) send_state_next = SEND_MLINK3;
        end
        default : send_state_next = SEND_MLINK0;
      endcase
    end

    // If this far then assume connected, wait for slave to finish sync
    SEND_MLINK3: begin
      running     = 1'b0;
      linktx_next = 2'b00;
      if (linkrx_stable == 2'b00) begin
        send_state_next = SEND_IDLE;
      end
    end

    SEND_SLINK0: begin
      running     = 1'b0;
      if (master_sel) send_state_next = SEND_MLINK0;
      else if (linkrx_stable == 2'b10) send_state_next = SEND_SLINK1;
    end

    SEND_SLINK1: begin
      running     = 1'b0;
      linktx_next = 2'b01;
      if (master_sel) send_state_next = SEND_MLINK0;
      else
        case(linkrx_stable)
          2'b10 :   send_state_next = SEND_SLINK1;
          2'b01 :   send_state_next = SEND_SLINK2;
          default : send_state_next = SEND_SLINK0;
        endcase
    end

    SEND_SLINK2: begin
      running     = 1'b0;
      linktx_next = 2'b10;
      if (master_sel) send_state_next = SEND_MLINK0;
      else
        case(linkrx_stable)
          2'b01 :   send_state_next = SEND_SLINK2;
          2'b11 :   send_state_next = SEND_SLINK3;
          default : send_state_next = SEND_SLINK0;
        endcase
    end

    // Wait until clock is synced
    SEND_SLINK3: begin
      running     = 1'b0;
      cl1on_rqst  = 1'b1;
      linktx_next = 2'b11;
      if (master_sel) send_state_next = SEND_MLINK0;
      else if (cl1on_ack & (linkrx_stable == 2'b00)) send_state_next = SEND_IDLE;
    end

    default: send_state_next = SEND_SLINK0;

  endcase
end



// Receive FSM
localparam
  RECV_IDLE  = 1'b0,
  RECV_WORK  = 1'b1;

logic        recv_state      = RECV_IDLE;
logic        recv_state_next            ;
logic [37:0] recv_tdata_next            ;
logic [ 1:0] recv_tuser_next            ;
logic [ 4:0] recv_cnt        = 5'h00    ;
logic [ 4:0] recv_cnt_next              ;

always @(posedge clk) begin
  recv_state    <= running ? recv_state_next : RECV_IDLE;
  linkrx_int    <= linkrx;
  linkrx_int2   <= linkrx_int;
  linkrx_stable <= (linkrx_int2 == linkrx_int) ? linkrx_int2 : linkrx_stable;
  recv_tdata    <= recv_tdata_next;
  recv_tuser    <= recv_tuser_next;
  recv_cnt      <= recv_cnt_next;
end

always @* begin
  recv_state_next = recv_state;
  recv_tdata_next = recv_tdata;
  recv_tuser_next = recv_tuser;
  recv_cnt_next   = recv_cnt;

  recv_tvalid     = 1'b0;
  recv_tdone      = 1'b0;

  case(recv_state)
    RECV_IDLE: begin
      recv_tvalid = 1'b1;
      if (linkrx_int == 2'b01)      recv_cnt_next = 5'h12; // Command word 38 bits
      else if (linkrx_int == 2'b10) recv_cnt_next = 5'h0c; // RX sample 2+24 bits
      else if (linkrx_int == 2'b11) recv_cnt_next = 5'h0f; // TX IQ sample 16+16 bits

      if (linkrx_int != 2'b00) begin
        recv_tuser_next = linkrx_int;
        recv_state_next = RECV_WORK;
      end
    end
    RECV_WORK: begin
      recv_tdata_next = {recv_tdata[35:0],linkrx_int};
      recv_cnt_next   = recv_cnt - 5'h01;
      if (recv_cnt == 5'h00) begin
        recv_tdone = 1'b1;
        recv_state_next = RECV_IDLE;
      end
    end
  endcase
end

endmodule

