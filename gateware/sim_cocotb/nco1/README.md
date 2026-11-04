# nco1 spectrum test

## Overview

Verifies the full numerically-controlled oscillator `nco1.v`
(`rtl/nco/`) — a 32-bit phase accumulator feeding the `sincos` ROM
chain — as a quadrature oscillator. The accumulator is loaded with a
frequency word for ~7.078 MHz at a 76.8 MHz sample rate and 16384
complex output samples are captured one per clock; a constant unit
envelope plus a spur-free FFT proves the accumulator, the coarse/fine
ROM interpolation and the output sign-magnitude coding are all correct.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=nco1`, sources `nco1.v`, `sincos.v`, `coarserom.v`, `finerom.v`, `primitives/sim/multipliers.v`. Copies the ROM images into the run dir. |
| `test_nco1.py` | Drives the stimulus and analyses the FFT. |
| `../spectrum.py` | FFT / windowing / peak-finding helper (shared by all DSP tests). |
| `nco1_spectrum.png` | Output plot written next to the Makefile on every run (git-ignored). |

## Stimulus

- Clock 13.022 ns (nominal 76.8 MHz; rounded for 1 ps simulator
  precision — the RTL is edge-driven so this is harmless).
- `phi = 0x7fffffff · RX_FREQ / (fs/2)` with `RX_FREQ = 7078132 Hz`
  → 395837831, i.e. 7.078131992 MHz; chosen so the tone lands exactly on
  FFT bin 1510 (bin size 76.8 MHz / 16384 = 4687.5 Hz).
- `rst` held low; 32 clocks of pipeline warm-up, then 16384 complex
  samples captured on falling edges. Outputs are sign-magnitude 19-bit
  (bit 18 sign, magnitude / (2¹⁸−1)).

## Checks

1. **Constant envelope** — every sample magnitude within 0.1% of full
   scale (passing run: min 0.999991, max 1.000006).
2. **Carrier location** — the FFT peak within 2 bins of bin 1510.
3. **SFDR** — worst peak outside a ±25-bin guard band around the carrier
   < −80 dBc (passing run: −111.8 dBc).
4. **DC offset** — worst peak within ±3 bins of DC < −80 dBc (passing
   run: −152.8 dBc).

## Running

```bash
cd sim_cocotb/nco1
make          # Verilator + cocotb; ~0.3 s test time, writes nco1_spectrum.png
```
