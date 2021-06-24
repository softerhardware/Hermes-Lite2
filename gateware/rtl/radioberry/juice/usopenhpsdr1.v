
// OpenHPSDR upstream (Card->PC) protocol packer

module usopenhpsdr1 (
	input						clk                 ,
	input						run                 ,
	input						wide_spectrum       ,
  
	output logic [7:0]  		us_stream			,
	input 						us_stream_ready		,
	output logic 				us_stream_valid		,

	input        [11:0] 		bs_tdata            ,
	output                      bs_tready           ,
	input                       bs_tvalid           ,
	
	input        [23:0] 		us_tdata            ,
	input                       us_tlast            ,
	output                      us_tready           ,
	input                       us_tvalid           ,
	input        [1:0] 			us_tuser            ,
	input        [10:0] 		us_tlength          ,
 
	// Command slave interface
	input        [           5:0] cmd_addr          ,
	input        [          31:0] cmd_data          ,
	input                         cmd_rqst          ,
	
	input        [          39:0] resp              ,
	output logic                  resp_rqst             = 1'b0
);

localparam START        = 5'h0,
           WIDE1        = 5'h1,
           WIDE2        = 5'h2,
           WIDE3        = 5'h3,
           WIDE4        = 5'h4,
           UDP1         = 5'h7,
           UDP2         = 5'h8,
           SYNC_RESP    = 5'h9,
           RXDATA2      = 5'ha,
           RXDATA1      = 5'hb,
           RXDATA0      = 5'hc,
           MIC1         = 5'hd,
           MIC0         = 5'he,
           PAD          = 5'hf,
           POST         = 5'h10;

logic [ 4:0] state              = START                  ;
logic [ 4:0] state_next                                  ;
logic [10:0] byte_no            = 11'h00                 ;
logic [10:0] byte_no_next                                ;
logic [19:0] ep6_seq_no         = 20'h0                  ;
logic [19:0] ep6_seq_no_next                             ;
logic [19:0] ep4_seq_no         = 20'h0                  ;
logic [19:0] ep4_seq_no_next                             ;


// Allow for at least 12 receivers in a round of sample data
logic [           6:0] round_bytes      = 7'h00, round_bytes_next;
logic [           6:0] bs_cnt           = 7'h1, bs_cnt_next      ;
logic [           6:0] set_bs_cnt       = 7'h1                   ;
logic                  resp_rqst_next                            ;
logic                  vna              = 1'b0                   ;
logic [1:0] 		   vna_mic          = 0, vna_mic_next        ;
logic [7:0] 		   vna_mic_msb, vna_mic_lsb;

assign vna_mic_msb = 8'h00;
assign vna_mic_lsb = vna ? {7'h00,vna_mic[0]} : 8'h00;


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
end


// State
always @ (posedge clk) begin
  state <= state_next;
  byte_no <= byte_no_next;
  bs_cnt <= bs_cnt_next;
  round_bytes <= round_bytes_next;
  
  resp_rqst <= resp_rqst_next;
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

  us_stream_valid = 1'b0;
   
  round_bytes_next = round_bytes;

  ep6_seq_no_next = ep6_seq_no;
  ep4_seq_no_next = ep4_seq_no;

  bs_cnt_next = bs_cnt;

  resp_rqst_next = resp_rqst;

  vna_mic_next = vna_mic;

  // Combinational
  us_tready = 1'b0;
  bs_tready = 1'b0;

  case (state)
    START: begin
		us_stream_valid = 1'b0;
		if ((us_tlength > 11'd333) & us_tvalid & run) begin // wait until there is enough data in fifo
			us_stream = 8'hef;
			state_next = UDP1;
		end 
		else if (bs_tvalid & ~(|bs_cnt)) begin
			bs_cnt_next = set_bs_cnt; // Set count until next wide data
			if (wide_spectrum) begin
				us_stream = 8'hef;
				state_next = WIDE1;
			end
		end 
    end
	
	WIDE1: begin
		us_stream_valid = 1'b0; 
		byte_no_next = 'h406;
		us_stream = 8'hef;	
		state_next = WIDE2;
	end

    WIDE2: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			byte_no_next = byte_no - 11'd1;
			case (byte_no[2:0])
				3'h6: us_stream = 8'hfe;
				3'h5: us_stream = 8'h01;
				3'h4: us_stream = 8'h04;
				3'h3: us_stream = 8'h00; //ep4_seq_no[31:24];
				3'h2: us_stream = {4'h0,ep4_seq_no[19:16]};
				3'h1: us_stream = ep4_seq_no[15:8];
				3'h0: begin
						us_stream = ep4_seq_no[7:0];
						ep4_seq_no_next = ep4_seq_no + 'h1;
						state_next = WIDE3;
					  end
				default: us_stream = 8'hxx;
			endcase
		end
    end

    WIDE3: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			byte_no_next = byte_no - 11'd1;
			us_stream = { bs_tdata[3:0],4'b0000 };
			
			state_next = WIDE4;
		end
    end

    WIDE4: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
		  byte_no_next = byte_no - 11'd1;
		  us_stream = bs_tdata[11:4];
		  bs_tready = 1'b1; // Pop data

		  // Escape if something goes wrong
		  state_next = (|byte_no) ? WIDE3 : POST;
		end
    end
	
	UDP1: begin
		us_stream_valid = 1'b0; 
		byte_no_next = 'h406;
		us_stream = 8'hef;	
		state_next = UDP2;
	end

    UDP2: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			byte_no_next = byte_no - 11'd1;
			case (byte_no[2:0])
				3'h6: us_stream = 8'hfe;
				3'h5: us_stream = 8'h01;
				3'h4: us_stream = 8'h06;
				3'h3: us_stream = 8'h00; //ep6_seq_no[31:24];
				3'h2: us_stream = {4'h00,ep6_seq_no[19:16]};
				3'h1: us_stream = ep6_seq_no[15:8];
				3'h0: begin
				  us_stream = ep6_seq_no[7:0];
				  ep6_seq_no_next = ep6_seq_no + 'h1;
				  if (|bs_cnt) bs_cnt_next = bs_cnt - 7'd1;
				  state_next = SYNC_RESP;
				end
				default: us_stream = 8'hxx;
			endcase // byte_no
		end
    end // UDP2:

    SYNC_RESP: begin
	
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			
			byte_no_next = byte_no - 11'd1;
			round_bytes_next = 'd0;
			case (byte_no[8:0])
				9'h1ff: us_stream = 8'h7f;
				9'h1fe: us_stream = 8'h7f;
				9'h1fd: us_stream = 8'h7f;
				9'h1fc: us_stream = resp[39:32];
				9'h1fb: us_stream = resp[31:24];
				9'h1fa: us_stream = resp[23:16];
				9'h1f9: us_stream = resp[15:8];
				9'h1f8: begin
				  us_stream = resp[7:0];
				  resp_rqst_next = ~resp_rqst;
				  state_next = RXDATA2;
				end
				default: us_stream = 8'hxx;
			endcase
		end
    end

    RXDATA2: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			
		  byte_no_next = byte_no - 11'd1;
		  round_bytes_next = round_bytes + 7'd1;
		  us_stream = us_tdata[23:16];

		  vna_mic_next = us_tuser; // Save mic bit for use later with mic data

		  if (|byte_no[8:0]) begin
			state_next = RXDATA1;
		  end else begin
			state_next = byte_no[9] ? SYNC_RESP : START;
		  end
		end
    end

    RXDATA1: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			
		  byte_no_next = byte_no - 11'd1;
		  round_bytes_next = round_bytes + 7'd1;
		  us_stream = us_tdata[15:8];

		  if (|byte_no[8:0]) begin
			state_next = RXDATA0;
		  end else begin
			state_next = byte_no[9] ? SYNC_RESP : START;
		  end
		end
    end

    RXDATA0: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
		 
		  byte_no_next = byte_no - 11'd1;
		  round_bytes_next = round_bytes + 7'd1;
		  us_stream = us_tdata[7:0];
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
    end

    MIC1: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			
		  byte_no_next = byte_no - 11'd1;
		  round_bytes_next = round_bytes + 7'd1;
		  us_stream = vna_mic_msb;

		  if (|byte_no[8:0]) begin
			state_next = MIC0;
		  end else begin
			state_next = byte_no[9] ? SYNC_RESP : START; 
		  end
		end
    end

    MIC0: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			
		  byte_no_next = byte_no - 11'd1;
		  round_bytes_next = 'd0;
		  us_stream = vna_mic_lsb;

		  if (|byte_no[8:0]) begin
			// Enough room for another round of data?
			state_next = (byte_no[8:0] > round_bytes) ? RXDATA2 : PAD;
		  end else begin
			state_next = byte_no[9] ? SYNC_RESP : POST;
		  end
		end
    end

    PAD: begin
		us_stream_valid = 1'b1;
		if (us_stream_ready) begin
			
		  byte_no_next = byte_no - 11'd1;
		  us_stream = 8'h00;

		  if (~(|byte_no[8:0])) begin
			state_next = byte_no[9] ? SYNC_RESP : POST;
			
		  end
		end
    end
	
	POST: begin
		us_stream_valid = 1'b1;
		us_stream = 8'hef;
		if (us_stream_ready) state_next = START;
    end

    default: state_next = START;

  endcase // state
end // always @*


endmodule
