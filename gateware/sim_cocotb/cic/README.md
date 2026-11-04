# CIC filter smoke test

## Overview

The most basic bring-up test for the 3-stage CIC decimation filter
`cic.v`. Unlike the other DSP tests in this directory there is no
golden model and no spectrum check: the DUT is simply clocked with a
sine-wave input for 400 cycles. The test passes if the simulation
compiles, runs and finishes without an error — i.e. it proves the CIC
integrator/comb chain elaborates and runs cleanly under Verilator and
produces a VCD trace for manual inspection.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=cic`, sources `cic.v`, `cic_comb.v`, `cic_integrator.v`. |
| `testcic.py` | The test itself (note: no underscore in the filename, unlike most other tests here). |

## What it does

1. Starts a 20 ns (50 MHz) clock on `clock`.
2. Deasserts `rst_all`, ties `in_strobe` high, drives `in_data` with a
   full-scale-ish sine sampled at an arbitrary frequency.
3. Runs 400 falling clock edges.
4. No assertions — completion is the check.

## Running

```bash
cd sim_cocotb/cic
make          # builds with Verilator and runs the test
make SIM=verilator WAVES=1   # additionally dumps FST waves
```

Produces `sim_build/` and a VCD trace (tracing enabled by `EXTRA_ARGS`).
