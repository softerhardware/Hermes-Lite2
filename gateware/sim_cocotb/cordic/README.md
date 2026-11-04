# CORDIC NCO spectrum test

## Overview

Verifies the CORDIC-based NCO/mixer `cordic.v` — the Hermes-Lite 2
receiver's numerically-controlled oscillator + mixer front end — as a
12-bit-input, 5-extra-bit (18-bit output) quadrature oscillator/mixer.
The design is driven with a real sine at 20.59 MHz while the CORDIC
rotates by a 32-bit frequency word for 20.48 MHz, so the I output is a
pure 110 kHz complex tone; a clean spectrum proves the pipeline
sign-extension, rounding and pipelining are correct.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=tb_cordic`, source `cordic.v`. |
| `tb_cordic.sv` | Thin wrapper pinning `IN_WIDTH=12`, `EXTRA_BITS=5` (explicit override matching the original myhdl test). |
| `test_cordic.py` | Drives the stimulus and checks the FFT. |
| `../spectrum.py` | FFT / windowing / peak-finding helper (shared by all DSP tests). |
| `../hlmodel.py` | Python golden model library (imported here for `_s` sign-extension helper). |

## Stimulus

- Clock 13.022 ns (76.8 MHz nominal; rounded for 1 ps simulator precision).
- `frequency = round(2^32 · 20.48 MHz / 76.8 MHz)` → 2726299238 → exact 20 MHz step
  of 76.8/2^32 Hz; combined with the input sine, the output tone lands at
  `SIG_FREQ − RX_FREQ = 110 kHz`.
- `in_data` = full-scale (±2047) sine at 20.59 MHz, one sample per clock.
- 32 clocks of warm-up, then 16384 captured samples.

## Checks

1. **Tone location** — the FFT peak must sit within 2 bins of 110 kHz.
2. **SFDR** — the worst peak outside a ±30-bin guard band around the
   carrier and outside 30 bins of DC must be < −70 dBc. Catches CORDIC
   iteration/rounding nonlinearity, missing pipeline registers, etc.

A `cordic_spectrum.png` plot is written next to the Makefile on every run.

## Running

```bash
cd sim_cocotb/cordic
make          # Verilator + cocotb; test prints PASS/FAIL
```
