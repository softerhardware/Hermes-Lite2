
module hl2link_app (
  input               clk            ,
  input               phy_connected  ,
  input        [ 1:0] linkrx         ,
  output logic [ 1:0] linktx         ,
  output              stall_req      ,
  input               stall_ack      ,
  output logic        rst_all          = 1'b0,
  output logic        rst_nco          = 1'b0,
  output              running        ,
  output logic        master_sel       = 1'b0,
  output       [23:0] lm_data        ,
  output logic        lm_valid         = 1'b0,
  input        [23:0] ls_data        ,
  input               ls_valid       ,
  output              ls_done        ,
  input        [ 5:0] ds_cmd_addr    ,
  input        [31:0] ds_cmd_data    ,
  input               ds_cmd_rqst    ,
  input               ds_cmd_resprqst,
  input               ds_cmd_is_alt  ,
  input        [ 1:0] ds_cmd_mask    ,
  output logic [ 5:0] cmd_addr         = 6'h00,
  output logic [31:0] cmd_data         = 32'h0000,
  output logic        cmd_cnt          = 1'b0,
  output logic        cmd_resprqst     = 1'b0,
  output logic        cmd_is_alt       = 1'b0,
  input               cmd_rqst
);

logic        send_tvalid;
logic        cmd_send_tvalid;
logic [37:0] send_tdata ;
logic [ 1:0] send_tuser ;
logic        send_tready;
logic        send_tdone ;

logic        recv_tvalid;
logic [37:0] recv_tdata ;
logic [ 1:0] recv_tuser ;
logic        recv_tready;
logic        recv_tdone ;

logic cl1on_ack, cl1on_rqst;

logic rst_link = 1'b0;

assign send_tdata  = master_sel ? {ds_cmd_addr,ds_cmd_data} : {ls_data,ds_cmd_data[13:0]};
assign send_tuser  = master_sel ? 2'b01 : 2'b10;
assign send_tvalid = master_sel ? cmd_send_tvalid : ls_valid;

assign recv_tready = 1'b1;

assign stall_req = 1'b0;

assign lm_data = recv_tdata[23:0];

always @(posedge clk) begin
  lm_valid <= recv_tdone;
end 

assign ls_done = send_tdone;

// hl2link master control - only accessible via ethernet
always @(posedge clk) begin
  if (ds_cmd_rqst & ds_cmd_addr == 6'h39 & ds_cmd_data[11]) begin
    case (ds_cmd_data[8])
      1'h0: master_sel <= 1'b0;
      1'h1: master_sel <= 1'b1;
    endcase
  end 
end

// hl2link global control - synchronized with slave
always @(posedge clk) begin
  if (cmd_rqst & cmd_addr == 6'h39) begin
    if (cmd_data[7]) begin
      case (cmd_data[4])
        1'h0: rst_all <= 1'b1;
        1'h1: rst_nco <= 1'b1;
      endcase
    end
    // reset link if master switching off, or not master and switching off cl1
    if ((cmd_data[11] & ~cmd_data[8]) | (~master_sel & cmd_data[3:0]==4'hc)) rst_link <=  1'b1;
  end else begin
    rst_all <=  1'b0;
    rst_nco <=  1'b0;
    rst_link <= 1'b0;
  end
end



// Command FSM
localparam
  CMD_IDLE       = 3'b000,
  CMD_SLV0       = 3'b001,
  CMD_MST0       = 3'b010,
  CMD_MST1       = 3'b011,
  CMD_SLVCLK1ON0 = 3'b101,
  CMD_SLVCLK1ON1 = 3'b110;

logic [2:0] cmd_state      = CMD_IDLE;
logic [2:0] cmd_state_next           ;

logic [ 5:0] cmd_addr_next    ;
logic [31:0] cmd_data_next    ;
logic        cmd_cnt_next     ;
logic        cmd_resprqst_next;
logic        cmd_is_alt_next  ;


always @(posedge clk) begin
  cmd_state    <= cmd_state_next;
  cmd_data     <= cmd_data_next;
  cmd_addr     <= cmd_addr_next;
  cmd_cnt      <= cmd_cnt_next;
  cmd_resprqst <= cmd_resprqst_next;
  cmd_is_alt   <= cmd_is_alt_next;
end

always @* begin
  cmd_state_next    = cmd_state;
  cmd_data_next     = cmd_data;
  cmd_addr_next     = cmd_addr;
  cmd_cnt_next      = cmd_cnt;
  cmd_resprqst_next = cmd_resprqst;
  cmd_is_alt_next   = cmd_is_alt;

  cmd_send_tvalid = 1'b0;
  cl1on_ack   = 1'b0;

  case(cmd_state)
    CMD_IDLE : begin
      if ((recv_tuser == 2'b01) & recv_tdone & ~master_sel) begin
        cmd_state_next = CMD_SLV0;
      end else if (cl1on_rqst & ~master_sel) begin
        cmd_state_next = CMD_SLVCLK1ON0;
      end else if (ds_cmd_rqst) begin
        cmd_send_tvalid   = ds_cmd_mask[1]; // Only send to remote if mask set
        cmd_data_next     = ds_cmd_data;
        cmd_addr_next     = ds_cmd_addr;
        cmd_resprqst_next = ds_cmd_resprqst;
        cmd_is_alt_next   = ds_cmd_is_alt;
        cmd_state_next    = running ? CMD_MST0 : CMD_MST1;
      end
    end

    // Delay to sync issue with slave
    CMD_MST0 : begin
      if (send_tready | send_tdone) cmd_state_next = CMD_MST1;
    end

    CMD_MST1 : begin
      cmd_cnt_next   = (ds_cmd_mask[0] | ~running) ? ~cmd_cnt : cmd_cnt; // Only send to master if mask set
      cmd_state_next = CMD_IDLE;
    end

    CMD_SLV0 : begin
      cmd_data_next     = recv_tdata[31:0];
      cmd_addr_next     = recv_tdata[37:32];
      cmd_resprqst_next = 1'b0;
      cmd_is_alt_next   = 1'b0;
      cmd_cnt_next      = ~cmd_cnt;
      cmd_state_next    = CMD_IDLE;
    end

    CMD_SLVCLK1ON0 : begin
      // Create command to turn cl1on, sync with i2c.v
      cmd_data_next     = 32'h0000_000d;
      cmd_addr_next     = 6'h39;
      cmd_resprqst_next = 1'b0;
      cmd_is_alt_next   = 1'b0;
      cmd_cnt_next      = ~cmd_cnt;
      cmd_state_next    = CMD_SLVCLK1ON1;
    end

    CMD_SLVCLK1ON1 : begin
      cl1on_ack = 1'b1;
      if (~cl1on_rqst) cmd_state_next = CMD_IDLE;
    end

    default: cmd_state_next = CMD_IDLE;

  endcase
end

hl2link hl2link_i (
  .clk        (clk        ),
  .rst        (rst_link   ),
  .linkrx     (linkrx     ),
  .linktx     (linktx     ),
  .running    (running    ),
  .master_sel (master_sel ),
  .cl1on_ack  (cl1on_ack  ),
  .cl1on_rqst (cl1on_rqst ),
  // Send interface
  .send_tvalid(send_tvalid),
  .send_tdata (send_tdata ),
  .send_tuser (send_tuser ),
  .send_tready(send_tready),
  .send_tdone (send_tdone ),
  // Receive interface
  .recv_tvalid(recv_tvalid),
  .recv_tdata (recv_tdata ),
  .recv_tuser (recv_tuser ),
  .recv_tready(recv_tready),
  .recv_tdone (recv_tdone )
);



endmodule

