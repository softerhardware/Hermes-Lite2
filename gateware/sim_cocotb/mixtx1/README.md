# mixtx1 spectrum + golden-model test

## Overview

Verifies the transmit up-converting mixer `mixtx1.v` (`rtl/nco/`) — an
`nco1` quadrature oscillator multiplying 18-bit signed I/Q baseband down
to 13-bit signed results. As in `mix1`, the RTL is checked **bit-exact**
against the Python golden model `hlmodel.Mixtx1`, then the spectrum of
`q_result` is checked for a clean single tone. Cocotb equivalent of the
old myhdl `sim/test_mixtx1.py`.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=mixtx1` (the DUT is used directly, no wrapper), sources `mixtx1.v`, `nco1.v`, `sincos.v`, `coarserom.v`, `finerom.v`, `multipliers.v`. Copies the ROM images into the run dir. |
| `test_mixtx1.py` | Drives the stimulus, runs the model, checks the FFT. |
| `../spectrum.py` | FFT / windowing / peak-finding helper. |
| `../hlmodel.py` | Python golden models (`Mixtx1`, `find_offset`, `_s`). |
| `mixtx1_spectrum.png` | Output plot written next to the Makefile (git-ignored). |

## Stimulus

- Clock 13.022 ns (nominal 76.8 MHz).
- `phi = 0x7fffffff · 17.28 MHz / (fs/2)` → 966367641 (≈ 17.28 MHz),
  `rst` low.
- `i_sig` / `q_sig` = a quadrature tone at `SIG_FREQ = 100 kHz` with
  amplitude 2¹⁷−1: `i = A·sin(ωt)`, `q = A·cos(ωt)`.
- 32 clocks of warm-up, then 16384 samples of both 13-bit signed results
  captured on falling edges, with the model stepped in lockstep.

## Checks

1. **Bit-exact golden model** — `i_result` and `q_result` each match the
   model exactly after alignment (passing run: offset 0, max diff 0).
2. **Tone location** — with the drive `i+jq = e^{j(ωt+π/2)}`,
   `q_result = i·sin + q·cos` is a single real tone at
   `RX_FREQ − SIG_FREQ = 17.18 MHz`; the peak must land on its exact FFT
   bin (passing run: 17.1776 MHz).
3. **SFDR** — worst peak outside ±30 bins of the tone and of DC
   < −70 dBc (passing run: −87.93 dBc).

## Running

```bash
cd sim_cocotb/mixtx1
make          # Verilator + cocotb; ~1.4 s test time, writes mixtx1_spectrum.png
```
