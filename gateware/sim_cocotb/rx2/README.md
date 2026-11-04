# rx2 receive-chain test (CORDIC → CIC → variable CIC)

## Overview

Exercises the full Hermes-Lite 2 receive chain used by the
`radio_openhpsdr1` build: the CORDIC DDC feeding a fixed 3-stage CIC
decimator whose output then runs through a **variable-decimation** CIC.
It is the cocotb/Python equivalent of the MyHDL-generated
`sim/test_rx2.v` bench: the wrapper reproduces that bench's wiring and
parameters, the golden model mirrors the arithmetic, and the decimated
output is spectrum-analysed. Unlike `rx1` this bench adds the `varcic`
stage and a second flush gate.

## Files

| File | Role |
|---|---|
| `tb_rx2.sv` | DUT wrapper: `cordic` (IN_WIDTH=12, EXTRA_BITS=5) → `flushed1` gate → `cic` (STAGES=3, DECIMATION=8, IN_WIDTH=18, ACC_WIDTH=27, OUT_WIDTH=14) → `flushed2` gate → `varcic` (STAGES=5, IN_WIDTH=14, ACC_WIDTH=39, OUT_WIDTH=16, CICRATE=8). |
| `test_rx2.py` | Python testbench: drives stimulus, steps the golden model, checks strobes, model match and spectrum. |
| `Makefile` | cocotb/Verilator build; pulls `cordic.v`, `cic.v`, `cic_comb.v`, `cic_integrator.v`, `varcic.v` from `../../rtl/radio_openhpsdr1/`. Run with `make`. |
| `../hlmodel.py` | Golden model (`RxChain` with a `var` sub-model). |
| `../spectrum.py` | FFT / windowing / peak-finding helper. |
| `rx2_spectrum.png` | Output plot written next to the Makefile (git-ignored). |

## Stimulus

- **Clock:** 13.564 ns (nominal 73.728 MHz = 13.563333 ns, rounded so
  cocotb's clock divides evenly into the 1 ps simulator precision).
- **NCO frequency:** 10 MHz, phase word built with the same PLL `m2/m3`
  rounding as the RTL: `freq = (RX_FREQ · 1954687338 + 16777216) >> 25`
  = 582542222 (≈ 9.999999996 MHz).
- **Input:** a 10.02 MHz full-scale (±2047) 12-bit sine, one sample per
  clock.
- **Flush gates:** `flushed1` asserted at input clock 20 (gates the
  CORDIC I output into the CIC) and `flushed2` at clock 64 (gates the CIC
  output into the varcic), matching the original bench.
- `var_decimation = 12`, so total decimation is 8 × 12 = 96 and the final
  output rate is 768 kHz.
- 128 input clocks of warm-up, then capture until **2048 `decimB`
  samples** have been produced (also recording every `decimA` sample).

## Checks

1. **Decimation strobes** — `decimA_avail` pulses exactly every 8 input
   clocks and `decimB_avail` exactly every 96.
2. **Bit-exact golden model on both stages** — `decimA_real` (14-bit) and
   `decimB_real` (16-bit) each match `hlmodel.RxChain` exactly after the
   alignment search (max diff 0, offset 0).
3. **Spectrum** — the 2048 varcic output samples (768 kHz rate) are
   FFT'd with a flat-top window and saved as `rx2_spectrum.png`. Asserts:
   - The wanted tone at |RX − SIG| = **20 kHz** lands within 2 FFT bins
     (bin size 375 Hz).
   - **Spur search:** above 200 kHz the worst narrowband spur must be
     below **−22 dBc** (passing run: −26.26 dBc at 259.6 kHz). The 200 kHz
     floor skips the region where the known `cic.v` signed-input
     zero-extension image skirt lives — the same behaviour documented in
     the `rx1` README; the varcic's stopband makes everything above it
     clean.

## Running

```
cd sim_cocotb/rx2
make          # Verilator by default; builds sim_build/, runs test, writes rx2_spectrum.png
```

The single cocotb test passes (~10 s wall time); the log reports the
frequency word, both strobe gap sets, both model offsets/maxdiffs, the
peak table and the spur margin.
