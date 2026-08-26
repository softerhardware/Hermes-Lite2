//
//  HPSDR - High Performance Software Defined Radio
//
//  Metis code. 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


//  Metis code copyright 2010, 2011, 2012, 2013 Alex Shovkoplyas, VE3NEA.
// Steve Haynal KF7O 2018

//-----------------------------------------------------------------------------
// CDC toolkit.  Every clock domain crossing should use one of the following
// mechanisms (raw crossings must carry a "// QUASI_STATIC_CDC: <reason>"
// annotation instead):
//
//   sync          level signal into another domain (DEPTH flops)
//   sync_pulse    every edge of the input becomes a one-cycle pulse
//   sync_one      each 0->1 transition becomes a one-cycle pulse
//   sync_qualifier  multi-bit bus + source-side valid toggle; the bus is
//                 captured in the destination domain only when the synced
//                 toggle proves it is stable
//   sync_handshake  pulse transfer with full four-phase acknowledgement
//
// All chains use (*preserve*) and initializer-only reset (FPGA target).
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// transfer signal to another clock domain
//-----------------------------------------------------------------------------
module sync (
  input clock,
  input sig_in,
  output sig_out
);

parameter DEPTH = 2;

initial begin
  if (DEPTH < 2) begin
    $display("ERROR: %m: sync DEPTH must be >= 2");
    $finish;
  end
end

(*preserve*) reg [DEPTH-1:0] sync_chain = {DEPTH{1'b0}};

always @(posedge clock)
  sync_chain <= {sig_in, sync_chain[DEPTH-1:1]};

assign sig_out = sync_chain[0];

endmodule


//-----------------------------------------------------------------------------
// transfer change as pulse to another domain
//-----------------------------------------------------------------------------
module sync_pulse (
  input clock,
  input sig_in,
  output sig_out
);

parameter DEPTH = 3;

initial begin
  if (DEPTH < 2) begin
    $display("ERROR: %m: sync_pulse DEPTH must be >= 2");
    $finish;
  end
end

(*preserve*) reg [DEPTH-1:0] sync_chain = {DEPTH{1'b0}};

always @(posedge clock)
  sync_chain <= {sig_in, sync_chain[DEPTH-1:1]};

assign sig_out = sync_chain[0] ^ sync_chain[1];

endmodule


//-----------------------------------------------------------------------------
// transfer change as pulse to another domain
//-----------------------------------------------------------------------------
module sync_one (
  input clock,
  input sig_in,
  output sig_out
);

parameter DEPTH = 3;

initial begin
  if (DEPTH < 2) begin
    $display("ERROR: %m: sync_one DEPTH must be >= 2");
    $finish;
  end
end

(*preserve*) reg [DEPTH-1:0] sync_chain = {DEPTH{1'b0}};

always @(posedge clock)
  sync_chain <= {sig_in, sync_chain[DEPTH-1:1]};

assign sig_out = ~sync_chain[0] & sync_chain[1];

endmodule


//-----------------------------------------------------------------------------
// Capture a multi-bit bus into the destination domain under a valid-toggle
// qualifier (the pattern used for remote_mac in ethernet/network.v).
//
// Contract:
//   - data_in must be registered in its source domain and stable before and
//     while data_valid toggles,
//   - successive updates must be spaced wider than the synchronizer latency.
// data_out captures data_in whenever an edge of data_valid arrives through
// the synchronizer; one extra capture occurs at startup so source register
// initializers propagate without waiting for the first toggle.
//-----------------------------------------------------------------------------
module sync_qualifier #(
  parameter WIDTH = 8,
  parameter DEPTH = 3
)(
  input                    clock,           // destination clock
  input      [WIDTH-1:0]   data_in,         // source domain bus
  input                    data_valid,      // source domain toggle per update
  output                   data_valid_sync, // one-cycle pulse per update
  output reg [WIDTH-1:0]   data_out
);

  wire update;

  sync_pulse #(.DEPTH(DEPTH)) valid_sync_i (
    .clock   (clock),
    .sig_in  (data_valid),
    .sig_out (update)
  );

  assign data_valid_sync = update;

  reg loaded = 1'b0;

  always @(posedge clock) begin
    if (update | ~loaded) begin
      data_out <= data_in;
      loaded   <= 1'b1;
    end
  end

endmodule


//-----------------------------------------------------------------------------
// Transfer one pulse from clk_indomain to clk_outdomain with a full
// four-phase request/acknowledge handshake.
//
//   sig_in : level in clk_indomain; asserting it queues one pulse.  It may
//            be dropped once busy deasserts (acknowledgement received).
//   sig_out: one-cycle pulse in clk_outdomain per accepted request.
//
// Replaces the previous single-flop version which crossed domains with no
// destination synchronizer at all.
//-----------------------------------------------------------------------------
module sync_handshake (
  input  clk_indomain,
  input  clk_outdomain,
  input  sig_in,
  output sig_out
);

  reg req_toggle = 1'b0;
  reg busy       = 1'b0;
  reg ack_toggle = 1'b0;

  wire ack_evt;

  sync_pulse #(.DEPTH(2)) ack_sync_i (
    .clock   (clk_indomain),
    .sig_in  (ack_toggle),
    .sig_out (ack_evt)
  );

  always @(posedge clk_indomain) begin
    if (!busy & sig_in) begin
      req_toggle <= ~req_toggle;
      busy       <= 1'b1;
    end else if (busy & ack_evt) begin
      busy <= 1'b0;
    end
  end

  wire req_evt;

  sync_pulse #(.DEPTH(2)) req_sync_i (
    .clock   (clk_outdomain),
    .sig_in  (req_toggle),
    .sig_out (req_evt)
  );

  always @(posedge clk_outdomain)
    if (req_evt) ack_toggle <= ~ack_toggle;

  assign sig_out = req_evt;

endmodule
