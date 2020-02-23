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


// Debounce with immediate response if last signal stabilized
module debounce(clean_pb, pb, clk, msec_pulse);

output clean_pb;
input pb, clk, msec_pulse;

logic   [5:0] pb_history;
logic         clean_pb;

logic         stable;

always @ (posedge clk) begin
  if (msec_pulse) begin
    pb_history <= {pb_history[4:0], pb};
    if (stable) clean_pb <= pb;
  end
end

assign stable = (&pb_history) | (|pb_history);


endmodule