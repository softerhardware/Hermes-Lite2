
// OpenHPSDR upstream (Card->PC) protocol packer

module usopenhpsdr1 (
  clk,
  rst,
  run,
  wide_spectrum,
  hermes_serialno,
  idhermeslite,
  assignnr,

  udp_tx_enable,
  udp_tx_active,
  udp_tx_request,
  udp_tx_data,
  udp_tx_length,

  phy_tx_data,
  phy_tx_rdused,
  tx_fifo_rdreq,

  mac,
  discovery,

  sp_fifo_rddata,
  have_sp_data,
  sp_fifo_rdreq

  //us_tdata,
  //us_tfirst,
  //us_tready,
  //us_tvalid,
  //us_tlength
);

input               clk;
input               rst;
input               run;
input               wide_spectrum;
input [7:0]         hermes_serialno;
input               idhermeslite;
input [7:0]         assignnr;

input               udp_tx_enable;
input               udp_tx_active;
output logic        udp_tx_request = 1'b0;
output logic [7:0]  udp_tx_data = 8'h00;
output logic [10:0] udp_tx_length = 11'h0;

input [7:0]         phy_tx_data;
input [10:0]        phy_tx_rdused;
output logic        tx_fifo_rdreq = 1'b0;

input [47:0]        mac;
input               discovery;

input [7:0]         sp_fifo_rddata;
input               have_sp_data;
output logic        sp_fifo_rdreq = 1'b0;

//input [7:0]       us_tdata;
//input             us_tfirst;
//output            us_tready;
//input             us_tvalid;
//input [9:0]       us_tlength;

localparam START        = 'h00,
            UDP1        = 'h01,
            UDP2        = 'h02,
           WIDE1        = 'h03,
           WIDE2        = 'h04,
           DISCOVER1    = 'h05,
           DISCOVER2    = 'h06;


logic   [ 2:0]  state = START;
logic   [ 2:0]  state_next;

logic   [10:0]  byte_no = 11'h00;
logic   [10:0]  byte_no_next; 

logic           udp_tx_request_next; 

logic   [10:0]  udp_tx_length_next;

logic   [31:0]  ep6_seq_no = 32'h0;
logic   [31:0]  ep6_seq_no_next;

logic   [31:0]  ep4_seq_no = 32'h0;
logic   [31:0]  ep4_seq_no_next;

logic   [ 7:0]  udp_tx_data_next;

logic           sp_fifo_rdreq_next;
logic           tx_fifo_rdreq_next;

// State
always @ (posedge clk) begin
  state <= state_next;

  byte_no <= byte_no_next;
  udp_tx_request <= udp_tx_request_next;
  udp_tx_length <= udp_tx_length_next;
  udp_tx_data <= udp_tx_data_next;
  sp_fifo_rdreq <= sp_fifo_rdreq_next;
  tx_fifo_rdreq <= tx_fifo_rdreq_next;

  if (~run) begin
    ep6_seq_no <= 32'h0;
    ep4_seq_no <= 32'h0;
  end else begin
    ep6_seq_no <= ep6_seq_no_next;
    ep4_seq_no <= ep4_seq_no_next;
  end // end else
end // always @ (posedge clk)


// FSM Combinational
always @* begin

  // Next State
  state_next = state;

  byte_no_next = byte_no;
  udp_tx_request_next = udp_tx_request;
  udp_tx_length_next = udp_tx_length;
  udp_tx_data_next = udp_tx_data;

  ep6_seq_no_next = ep6_seq_no;
  ep4_seq_no_next = ep4_seq_no;

  sp_fifo_rdreq_next = sp_fifo_rdreq;
  tx_fifo_rdreq_next = tx_fifo_rdreq;

  // Combinational

  case (state)
    START: begin
      byte_no_next = 11'h0;
      udp_tx_request_next = 1'b0;
      udp_tx_length_next = 11'h0;

      sp_fifo_rdreq_next = 1'b0;
      tx_fifo_rdreq_next = 1'b0;

      if (discovery) begin 
        udp_tx_request_next = 1'b1;
        udp_tx_length_next = 11'd60;
        state_next = DISCOVER1;

      end else if (phy_tx_rdused > 11'd1023  & ~rst & run) begin // wait until we have at least 1024 bytes in Tx fifo
        udp_tx_request_next = 1'b1;
        udp_tx_length_next = 11'd1032;
        state_next = UDP1;
      
      end else if (have_sp_data & wide_spectrum) begin   // Spectrum fifo has data available
        udp_tx_request_next = 1'b1;
        udp_tx_length_next = 11'd1032;
        state_next = WIDE1;
      end
    end

    DISCOVER1: begin
      udp_tx_data_next = 8'hef;
      if (udp_tx_enable) state_next = DISCOVER2;
    end // DISCOVER1:

    DISCOVER2: begin
      if (byte_no < 11'd59) begin // Total-1
        if (udp_tx_active) begin
          case (byte_no)
            11'd0: udp_tx_data_next = 8'hfe;
            11'd1: udp_tx_data_next = run ? 8'h03 : 8'h02;
            11'd2: udp_tx_data_next = mac[47:40];
            11'd3: udp_tx_data_next = mac[39:32];
            11'd4: udp_tx_data_next = mac[31:24];
            11'd5: udp_tx_data_next = mac[23:16];
            11'd6: udp_tx_data_next = mac[15:8];
            11'd7: udp_tx_data_next = mac[7:0];
            11'd8: udp_tx_data_next = hermes_serialno;
            //11'd9: udp_tx_data_next = IDHermesLite ? 8'h06 : 8'h01;
            // FIXME: Really needed for CW skimmer? Why so much?
            11'd10: udp_tx_data_next = "H";
            11'd11: udp_tx_data_next = "E";
            11'd12: udp_tx_data_next = "R";
            11'd13: udp_tx_data_next = "M";
            11'd14: udp_tx_data_next = "E";
            11'd15: udp_tx_data_next = "S";
            11'd16: udp_tx_data_next = "L";
            11'd17: udp_tx_data_next = "T";
            11'd18: udp_tx_data_next = assignnr;
            default: udp_tx_data_next = idhermeslite ? 8'h06 : 8'h01;
          endcase
          byte_no_next = byte_no + 'd1;
        end

      end else begin
        state_next = START;
      end
    end

    // start sending UDP/IP data
    WIDE1: begin
      udp_tx_data_next = 8'hef;
      if (udp_tx_enable) state_next = WIDE2;
    end 

    WIDE2: begin
      if (byte_no < 11'd1031) begin // Total-1
        if (udp_tx_active) begin
          case (byte_no)
            11'd0: udp_tx_data_next = 8'hfe;
            11'd1: udp_tx_data_next = 8'h01;
            11'd2: udp_tx_data_next = 8'h04;
            11'd3: udp_tx_data_next = ep4_seq_no[31:24];
            11'd4: udp_tx_data_next = ep4_seq_no[23:16];
            11'd5: begin udp_tx_data_next = ep4_seq_no[15:8]; sp_fifo_rdreq_next = 1'b1; end
            11'd6: udp_tx_data_next = ep4_seq_no[7:0];    
            11'd1029: begin sp_fifo_rdreq_next = 1'b0; udp_tx_data_next = sp_fifo_rddata; end // Total-3
            default: udp_tx_data_next = sp_fifo_rddata;     
          endcase       
          byte_no_next = byte_no + 'd1;
        end

      end else begin
        ep4_seq_no_next = ep4_seq_no + 'h01;
        state_next = START;
      end
    end

    UDP1: begin
      udp_tx_data_next = 8'hef;
      if (udp_tx_enable) state_next = UDP2;
    end
    
    UDP2: begin
      if (byte_no < 11'd1031) begin // Total-1
        if (udp_tx_active) begin
          case (byte_no)
            11'd0: udp_tx_data_next = 8'hfe;
            11'd1: udp_tx_data_next = 8'h01;
            11'd2: udp_tx_data_next = 8'h06;
            11'd3: udp_tx_data_next = ep6_seq_no[31:24];
            11'd4: udp_tx_data_next = ep6_seq_no[23:16];
            11'd5: begin udp_tx_data_next = ep6_seq_no[15:8]; tx_fifo_rdreq_next = 1'b1; end
            11'd6: udp_tx_data_next = ep6_seq_no[7:0];  
            11'd1029: begin tx_fifo_rdreq_next = 1'b0; udp_tx_data_next = phy_tx_data; end // Total-3  
            default: udp_tx_data_next = phy_tx_data;    
          endcase       
          byte_no_next = byte_no + 'd1;
        end
      
      end else begin
        ep6_seq_no_next = ep6_seq_no + 'h1;
        state_next = START;
      end
    end

    default: state_next = START;

  endcase // state
end // always @*



endmodule
