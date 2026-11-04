# rx2iq I/Q receive-chain test (CORDIC → dual CIC → dual variable CIC)

## Overview

The **I/Q** companion to `rx2`: same chain, but the CORDIC's I and Q
outputs are each carried through their own CIC and variable-CIC, so the
test can validate the quadrature path end-to-end and plot complex
spectra at all three capture points (CORDIC, CIC, varcic) the way the
original bench's `t.plot()` did. It is the cocotb/Python equivalent of
`sim/test_rx2IQ.py` driving the MyHDL-generated `test_rx2.v`.

## Files

| File | Role |
|---|---|
| `tb_rx2iq.sv` | DUT wrapper: `cordic` (IN_WIDTH=12, EXTRA_BITS=5) → `flushed1` gate → **two** `cic` instances (STAGES=3, DECIMATION=8, IN_WIDTH=18, ACC_WIDTH=27, OUT_WIDTH=14, one per I/Q) → `flushed2` gate → **two** `varcic` instances (STAGES=5, IN_WIDTH=14, ACC_WIDTH=37, OUT_WIDTH=16, CICRATE=8, `decimation` tied to 6'd12). As in the original bench, the Q-path `out_strobe` pins are left unconnected. |
| `test_rx2iq.py` | Python testbench: stimulus, golden model, strobes, model match, three spectra + final checks. |
| `Makefile` | cocotb/Verilator build; sources `cordic.v`, `cic.v`, `cic_comb.v`, `cic_integrator.v`, `varcic.v` from `../../rtl/radio_openhpsdr1/`. Run with `make`. |
| `../hlmodel.py` | Golden model (`RxChain` with `var=dict(..., iq=True)`), plus `find_offset_iq`. |
| `../spectrum.py` | Complex-spectrum helper (`SpectrumIQ`). |
| `rx2iq_cordic_spectrum.png`, `rx2iq_cic_spectrum.png`, `rx2iq_varcic_spectrum.png` | Output plots (git-ignored). |

## Stimulus

- **Clock:** 13.564 ns (nominal 73.728 MHz, rounded for cocotb/1 ps).
- **NCO frequency:** 5 MHz via the PLL `m2/m3` rounding
  `freq = (RX_FREQ · 1954687338 + 16777216) >> 25` = 291271111
  (≈ 4.999999998 MHz).
- **Input:** a 5.02 MHz full-scale (±2047) 12-bit sine.
- `flushed1` at input clock 20, `flushed2` at clock 64; total decimation
  8 × 12 = 96 → 768 kHz output rate.
- 128 clocks of warm-up, then capture: 8192 CORDIC samples, every
  `decimA` sample, and 2048 `decimB` complex samples. I/Q is assembled as
  `I − jQ`, the original bench's sign convention.

## Checks

1. **Decimation strobes** — `decimA_avail` every 8 clocks, `decimB_avail`
   every 96.
2. **Bit-exact golden model on both stages, both channels** — `decimA`
   and `decimB` I and Q each match `hlmodel.RxChain` exactly
   (`find_offset_iq`, max diff 0/0).
3. **Spectra** — `SpectrumIQ` with a Blackman-Harris window renders
   `rx2iq_cordic_spectrum.png`, `rx2iq_cic_spectrum.png` and
   `rx2iq_varcic_spectrum.png`. On the final varcic output:
   - The wanted tone lands at **+20 kHz** within 2 bins. (`I − jQ` flips
     the complex spectrum, so the RX−SIG = −20 kHz difference tone plots
     positive.)
   - **Spur search:** outside |f| ≤ 200 kHz the worst spur must be below
     **−22 dBc** (passing run: −30.94 dBc at 244.1 kHz), again skipping
     the known CIC zero-extension image skirt (see the `rx1` README).

## Running

```
cd sim_cocotb/rx2iq
make          # Verilator by default; builds sim_build/, runs test, writes the three PNGs
```

The single cocotb test passes (~12.6 s wall time).
