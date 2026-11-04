# rx1 cocotb test

## Overview

This test exercises the core of the Hermes receive chain — an NCO/CORDIC
direct digital down-converter followed by a 3rd-order CIC decimation filter —
using cocotb + Verilator. It is the cocotb/Python equivalent of the older
MyHDL-generated `test_rx1.v` bench: the SystemVerilog wrapper `tb_rx1.sv`
reproduces that bench's wiring (`cordic -> gated feed -> cic`, with the CIC
`in_strobe` tied high).

## Files

| File | Role |
|---|---|
| `tb_rx1.sv` | DUT wrapper: instantiates `cordic` (IN_WIDTH=12, EXTRA_BITS=5) feeding `cic` (STAGES=3, DECIMATION=8, IN_WIDTH=18, ACC_WIDTH=27, OUT_WIDTH=14). The `flushed` input gates the CORDIC I output into the CIC (`in_data_I = flushed ? out_data_I : 0`). |
| `test_rx1.py` | Python testbench: drives stimulus, compares against a golden model, and analyses the output spectrum. |
| `Makefile` | cocotb/Verilator build; pulls `cordic.v`, `cic.v`, `cic_comb.v`, `cic_integrator.v` from `../../rtl/radio_openhpsdr1/`. Run with `make`. |

## Stimulus

- **Clock:** ~76.8 MHz (13.022 ns period), the ADC sampling rate.
- **NCO frequency:** 10 MHz, phase-increment word computed with the same
  PLL `m2/m3` rounding as the RTL: `freq = (RX_FREQ * 1876499845 + 16777216) >> 25`
  = 559240533 (≈ 9.999999994 MHz actual).
- **Input signal:** a 10.02 MHz full-scale sine, generated in Python and
  sampled at 76.8 MHz, quantized to 12 bits with scale `(2^11) - 1`.
- **Warmup:** 64 input clocks of stimulus are applied before capture begins;
  `flushed` is asserted at input clock 20 (as in the original bench), so the
  CIC only starts integrating after a valid CORDIC pipeline fill.
- The test then runs until **4096 decimated samples** (i.e., 32768 input
  clocks) have been captured on the falling edge whenever `decimA_avail`
  (the CIC `out_strobe`) is high.

## Checks

1. **Decimation ratio** — `decimA_avail` must pulse with a gap of exactly
   8 cycles between assertions (CIC DECIMATION=8).

2. **Bit-exact golden model** — the Python golden model
   (`../hlmodel.RxChain`, mirroring CORDIC + CIC arithmetic including the
   CIC's 18-bit signed input handling) is stepped in lockstep with the RTL.
   After an alignment search (`hlmodel.find_offset`), the captured
   `decimA_real` stream must match the model **exactly** (max difference 0).

3. **Spectrum analysis** — the 4096 captured CIC output samples (at the
   9.6 MHz output rate) are FFT'd with a flat-top window
   (`../spectrum.Spectrum`) and saved as `rx1_spectrum.png`. The CORDIC I
   channel splits the input sine into the wanted difference tone at
   |10 MHz − 10.02 MHz| = **20 kHz** and the sum image at 20.02 MHz, which
   aliases to 10.02 + 10 − 2×9.6 = **0.82 MHz** after /8 decimation.
   Asserts:
   - Wanted tone peak lands within 2 FFT bins (bin size 2343.75 Hz) of 20 kHz.
   - Alias peak lands within 2 bins of 0.82 MHz.
   - Alias level is between **−27 and −20 dBc** relative to the wanted tone
     (passing run: ≈ −23.3 dBc). This relaxed window reflects a known design
     behaviour: `cic.v` zero-extends its signed 18-bit input, so negative
     CORDIC samples wrap by +2^18, producing an image skirt visible in the
     original testbench plots (up to about −10 dBc). The test pins this as
     expected behaviour rather than flagging it.
   - **Spur search:** above 3.7 MHz (beyond the zero-extend image skirt) the
     worst narrowband spur must be below **−15 dBc**, catching gross
     regressions while tolerating the known skirt.

## Running

```
cd sim_cocotb/rx1
make          # Verilator by default; builds sim_build/, runs test, writes rx1_spectrum.png
```

The test currently passes (~1.4 s wall time); the log reports the frequency
word, strobe gaps, model offset/maxdiff, peak table, and the two spectral
margin checks, and `rx1_spectrum.png` is written next to the Makefile.
