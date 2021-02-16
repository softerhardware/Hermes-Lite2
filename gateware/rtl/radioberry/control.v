module control(
	clk,
	clk_slow,
	
	run,
	
	cmd_addr,
	cmd_data,
	cmd_rqst,
 
	tx_on,
	cw_on,
	
	cw_keydown,
  
	io_phone_tip,  
	io_phone_ring,  

	msec_pulse,
	qmsec_pulse,
	
	resp,
	
	pa_temp_enabletx,
	
	pa_inttr,
	pa_exttr,
	
    pwr_envpa,
	pwr_envbias,
  );

input           clk;		// clk_internal = 10Mhz.
input			clk_slow;

input           run;

input  [5:0]    cmd_addr;
input  [31:0]   cmd_data;
input           cmd_rqst;

input           tx_on;
input           cw_on;
output          cw_keydown;

input           io_phone_tip;
input           io_phone_ring;

output logic    msec_pulse = 1'b0;
output logic    qmsec_pulse = 1'b0;

output [7:0] 	resp;

input			pa_temp_enabletx;
  
output          pa_inttr;
output          pa_exttr;

output          pwr_envpa;
output          pwr_envbias;


parameter     CW = 0;


logic         pa_enable = 1'b0;
logic         tr_disable = 1'b0;

logic [11:0]   qmillisec_count, qmillisec_count_next;
logic [1:0]   millisec_count, millisec_count_next;
logic int_tx_on;
logic ext_ptt;

assign int_tx_on = (tx_on | ext_ptt ) & run & pa_temp_enabletx;
assign pa_inttr = int_tx_on & (pa_enable | ~tr_disable);
assign pa_exttr = int_tx_on;
assign pwr_envpa = int_tx_on & pa_enable;
assign pwr_envbias = int_tx_on & pa_enable;

assign resp = {5'b0, ext_cwkey,  1'b0, cw_on | ext_ptt};

always @(posedge clk) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h09) begin
      pa_enable    <= cmd_data[19];
      tr_disable   <= cmd_data[18]; 
    end
  end
end


// Gererate two slow pulses for timing.  msec_pulse occurs every one millisecond.
// qmsec_pulse occurs every quarter of a millisecond
// led_saturate occurs every 64 milliseconds.
always @(posedge clk) begin
  qmillisec_count <= qmillisec_count_next;
  millisec_count <= millisec_count_next;
end

always @* begin
  qmillisec_count_next = qmillisec_count - 10'd1;
  millisec_count_next  = millisec_count;

  qmsec_pulse = 1'b0;
  msec_pulse = 1'b0;
  
  if (qmillisec_count == 12'd0) begin
    qmillisec_count_next = 12'd2500;
    qmsec_pulse = 1'b1;
    millisec_count_next = millisec_count - 2'd1;
    if (&millisec_count) msec_pulse = 1'b1;
  end
end


debounce de_phone_tip(.clean_pb(ext_cwkey), .pb(~io_phone_tip), .clk(clk), .msec_pulse(msec_pulse));
debounce de_phone_ring(.clean_pb(clean_ring), .pb(~io_phone_ring), .clk(clk), .msec_pulse(msec_pulse));

generate
  case (CW)
    0: begin: CW_NONE
      assign cw_keydown = 1'b0;

      assign ext_ptt = 1'b0;
    end

    1: begin: CW_BASIC

      assign cw_keydown = ext_cwkey;
      assign ext_ptt = clean_ring;

    end

    2: begin: CW_OPENHPSDR

      // No ext_ptt
      assign ext_ptt = 1'b0;

      cw_openhpsdr cw_openhpsdr_i (
        .clk               (clk       ),
        .clk_slow          (clk_slow  ),
        .cmd_addr          (cmd_addr  ),
        .cmd_data          (cmd_data  ),
        .cmd_rqst          (cmd_rqst  ),
        .dot_key           (ext_cwkey ),
        .dash_key          (clean_ring),
        .cw_keydown        (cw_keydown)
      );
    end

  endcase
endgenerate


endmodule