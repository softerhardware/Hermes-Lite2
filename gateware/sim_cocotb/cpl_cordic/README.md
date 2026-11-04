# cpl_cordic spectrum + golden-model test

## Overview

Verifies the **complex** CORDIC rotate-and-multiply `cpl_cordic.v`
(`rtl/radio_openhpsdr1/`) — the transmitter-side quadrature NCO/mixer in
`radio.v`, which rotates a complex 16-bit input by a running 32-bit
frequency word. The test drives a complex low-frequency tone through the
rotator and checks the RTL is **bit-exact** against the Python golden
model `hlmodel.CplCordic`, then checks the output spectrum is a clean
single tone. Cocotb equivalent of the old myhdl `sim/test_cpl_cordic.py`.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=tb_cpl_cordic`, source `cpl_cordic.v`. `-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC` waive benign width lint on the RTL's `frequency == 1'b0` / `phase <= 1'b0` comparisons. |
| `tb_cpl_cordic.sv` | Wrapper pinning `IN_WIDTH=16`, `EXTRA_BITS=5` and, importantly, `OUT_WIDTH=16` — the same explicit override the original myhdl bench used (the RTL default `OUT_WIDTH` is the raw 23-bit `WR` datapath). |
| `test_cpl_cordic.py` | Drives the stimulus, runs the model, checks the FFT. |
| `../spectrum.py` | FFT / windowing / peak-finding helper. |
| `../hlmodel.py` | Python golden models (`CplCordic`, `find_offset`, `_s`). |
| `cpl_cordic_spectrum.png` | Output plot written next to the Makefile (git-ignored). |

## Stimulus

- Clock 13.022 ns (nominal 76.8 MHz; rounded for 1 ps precision).
- `frequency = 0x7fffffff · 24 MHz / (fs/2)` → 1342177279
  (≈ 23.99999998 MHz).
- `in_data_I` / `in_data_Q` = a complex tone at `SIG_FREQ = 12 kHz` with
  amplitude 2¹⁵−1: `I = A·sin(ωt)`, `Q = A·cos(ωt)` — i.e. a
  negative-frequency rotation of the input vector.
- 32 clocks of warm-up, then 16384 samples of both 16-bit signed outputs
  captured on falling edges, model stepped in lockstep.

## Checks

1. **Bit-exact golden model on both outputs** — after the alignment
   search, `out_data_I` and `out_data_Q` must match the model exactly
   (passing run: offset −1, max diff 0 on both channels).
2. **Tone location** — rotating a −12 kHz input by the +24 MHz NCO phase
   leaves a single real tone at `TX_FREQ − SIG_FREQ`; with the driven
   frequency word (≈ 23 999 987.98 Hz) that is **23.987988 MHz** = FFT
   bin 5117, and the peak must land within 2 bins (bin size 4687.5 Hz;
   passing run: 23.983010 MHz).
3. **SFDR** — worst peak outside ±40 bins of the tone and of DC
   < −70 dBc (passing run: −96.39 dBc). Catches CORDIC iteration/rounding
   nonlinearity and pipeline mistakes.

## Running

```bash
cd sim_cocotb/cpl_cordic
make          # Verilator + cocotb; ~2 s test time, writes cpl_cordic_spectrum.png
```
