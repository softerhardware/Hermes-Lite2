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

SAMPLING_FREQ = 73728000.0
RX_FREQ = 10000000.0
SIG_FREQ = 10020000.0
CIC_DECIMATION = 8
VAR_DECIMATION = 12
NUM_SAMPLES = 2048          # decimB samples, like the original bench
WARMUP = 128                # input clocks before capture, like original
FLUSH1_AT = 20
FLUSH2_AT = 64
IN_WIDTH = 12
VAR_OUT_WIDTH = 16

CLK_PERIOD_NS = 13.564  # nominal 73.728MHz = 13.563333ns; cocotb Clock
                        # requires a period divisible by 2 ps; see test_nco1

OUT_FREQ = SAMPLING_FREQ / (CIC_DECIMATION * VAR_DECIMATION)  # 768 kHz

# Automated check limits
CARRIER_BINS = 2      # tone peak must land within this many FFT bins
SFDR_LIMIT_DB = -22   # any other spur above 200kHz (zero-extend skirt
                      # lives lower; see rx1 notes)


@cocotb.test()
async def test_rx2(dut):

    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit='ns').start())

    # m2/m3 from the rtl pll, fs = 73.728MHz (same values as test_rx2.py)
    m2, m3 = 1954687338, 16777216
    freq = (int(RX_FREQ) * m2 + m3) >> 25
    dut.frequency.value = freq
    dut.in_data.value = 0
    dut.flushed1.value = 0
    dut.flushed2.value = 0
    dut.var_decimation.value = VAR_DECIMATION
    dut._log.info("Driving frequency = %d (%.6f Hz), input %.1f Hz",
                  freq, freq / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.RxChain(
        freq, in_width=IN_WIDTH, extra_bits=5,
        cic_stages=3, cic_decimation=CIC_DECIMATION,
        cic_acc_width=27, cic_out_width=14,
        var=dict(stages=5, acc_width=39, out_width=VAR_OUT_WIDTH,
                 decimation=VAR_DECIMATION))

    def sig(i):
        return int(round(((2 ** (IN_WIDTH - 1)) - 1) *
                         np.sin(2 * np.pi * SIG_FREQ * i * dt)))

    resB = np.zeros(NUM_SAMPLES)
    mdlB = []
    resA = []
    mdlA = []

    f1 = f2 = 0
    for i in range(WARMUP):
        if i == FLUSH1_AT:
            f1 = 1
            dut.flushed1.value = 1
        if i == FLUSH2_AT:
            f2 = 1
            dut.flushed2.value = 1
        a = sig(i)
        dut.in_data.value = a
        model.step(a, f1, f2)
        await FallingEdge(dut.clock)

    # Capture on the falling edge after stepping the model through the same
    # edge: both see post-edge values (validated convention, see cordic).
    i = WARMUP
    j = 0
    strobeA = []
    strobeB = []
    while j < NUM_SAMPLES:
        a = sig(i)
        dut.in_data.value = a
        _, _, cs, co, vs, vo = model.step(a, 1, 1)
        await FallingEdge(dut.clock)
        if int(dut.decimA_avail.value):
            resA.append(hlmodel._s(int(dut.decimA_real.value), 14))
            mdlA.append(co)
            strobeA.append(i)
        if int(dut.decimB_avail.value):
            resB[j] = hlmodel._s(int(dut.decimB_real.value), VAR_OUT_WIDTH)
            mdlB.append(vo)
            strobeB.append(i)
            j += 1
        i += 1

    # strobes must pulse exactly every DECIMATION input clocks /
    # varcic every CIC_DECIMATION*VAR_DECIMATION
    gapsA = set(int(g) for g in np.diff(strobeA))
    gapsB = set(int(g) for g in np.diff(strobeB))
    dut._log.info("decimA gaps %s, decimB gaps %s", sorted(gapsA), sorted(gapsB))
    assert gapsA == {CIC_DECIMATION}, "decimA_avail not every %d cycles" % CIC_DECIMATION
    assert gapsB == {CIC_DECIMATION * VAR_DECIMATION}, \
        "decimB_avail not every %d cycles" % (CIC_DECIMATION * VAR_DECIMATION)

    # Bit exact golden model checks
    offA, maxdA = hlmodel.find_offset(resA, mdlA)
    dut._log.info("decimA model alignment offset %d (maxdiff %d)", offA, maxdA)
    assert maxdA == 0, "decimA_real does not match model (maxdiff %d)" % maxdA
    offB, maxdB = hlmodel.find_offset(resB, mdlB)
    dut._log.info("decimB model alignment offset %d (maxdiff %d)", offB, maxdB)
    assert maxdB == 0, "decimB_real does not match model (maxdiff %d)" % maxdB

    # Spectrum of decimB at the 768kHz output rate.  Same story as rx1:
    # the cic zero-extends its signed input (see rx1 test notes), so the
    # baseband shows a mirror image at RX+SIG-8*fs_out = 60kHz a few dB
    # below the wanted tone; the varcic then lowpasses heavily, leaving
    # the region above ~200kHz clean.
    s = spectrum.Spectrum(resB, dt * CIC_DECIMATION * VAR_DECIMATION,
                          window=spectrum.flattop)
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'rx2_spectrum.png')
    s.savepng(png, "rx2 VarCIC Output Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=90)
    s.printPeaks(peaks)

    n = len(s.sa)
    binsz = OUT_FREQ / NUM_SAMPLES      # 375 Hz

    def peak_near(freq_hz, span):
        idx = int(round(freq_hz / binsz))
        lo = max(idx - span, 0)
        p = lo + int(np.argmax(s.sa[lo:idx + span + 1]))
        return p, float(s.sa[p])

    wanted = abs(RX_FREQ - SIG_FREQ)    # 20 kHz in the real output spectrum
    dp, carrier_db = peak_near(wanted, CARRIER_BINS)
    dut._log.info("Wanted %.6f MHz: %.2f dB", s.binFreq(dp), carrier_db)
    assert abs(dp - int(round(wanted / binsz))) <= CARRIER_BINS, \
        "wanted tone not near %.1f Hz (found bin %d)" % (wanted, dp)

    # SFDR above the zero-extend image region: worst peak >200kHz
    mask = np.ones(n, bool)
    mask[:int(200e3 / binsz)] = False
    spur_idx = np.flatnonzero(mask)[int(np.argmax(s.sa[mask]))]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Worst spur above 200kHz: %.2f dBc at %.6f MHz",
                  spur_db - carrier_db, s.binFreq(spur_idx))
    assert spur_db - carrier_db < SFDR_LIMIT_DB, \
        "spur %.2f dBc at %.6f MHz exceeds limit %.1f dBc" % (
            spur_db - carrier_db, s.binFreq(spur_idx), SFDR_LIMIT_DB)
