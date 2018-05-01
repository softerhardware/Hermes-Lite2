
// OpenHPSDR upstream (Card->PC) protocol packer

module usopenhpsdr1 (
  clk,
  rst,
  run,
  wide_spectrum,
  hermes_serialno,
  idhermeslite,
  assignnr,
  mac,
  discovery,
  
  udp_tx_enable,
  udp_tx_request,
  udp_tx_data,
  udp_tx_length,

//  phy_tx_data,
//  phy_tx_rdused,
//  tx_fifo_rdreq,

  sp_fifo_rddata,
  have_sp_data,
  sp_fifo_rdreq,

  us_tdata,
  us_tlast,
  us_tready,
  us_tvalid,
  us_tlength
);

input               clk;
input               rst;
input               run;
input               wide_spectrum;
input [7:0]         hermes_serialno;
input               idhermeslite;
input [7:0]         assignnr;
input [47:0]        mac;
input               discovery;

input               udp_tx_enable;
output              udp_tx_request;
output [7:0]        udp_tx_data;
output logic [10:0] udp_tx_length = 'd0;

//input [7:0]         phy_tx_data;
//input [10:0]        phy_tx_rdused;
//output logic        tx_fifo_rdreq = 1'b0;

input [7:0]         sp_fifo_rddata;
input               have_sp_data;
output logic        sp_fifo_rdreq = 1'b0;

input [23:0]        us_tdata;
input               us_tlast;
output              us_tready;
input               us_tvalid;
input [10:0]        us_tlength;

localparam START        = 4'h0,
           WIDE1        = 4'h1,
           WIDE2        = 4'h2,
           DISCOVER1    = 4'h3,
           DISCOVER2    = 4'h4,
           UDP1         = 4'h5,
           UDP2         = 4'h6,
           SYNC_RESP    = 4'h7,
           RXDATA2      = 4'h8,
           RXDATA1      = 4'h9,
           RXDATA0      = 4'ha,
           MIC1         = 4'hb,
           MIC0         = 4'hc,
           PAD          = 4'hd;

logic   [ 3:0]  state = START;
logic   [ 3:0]  state_next;

logic   [10:0]  byte_no = 11'h00;
logic   [10:0]  byte_no_next; 

logic   [10:0]  udp_tx_length_next;

logic   [31:0]  ep6_seq_no = 32'h0;
logic   [31:0]  ep6_seq_no_next;

logic   [31:0]  ep4_seq_no = 32'h0;
logic   [31:0]  ep4_seq_no_next;

logic   [ 7:0]  discover_data = 'd0, discover_data_next;
logic   [ 7:0]  wide_data = 'd0, wide_data_next;
logic   [ 7:0]  udp_data = 'd0, udp_data_next;

// Allow for at least 12 receivers in a round of sample data
logic   [ 6:0]  round_bytes = 7'h00, round_bytes_next;

logic           sp_fifo_rdreq_next;

logic   [31:0]  resp;
logic    [4:0]  c0addr = 'd0;
logic   dot,dash,ptt;
logic   resp_sent;


// State
always @ (posedge clk) begin
  state <= state_next;

  byte_no <= byte_no_next;
  discover_data <= discover_data_next;
  wide_data <= wide_data_next;
  udp_data <= udp_data_next;

  udp_tx_length <= udp_tx_length_next;
  sp_fifo_rdreq <= sp_fifo_rdreq_next;

  round_bytes <= round_bytes_next;

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
  discover_data_next = discover_data;
  wide_data_next = wide_data;
  udp_data_next = udp_data;

  udp_tx_length_next = udp_tx_length;

  round_bytes_next = round_bytes;

  ep6_seq_no_next = ep6_seq_no;
  ep4_seq_no_next = ep4_seq_no;

  sp_fifo_rdreq_next = sp_fifo_rdreq;

  // Combinational
  udp_tx_data = udp_data;
  udp_tx_request = 1'b0;
  resp_sent = 1'b0;
  us_tready = 1'b0;

  case (state)
    START: begin
      sp_fifo_rdreq_next = 1'b0;

      if (discovery) begin 
        udp_tx_length_next = 'h3c;
        state_next = DISCOVER1;

      end else if ((us_tlength > 11'd333) & us_tvalid & ~rst & run) begin // wait until there is enough data in fifo
        udp_tx_length_next = 'd1032;
        state_next = UDP1;
      
      end else if (have_sp_data & wide_spectrum) begin   // Spectrum fifo has data available
        udp_tx_length_next = 'd1032;
        state_next = WIDE1;
      end
    end

    DISCOVER1: begin
      byte_no_next = 'h3a;
      udp_tx_data = discover_data;
      udp_tx_request = 1'b1;
      discover_data_next = 8'hef;
      if (udp_tx_enable) state_next = DISCOVER2;
    end // DISCOVER1:

    DISCOVER2: begin
      byte_no_next = byte_no - 'd1;
      udp_tx_data = discover_data;      
      case (byte_no[5:0])
        6'h3a: discover_data_next = 8'hfe;
        6'h39: discover_data_next = run ? 8'h03 : 8'h02;
        6'h38: discover_data_next = mac[47:40];
        6'h37: discover_data_next = mac[39:32];
        6'h36: discover_data_next = mac[31:24];
        6'h35: discover_data_next = mac[23:16];
        6'h34: discover_data_next = mac[15:8];
        6'h33: discover_data_next = mac[7:0];
        6'h32: discover_data_next = hermes_serialno;
        //7'h31: discover_data_next = IDHermesLite ? 8'h06 : 8'h01;
        // FIXME: Really needed for CW skimmer? Why so much?
        6'h30: discover_data_next = "H";
        6'h2f: discover_data_next = "E";
        6'h2e: discover_data_next = "R";
        6'h2d: discover_data_next = "M";
        6'h2c: discover_data_next = "E";
        6'h2b: discover_data_next = "S";
        6'h2a: discover_data_next = "L";
        6'h29: discover_data_next = "T";
        6'h28: discover_data_next = assignnr;
        6'h00: begin
          discover_data_next = idhermeslite ? 8'h06 : 8'h01;
          state_next = START;
        end
        default: discover_data_next = idhermeslite ? 8'h06 : 8'h01;
      endcase
    end

    // start sending UDP/IP data
    WIDE1: begin
      byte_no_next = 'h406;
      udp_tx_data = wide_data;
      udp_tx_request = 1'b1;
      wide_data_next = 8'hef;
      if (udp_tx_enable) state_next = WIDE2;
    end 

    WIDE2: begin
      byte_no_next = byte_no - 'd1;
      udp_tx_data = wide_data;
      case (byte_no)
        11'h406: wide_data_next = 8'hfe;
        11'h405: wide_data_next = 8'h01;
        11'h404: wide_data_next = 8'h04;
        11'h403: wide_data_next = ep4_seq_no[31:24];
        11'h402: wide_data_next = ep4_seq_no[23:16];
        11'h401: begin wide_data_next = ep4_seq_no[15:8]; sp_fifo_rdreq_next = 1'b1; end
        11'h400: wide_data_next = ep4_seq_no[7:0];    
        11'h001: begin sp_fifo_rdreq_next = 1'b0; wide_data_next = sp_fifo_rddata; end 
        11'h000: begin 
          wide_data_next = sp_fifo_rddata;
          ep4_seq_no_next = ep4_seq_no + 'h1;
          state_next = START;
        end
        default: wide_data_next = sp_fifo_rddata;     
      endcase
    end

    UDP1: begin
      byte_no_next = 'h406;
      udp_tx_request = 1'b1;
      udp_data_next = 8'hef;
      if (udp_tx_enable) state_next = UDP2;
    end
    
    UDP2: begin
      byte_no_next = byte_no - 'd1;
      case (byte_no[2:0])
        3'h6: udp_data_next = 8'hfe;
        3'h5: udp_data_next = 8'h01;
        3'h4: udp_data_next = 8'h06;
        3'h3: udp_data_next = ep6_seq_no[31:24];
        3'h2: udp_data_next = ep6_seq_no[23:16];
        3'h1: udp_data_next = ep6_seq_no[15:8]; 
        3'h0: begin
          udp_data_next = ep6_seq_no[7:0];
          ep6_seq_no_next = ep6_seq_no + 'h1;
          state_next = SYNC_RESP;
        end
        default: udp_data_next = 8'hfe;
      endcase // byte_no
    end // UDP2:

    SYNC_RESP: begin
      byte_no_next = byte_no - 'd1;
      round_bytes_next = 'd0;
      case (byte_no[8:0])
        9'h1ff: udp_data_next = 8'h7f;
        9'h1fe: udp_data_next = 8'h7f;
        9'h1fd: udp_data_next = 8'h7f;
        9'h1fc: udp_data_next = {c0addr,dot,dash,ptt};
        9'h1fb: udp_data_next = resp[31:24];
        9'h1fa: udp_data_next = resp[23:16];
        9'h1f9: udp_data_next = resp[15:8];
        9'h1f8: begin 
          udp_data_next = resp[7:0];
          resp_sent = 1'b1; 
          state_next = RXDATA2; 
        end 
        default: udp_data_next = 8'hxx; 
      endcase
    end

    RXDATA2: begin
      byte_no_next = byte_no - 'd1;
      round_bytes_next = round_bytes + 'd1;
      udp_data_next = us_tdata[23:16];

      if (|byte_no[8:0]) begin
        state_next = RXDATA1;
      end else begin 
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end      

    RXDATA1: begin
      byte_no_next = byte_no - 'd1;
      round_bytes_next = round_bytes + 'd1;
      udp_data_next = us_tdata[15:8];

      if (|byte_no[8:0]) begin
        state_next = RXDATA0;        
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START; 
      end
    end   

    RXDATA0: begin
      byte_no_next = byte_no - 'd1;
      round_bytes_next = round_bytes + 'd1;
      udp_data_next = us_tdata[7:0];
      us_tready = 1'b1; // Pop next word

      if (|byte_no[8:0]) begin
        state_next = (us_tlast) ? MIC1 : RXDATA2;
      end else begin 
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end 

    MIC1: begin
      byte_no_next = byte_no - 'd1;
      round_bytes_next = round_bytes + 'd1;
      udp_data_next = 'd0;
      
      if (|byte_no[8:0]) begin
        state_next = MIC0;
      end else begin 
        state_next = byte_no[9] ? SYNC_RESP : START;
      end   
    end 

    MIC0: begin
      byte_no_next = byte_no - 'd1;
      round_bytes_next = 'd0;
      udp_data_next = 'd0;

      if (|byte_no[8:0]) begin
        // Enough room for another round of data?
        state_next = (byte_no > round_bytes) ? RXDATA2 : PAD;
      end else begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end
    end

    PAD: begin
      byte_no_next = byte_no - 'd1;
      udp_data_next = 8'h00;

      if (~(|byte_no[8:0])) begin
        state_next = byte_no[9] ? SYNC_RESP : START;
      end 
    end 

    default: state_next = START;

  endcase // state
end // always @*



always @ (posedge clk) begin
  if (resp_sent) begin
    if (&c0addr[1:0]) c0addr <= 'd0;
    else c0addr <= c0addr + 1;
  end
end 

assign resp = 'd0;
assign ptt = 1'b0;
assign dot = 1'b0;
assign dash = 1'b0;


endmodule
