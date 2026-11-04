import os
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge

import numpy as np

# spectrum/hlmodel live in the parent sim_cocotb directory
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))
import spectrum
import hlmodel

SAMPLING_FREQ = 76800000.0
RX_FREQ = 10000000.0
SIG_FREQ = 10020000.0
CIC_DECIMATION = 8
NUM_SAMPLES = 4096          # decimated samples, like the original bench
WARMUP = 64                 # input clocks before capture starts, like original
FLUSH_AT = 20               # input clocks; original sets flushed here
IN_WIDTH = 12

CLK_PERIOD_NS = 13.022  # nominal 76.8MHz; see test_nco1 for rationale

OUT_FREQ = SAMPLING_FREQ / CIC_DECIMATION   # cic output sample rate

# Automated check limits
CARRIER_BINS = 2      # tone peak must land within this many FFT bins


@cocotb.test()
async def test_rx1(dut):

    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit='ns').start())

    # m2/m3 from the rtl pll, fs = 76.8MHz (same values as test_rx1.py)
    m2, m3 = 1876499845, 16777216
    freq = (int(RX_FREQ) * m2 + m3) >> 25
    dut.frequency.value = freq
    dut.in_data.value = 0
    dut.flushed.value = 0
    dut._log.info("Driving frequency = %d (%.6f Hz), input %.1f Hz",
                  freq, freq / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.RxChain(
        freq, in_width=IN_WIDTH, extra_bits=5,
        cic_stages=3, cic_decimation=CIC_DECIMATION,
        cic_acc_width=27, cic_out_width=14)

    def sig(i):
        # original bench: scale = (2**(IN_WIDTH-1))-1 for ampl=1.0
        return int(round(((2 ** (IN_WIDTH - 1)) - 1) *
                         np.sin(2 * np.pi * SIG_FREQ * i * dt)))

    res = np.zeros(NUM_SAMPLES)
    mdl = []

    flushed = 0
    for i in range(WARMUP):
        if i == FLUSH_AT:
            flushed = 1
            dut.flushed.value = 1
        a = sig(i)
        dut.in_data.value = a
        model.step(a, flushed)
        await FallingEdge(dut.clock)

    # Capture decimA_avail/decimA_real on the falling edge after stepping
    # the model through the same clock edge: both see the post-edge values.
    i = WARMUP
    j = 0
    strobe_cycles = []
    while j < NUM_SAMPLES:
        a = sig(i)
        dut.in_data.value = a
        _, _, cs, co = model.step(a, 1)
        await FallingEdge(dut.clock)
        if int(dut.decimA_avail.value):
            res[j] = hlmodel._s(int(dut.decimA_real.value), 14)
            mdl.append(co)
            strobe_cycles.append(i)
            j += 1
        i += 1

    # out_strobe must pulse exactly every DECIMATION clocks
    gaps = set(np.diff(strobe_cycles))
    dut._log.info("decimA_avail gaps: %s", sorted(gaps))
    assert gaps == {CIC_DECIMATION}, "out_strobe not every %d cycles" % (
        CIC_DECIMATION,)

    # Bit exact golden model check
    off, maxd = hlmodel.find_offset(res, mdl)
    dut._log.info("Model alignment offset %d (maxdiff %d)", off, maxd)
    assert maxd == 0, "decimA_real does not match golden model (maxdiff %d)" % maxd

    # Spectrum, like the original plot: real cic output at the 9.6MHz
    # output rate.  The cordic I channel holds the input sine split between
    # SIG-RX = 20kHz (wanted) and SIG+RX = 20.02MHz.  Note cic.v zero
    # extends its signed 18-bit input (concat in integrator_data[0]), so
    # negative cordic samples wrap by +2^18: the original testbench plots
    # show the resulting image skirt up to about -10 dBc.  That is the
    # behaviour of the design under test, so the automated checks pin the
    # tone/alias positions and relaxed levels.
    s = spectrum.Spectrum(res, dt * CIC_DECIMATION, window=spectrum.flattop)
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'rx1_spectrum.png')
    s.savepng(png, "rx1 CIC Output Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=90)
    s.printPeaks(peaks)

    n = len(s.sa)
    binsz = OUT_FREQ / NUM_SAMPLES   # 2343.75 Hz

    def peak_near(freq_hz, span):
        idx = int(round(freq_hz / binsz))
        lo = max(idx - span, 0)
        p = lo + int(np.argmax(s.sa[lo:idx + span + 1]))
        return p, float(s.sa[p])

    wanted = abs(RX_FREQ - SIG_FREQ)             # 20 kHz (real spectrum)
    alias = SIG_FREQ + RX_FREQ - 2 * OUT_FREQ    # 0.82 MHz after /8
    dp, carrier_db = peak_near(wanted, CARRIER_BINS)
    ap, alias_db = peak_near(abs(alias), CARRIER_BINS)
    dut._log.info("Wanted %.6f MHz: %.2f dB; alias %.6f MHz: %.2f dB "
                  "(%.2f dBc)",
                  s.binFreq(dp), carrier_db, s.binFreq(ap), alias_db,
                  alias_db - carrier_db)
    assert dp == int(round(wanted / binsz)), \
        "wanted tone not near %.1f Hz (found bin %d)" % (wanted, dp)
    assert ap == int(round(alias / binsz)), \
        "alias not near %.3f MHz (found bin %d)" % (alias / 1e6, ap)
    assert -27.0 < alias_db - carrier_db < -20.0, \
        "alias %.2f dBc outside expected %.1f..%.1f dBc window" % (
            alias_db - carrier_db, -27.0, -20.0)

    # Above the zero-extend image skirt (>3.7MHz) the spectrum must be
    # free of large narrow spurs; this catches gross regressions while
    # tolerating the known skirt.
    mask = np.ones(n, bool)
    mask[:int(3.7e6 / binsz)] = False
    spur_idx = np.flatnonzero(mask)[int(np.argmax(s.sa[mask]))]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Worst spur above 3.7MHz: %.2f dBc at %.6f MHz",
                  spur_db - carrier_db, s.binFreq(spur_idx))
    assert spur_db - carrier_db < -15.0, \
        "spur %.2f dBc at %.6f MHz exceeds limit -15.0 dBc" % (
            spur_db - carrier_db, s.binFreq(spur_idx))
