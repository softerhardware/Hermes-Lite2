// ============================================================================
// clk_config.vh - Single source of truth for CLK_FREQ-derived DSP constants.
//
// Include ONCE, after parameter CLK_FREQ is defined, e.g. in radio.v:
//
//     parameter CLK_FREQ = 76800000;
//     `include "clk_config.vh"
//
// Defines: M2, CICRATE, GBITS, RRRR, RATE48, RATE96, RATE192, RATE384
//
// Supported base-rate identity (48 ksps output):
//     CLK_FREQ == CICRATE * RATE48 * 8 * 48000
// An elaboration-time check below flags unsupported clocks.
// ============================================================================

// NCO phase increment constant: M2 = round(2^57 / CLK_FREQ).
// freq[Hz] * M2 >> 25 is the 32-bit phase increment (see radio.v).
localparam [63:0] M2_MATH_WIDE = (64'd144115188075855872 + CLK_FREQ/2) / CLK_FREQ;
localparam [31:0] M2_MATH = M2_MATH_WIDE[31:0];

// Some oscillator frequencies carry measured calibration offsets that must
// NOT be recomputed from the formula; they are preserved verbatim.  For
// 76.8 MHz and the default (73.728 MHz) the pure math reproduces the
// previously hardcoded constants (1876499845 / 1954687338).
localparam [31:0] M2 =
    (CLK_FREQ == 32'd61440000) ? 32'd2345640077 :  // OSC 61440000-400 Hz
    (CLK_FREQ == 32'd79872000) ? 32'd1804326773 :  // measured osc offset
    M2_MATH;

// Fixed CIC decimation ahead of the variable CIC, per supported clock:
//   61.44 MHz -> 10, 79.872 MHz -> 13, 76.8 MHz -> 5, default(73.728) -> 8
localparam [5:0] CICRATE =
    (CLK_FREQ == 32'd61440000) ? 6'd10 :
    (CLK_FREQ == 32'd79872000) ? 6'd13 :
    (CLK_FREQ == 32'd76800000) ? 6'd05 : 6'd08;

// TX interpolator gain normalization count: RRRR = CLK_FREQ / 384000
localparam [31:0] RRRR_WIDE = CLK_FREQ / 32'd384000;
localparam [9:0] RRRR = RRRR_WIDE[9:0];

// TX interpolator growth normalization bits
localparam GBITS = (CLK_FREQ == 32'd61440000) ? 30 : 31;

// Decimation rates through cic(CICRATE) x varcic(rate) x fir(/8)
localparam [31:0] RATE48_WIDE = CLK_FREQ / (CICRATE * 32'd384000);
localparam [5:0] RATE48  = RATE48_WIDE[5:0];                    //  48 ksps
localparam [5:0] RATE96  =  RATE48 >> 1;                      //  96 ksps
localparam [5:0] RATE192 =  RATE96  >> 1;                     // 192 ksps
localparam [5:0] RATE384 =  RATE192 >> 1;                     // 384 ksps

// Elaboration-time sanity check of the rate identity
initial begin
  if ((CICRATE * RATE48 * 32'd384000) != CLK_FREQ) begin
    $display("ERROR: clk_config: CLK_FREQ=%0d unsupported; requires CICRATE*RATE48*8*48000 == CLK_FREQ", CLK_FREQ);
    $finish;
  end
end
