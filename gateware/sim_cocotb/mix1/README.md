# mix1 spectrum + golden-model test

## Overview

Verifies the receiver mixer `mix1.v` (`rtl/nco/`) — an `nco1` quadrature
oscillator multiplying a 12-bit real ADC sample down to 18-bit signed
I/Q. Two things are proven: the RTL is **bit-exact** against the Python
golden model `hlmodel.Mix1` (which reimplements the ROM interpolation,
rounding and pipelining), and the resulting spectrum has good image and
spur behaviour. The cocotb equivalent of the old myhdl `sim/test_mix1.py`.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=tb_mix1`, sources `mix1.v`, `nco1.v`, `sincos.v`, `coarserom.v`, `finerom.v`, `multipliers.v`. Copies the ROM images into the run dir. |
| `tb_mix1.sv` | Wrapper that instantiates `mix1` with default `CALCTYPE=3` and defines the undeclared implicit net `clk_2x` (tying it to `clk`) so Verilator elaborates the way iverilog's `-g2012` let it float. |
| `test_mix1.py` | Drives the stimulus, runs the model, checks the FFT. |
| `../spectrum.py` | FFT / windowing / peak-finding helper. |
| `../hlmodel.py` | Python golden models (`Mix1`, `find_offset`, `_s`). |
| `mix1_spectrum.png` | Output plot written next to the Makefile (git-ignored). |

## Stimulus

- Clock 13.022 ns (nominal 76.8 MHz; rounded for 1 ps precision).
- `phi = 0x7fffffff · 24 MHz / (fs/2)` → 1342177279 (≈ 23.99999998 MHz).
- `adc` = full-scale (±2047) real sine at `SIG_FREQ = 24 006 123 Hz`, one
  sample per clock, `rst` low.
- 32 clocks of warm-up, then 16384 complex samples of
  `i_data + j·q_data` captured on falling edges; the model is stepped in
  lockstep and then run 64 extra clocks so its pipeline drains.

## Checks

1. **Bit-exact golden model** — after an alignment search
   (`hlmodel.find_offset`) both `i_data` and `q_data` must match the
   model exactly (max diff 0; passing run aligns at offset 0).
2. **Downconversion** — a real input tone splits in half: the wanted
   difference tone at −(SIG−RX) = **−6123 Hz** and the sum image at
   SIG+RX−fs = **−28.7953 MHz**. Both peaks must land on their exact FFT
   bin (bin size 4687.5 Hz).
3. **Equal gain in both halves** — the upper sideband within 1 dB of the
   wanted tone (passing run: 0.00 dBc).
4. **SFDR** — worst peak outside ±30 bins of either tone and of DC
   < −70 dBc (passing run: −93.98 dBc).

## Running

```bash
cd sim_cocotb/mix1
make          # Verilator + cocotb; ~0.9 s test time, writes mix1_spectrum.png
```
