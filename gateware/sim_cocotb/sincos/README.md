# sincos ROM-table lookup test

## Overview

Characterises the coarse/fine ROM sin/cos generator `sincos.v`
(`rtl/nco/`) — the table-lookup oscillator front end of the Hermes-Lite 2
NCO. The test sweeps 20000 consecutive angles from 0 through the DUT and
compares the outputs against `numpy`'s `cos`/`sin`, checking that the
*power* of each output stays within 1% of unity: since a correct
sin/cos pair satisfies sin² + cos² = 1, tracking |cos²_gold − cos²_calc|
catches ROM bit errors, wrong interpolation in the fine table, and
sign-handling bugs without needing the model to be bit-exact.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=sincos`, sources `sincos.v`, `coarserom.v`, `finerom.v`, `primitives/sim/multipliers.v`. Copies the ROM images into the run dir (see Running). |
| `test_sincos.py` | The test itself. |
| `sincos_coarse.txt`, `sin_fine.txt` | ROM images copied from `rtl/nco/` by the Makefile's `%.txt` rule (`coarserom`/`finerom` load them with `$readmemb` relative paths). Git-ignored. |

## What it does

1. Starts a 10 ns (100 MHz) clock on `clk`; drives `angle` directly.
2. For each angle `a` in 0..19999 (the full circle is 2²⁰ angles) waits
   6 clocks for the interpolation pipeline to settle, then unpacks `cos`
   and `sin`: the 19-bit outputs are sign-magnitude (bit 18 = sign,
   bits 17:0 = magnitude scaled so full scale is 2¹⁸−1).
3. Compares against `cos/sin(2π·(a+0.5)/2²⁰)` — the +0.5 samples the
   centre of each table step.

## Checks

- **Max squared-value error** — `|cos²_gold − cos²_calc| < 0.01` for
  every angle (the threshold the original myhdl test flagged on). Only
  the cos channel is checked; the sin error is implicitly bounded.
- Average error and max diff are printed. Passing run: average 0.000006,
  max diff 0.000018 — comfortably inside the limit.

## Running

```bash
cd sim_cocotb/sincos
make          # Verilator + cocotb; ~1.2 s test time
```

The Makefile's `CUSTOM_SIM_DEPS` copies `sincos_coarse.txt` and
`sin_fine.txt` next to the Makefile before simulating. `--trace` is
enabled, so `dump.vcd` is produced.
