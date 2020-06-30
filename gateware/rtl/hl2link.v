
module hl2link (
  input               clk      ,
  input        [ 1:0] linkrx   ,
  output logic [ 1:0] linktx   ,
  output              stall_req,
  input               stall_ack,
  output logic        rst_all  ,
  output logic        rst_nco  ,
  input        [ 5:0] cmd_addr ,
  input        [31:0] cmd_data ,
  input               cmd_rqst
);

logic enable_sync = 1'b0;

logic send_tvalid;
logic send_tready;
logic [3:0] send_tdata;

logic recv_tvalid;
logic recv_tready;
logic [3:0] recv_tdata;

logic mst_rst_all, slv_rst_all;
logic mst_rst_nco, slv_rst_nco;
logic rst_all_p1, rst_nco_p1;

// 4-bit command words
localparam
  CMD_STALL_REQ  = 4'b0001,
  CMD_STALL_ACK  = 4'b0010,
  CMD_STALL_RLS  = 4'b0011,
  CMD_RST_ALL    = 4'b0100,
  CMD_RST_NCO    = 4'b0101;


always @(posedge clk) begin
  if (cmd_rqst & cmd_addr == 6'h39) begin
    enable_sync <= cmd_data[31];
  end
  rst_all_p1 <= mst_rst_all | slv_rst_all;
  rst_nco_p1 <= mst_rst_nco | slv_rst_nco;
  rst_all <= rst_all_p1;
  rst_nco <= rst_nco_p1;
end


// Master protocol FSM
localparam
  MST_IDLE     = 3'b000,
  MST_RST_NCO  = 3'b001,
  MST_REQ_ALL1 = 3'b010,
  MST_REQ_ALL2 = 3'b110,
  MST_REQ_ALL3 = 3'b100,
  MST_ACK_ALL1 = 3'b011,
  MST_ACK_ALL2 = 3'b111,
  MST_ACK_ALL3 = 3'b101;

logic [2:0] mst_state       = MST_IDLE;
logic [2:0] mst_state_next            ;
logic [3:0] send_tdata_next           ;

always @(posedge clk) begin
  mst_state <= enable_sync ? mst_state_next : MST_IDLE;
  send_tdata <= send_tdata_next;
end

always @* begin
  mst_state_next = mst_state;
  send_tdata_next = send_tdata;
  send_tvalid = 1'b0;
  mst_rst_nco = 1'b0;
  mst_rst_all = 1'b0;
  stall_req = 1'b0;

  case(mst_state)
    MST_IDLE: begin
      if (cmd_rqst & cmd_addr == 6'h39) begin
        if (cmd_data[25:24] == 2'b01) begin
          send_tvalid = 1'b1;
          send_tdata_next = CMD_RST_NCO;
          mst_state_next = MST_RST_NCO;
        end if (cmd_data[25:24] == 2'b10) begin
          send_tvalid = 1'b1;
          send_tdata_next = CMD_STALL_REQ;
          mst_state_next = MST_REQ_ALL1;
        end
      end if (recv_tvalid & recv_tdata == CMD_STALL_REQ) begin
        mst_state_next = MST_ACK_ALL1;
      end
    end

    MST_RST_NCO : begin
      if (send_tready) begin
        mst_rst_nco = 1'b1;
        mst_state_next = MST_IDLE;
      end
    end

    MST_REQ_ALL1 : begin
      stall_req = 1'b1;
      if (recv_tvalid & recv_tdata == CMD_STALL_ACK & stall_ack) begin
        if (send_tready) begin
          send_tvalid = 1'b1;
          send_tdata_next = CMD_RST_ALL;
          mst_state_next = MST_REQ_ALL2;
        end
      end
    end

    MST_REQ_ALL2 : begin
      stall_req = 1'b1;
      if (send_tready) begin
        mst_rst_all = 1'b1;
        mst_state_next = MST_REQ_ALL3;
      end
    end

    MST_REQ_ALL3 : begin
      stall_req = 1'b1;
      if (recv_tvalid & recv_tdata == CMD_STALL_RLS) begin
        mst_state_next = MST_IDLE;
      end
    end

    MST_ACK_ALL1 : begin
      stall_req = 1'b1;
      if (stall_ack & send_tready) begin
        send_tvalid = 1'b1;
        send_tdata_next = CMD_STALL_ACK;
        mst_state_next = MST_ACK_ALL2;
      end
    end

    MST_ACK_ALL2 : begin
      stall_req = 1'b1;
      if (recv_tvalid & recv_tdata == CMD_RST_ALL) begin
        if (send_tready) begin
          send_tvalid = 1'b1;
          send_tdata_next = CMD_STALL_RLS;
          mst_state_next = MST_ACK_ALL3;
        end
      end
    end

    MST_ACK_ALL3 : begin
      stall_req = 1'b1;
      if (send_tready) begin
        mst_state_next = MST_IDLE;
      end
    end

  endcase
end


// Slave protocol FSM
localparam
  SLV_IDLE = 1'b0,
  SLV_WAIT = 1'b1;

logic slv_state = SLV_IDLE;
logic slv_state_next;

always @(posedge clk) begin
  slv_state <= enable_sync ? slv_state_next : SLV_IDLE;
end

always @* begin
  slv_state_next = slv_state;
  recv_tready = 1'b0;
  slv_rst_nco = 1'b0;
  slv_rst_all = 1'b0;

  case(slv_state)
    SLV_IDLE: begin
      recv_tready = 1'b1;
      if (~recv_tvalid) slv_state_next = SLV_WAIT;
    end

    SLV_WAIT: begin
      if (recv_tvalid) begin
        if (recv_tdata == CMD_RST_NCO) slv_rst_nco = 1'b1;
        else if (recv_tdata == CMD_RST_ALL) slv_rst_all = 1'b1;
        slv_state_next = SLV_IDLE;
      end
    end
  endcase
end


// Send FSM
localparam
  SEND_IDLE  = 3'b000,
  SEND_MS2   = 3'b001,
  SEND_LS2   = 3'b011,
  SEND_SYNC1 = 3'b111,
  SEND_SYNC2 = 3'b110;

logic [2:0] send_state      = SEND_IDLE;
logic [2:0] send_state_next            ;
logic [1:0] linktx_next     = 2'b00    ;

always @(posedge clk) begin
  send_state <= enable_sync ? send_state_next : SEND_IDLE;
  linktx     <= linktx_next;
end

always @* begin
  send_state_next = send_state;
  linktx_next     = 2'b00;
  send_tready = 1'b0;

  case(send_state)
    SEND_IDLE : begin
      send_tready = 1'b1;
      if (send_tvalid) begin
        linktx_next     = 2'b01;
        send_state_next = SEND_MS2;
      end
    end
    SEND_MS2 : begin
      linktx_next     = send_tdata[3:2];
      send_state_next = SEND_LS2;
    end
    SEND_LS2 : begin
      linktx_next     = send_tdata[1:0];
      // TODO: Send longer streams for some nibble encodings
      send_state_next = SEND_SYNC1;
    end
    // Wait so that send_tready will be synchronized with recv_tvalid in other HL2
    SEND_SYNC1 : begin
      send_state_next = SEND_SYNC2;
    end
    SEND_SYNC2 : begin
      send_state_next = SEND_IDLE;
    end
  endcase
end


// Receive FSM
localparam
  RECV_IDLE  = 2'b00,
  RECV_MS2   = 2'b01,
  RECV_LS2   = 2'b11;

logic [1:0] recv_state      = RECV_IDLE;
logic [1:0] recv_state_next            ;
logic [1:0] linkrx_int      = 2'b00    ;
logic [3:0] recv_tdata_next            ;

always @(posedge clk) begin
  recv_state <= enable_sync ? recv_state_next : RECV_IDLE;
  linkrx_int <= linkrx;
  recv_tdata <= recv_tdata_next;
end

always @* begin
  recv_state_next = recv_state;
  recv_tdata_next = recv_tdata;
  recv_tvalid = 1'b0;

  case(recv_state)
    RECV_IDLE: begin
      recv_tvalid = 1'b1;
      if (linkrx_int == 2'b01) begin
        recv_state_next = RECV_MS2;
      end
    end
    RECV_MS2: begin
      recv_tdata_next = {linkrx_int,recv_tdata[1:0]};
      recv_state_next = RECV_LS2;
    end
    RECV_LS2: begin
      recv_tdata_next = {recv_tdata[3:2],linkrx_int};
      recv_state_next = RECV_IDLE;
    end
  endcase
end



endmodule

