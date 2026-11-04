# cocotb Testbenches

## Overview

This directory holds 22 self-contained cocotb testbenches for the gateware,
one per subdirectory, covering the RX DSP chain (`cic`, `cordic`, `cpl_cordic`,
`mix1`, `mixtx1`, `nco1`, `rx1`, `rx2`, `rx2iq`, `sincos`) and the Ethernet
stack (`eth_arp`, `eth_crc32`, `eth_icmp`, `eth_ip_recv`, `eth_ip_send`,
`eth_mac_recv`, `eth_mac_send`, `eth_mdio`, `eth_network`, `eth_rgmii`,
`eth_udp_recv`, `eth_udp_send`).  Each subdirectory has its own `Makefile`,
its own `README.md` describing what the test does, and its own `sim_build/`
scratch directory; the `Makefile` here only fans out to them.  Everything is
driven by Verilator as the simulator, with cocotb's VPI interface loading the
Python tests.

Three shared Python modules live at this level and are imported by the tests
through a `sys.path` append: `hlmodel.py` (golden fixed-point models of the
DSP blocks), `spectrum.py` (FFT spur/noise measurement helpers used for the
DSP pass/fail margins), and `ethcommon.py` (byte-level TX/RX stream drivers
shared by the Ethernet benches).

## Setting up the environment

Two things must be on `PATH`: a Python with cocotb installed, and Verilator
with its runtime (plus a C++ compiler, which Verilator uses to build the model).
On this machine that is the repository's `hl2_venv` plus a Verilator 5.053
devel build; tested versions are:

| Component | Version used |
| --- | --- |
| Python | 3.14.7 |
| cocotb | 2.1.0 |
| Verilator | 5.053 devel (`v5.052-603`) |
| g++ | 11.5.0 |
| GNU Make | 4.3 |

From the repository root, activate the environment:

```sh
source hl2_venv/bin/activate
cd gateware/sim_cocotb
```

To recreate the venv from scratch (this one was built with `uv`, but plain
`venv` + `pip` works the same):

```sh
uv venv --python 3.14 hl2_venv            # or: python3 -m venv hl2_venv
uv pip install --python hl2_venv/bin/python \
    cocotb numpy scipy matplotlib pyfftw  # or: hl2_venv/bin/pip install ...
```

`cocotb` is all the testbenches need to run; `numpy`, `scipy`, `matplotlib`
and `pyfftw` are used by the DSP tests through `spectrum.py`/`hlmodel.py`
(FFT spur measurement and plots).  The Ethernet tests import only `cocotb`.

Three Ethernet benches instantiate Altera primitives and additionally need the
Quartus simulation library `altera_mf.v`; their Makefiles reference it at a
hardcoded path (`/home/shaynal/altera_lite/25.1std/quartus/eda/sim_lib/`).  If
your Quartus lives elsewhere, edit that line in `eth_icmp/Makefile`,
`eth_network/Makefile` and `eth_rgmii/Makefile`; every other test needs no
Quartus at all.

## Running

From this directory:

```sh
make              # run everything, serially (~1 min 20 s from clean)
make -j8          # the same, several benches at once (~20 s from clean)
make rx2 eth_arp  # only these two testbenches
make summary      # re-print the pass/fail tally of the last run
make clean        # remove test-logs/ and every sim_build/, dump.vcd, ...
```

`make` prints one line per testbench and a tally, and redirects each
testbench's full output to `test-logs/<dir>.log` (look there when a line says
`FAIL`):

```
== cic
PASS cic
== cordic
PASS cordic
...
== rx2iq
PASS rx2iq

22/22 test directories passed
```

A failing testbench does not cut the run short; the tally is what exits
non-zero.  To work on one bench directly, either use the per-directory target
above or `cd` into it and run plain `make` — every subdirectory's Makefile is
the standard cocotb one, so all cocotb knobs work, e.g.:

```sh
cd eth_arp
make                                   # run all tests in this bench
make TESTCASE=test_arp_request_reply   # run just one cocotb test
make clean
```

(Cocotb prints a deprecation warning about `TESTCASE` vs `COCOTB_TEST_FILTER`;
the `TESTCASE=` make variable is still the documented cocotb Makefile knob and
works.)

One quirk: `make -C eth_icmp` from outside fails (`No rule to make target
'.../rtl/sync.v'`) because that Makefile builds its RTL paths from the
environment `PWD` and doesn't set it.  Use `cd eth_icmp && make`, or the
top-level `make eth_icmp`, which passes the right `PWD`.  Waveforms: 18 of the
22 Makefiles already pass `--trace` and write `dump.vcd` in the test directory;
for the four that don't (`eth_icmp`, `eth_mac_send`, `eth_network`,
`eth_rgmii`), run `make clean && make EXTRA_ARGS=--trace` (clean first: the
trace has to be in at compile time).  The benches are written for Verilator;
`SIM=icarus` does not work — iverilog rejects constructs in the RTL and the
`--trace` argument these Makefiles pass.

## Expected results

All 22 test directories pass on a clean checkout with the environment above:
73 cocotb tests in total, every one reported as `PASS=n FAIL=0 SKIP=0` in its
`test-logs/<dir>.log`.  Wall time from a clean tree is roughly 1 min 20 s
serial, ~20 s with `-j8`; most benches build and run in about a second, the
slow ones are `eth_network` ~13 s, `rx2iq` ~11 s, `rx2` ~11 s.  The DSP benches
don't just run the RTL, they compare against golden models and FFT-based
spectra — each subdirectory's `README.md` quotes the margins and the numbers
actually measured, e.g. `nco1` requires the NCO output spur to stay under
−80 dBc (measured: −111.8 dBc), and `eth_icmp` builds full ICMP echo
request/reply frames and checks the generated reply byte for byte.  Typical
single-test output:

```
** testcic.test_0                 PASS        5201.49           0.00    1963005.68  **
** TESTS=1 PASS=1 FAIL=0 SKIP=0               5201.49           0.00    1775258.62  **
```

## Files

| Path | Purpose |
| --- | --- |
| `Makefile` | fan-out runner for all 22 benches (`make`, `make -j8`, `make summary`, `make clean`) |
| `*/Makefile`, `*/test_*.py`, `*/README.md` | one self-contained testbench per subdirectory, with its own documentation |
| `hlmodel.py` | golden fixed-point models of the DSP blocks, used by the DSP benches |
| `spectrum.py` | FFT spur/noise measurement and plot helpers (`*_spectrum.png`) |
| `ethcommon.py` | shared Ethernet TX/RX stream drivers |
| `test-logs/` | per-bench logs and `.pass` markers written by the top-level Makefile (git-ignored) |
| `.gitignore` | keeps build artifacts (`sim_build/`, `dump.vcd`, `results.xml`, ROM `.txt` copies, plots) out of git |
