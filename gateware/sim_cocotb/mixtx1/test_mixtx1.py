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
RX_FREQ = 17280000.0
SIG_FREQ = 100000.0
NUM_SAMPLES = 16384
WARMUP = 32
SIG_LEVEL = 2**17 - 1

CLK_PERIOD_NS = 13.022  # nominal 76.8MHz; see test_nco1 for rationale

# Automated check limits
CARRIER_BINS = 3      # tone peak must land within this many FFT bins
SFDR_LIMIT_DB = -70   # any other spur
GUARD_BINS = 30       # bins around a peak excluded from the spur scan


@cocotb.test()
async def test_mixtx1(dut):

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit='ns').start())

    phi = int(0x7fffffff * float(RX_FREQ) / (SAMPLING_FREQ / 2))
    dut.rst.value = 0
    dut.phi.value = phi
    dut.i_sig.value = 0
    dut.q_sig.value = 0
    dut._log.info("Driving phi = %d (%.6f Hz), input signal %.1f Hz",
                  phi, phi / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.Mixtx1(phi)

    def sigs(i):
        t = i * dt
        return (int(round(SIG_LEVEL * np.sin(2 * np.pi * SIG_FREQ * t))),
                int(round(SIG_LEVEL * np.cos(2 * np.pi * SIG_FREQ * t))))

    # The original myhdl bench captured q_result into a real sequence;
    # keep i_result too for the golden model comparison.
    res_i = np.zeros(NUM_SAMPLES)
    res_q = np.zeros(NUM_SAMPLES)
    model_i = []
    model_q = []

    for i in range(WARMUP):
        a, b = sigs(i)
        dut.i_sig.value = a
        dut.q_sig.value = b
        model.step(a, b)
        await FallingEdge(dut.clk)

    for i in range(WARMUP, WARMUP + NUM_SAMPLES):
        a, b = sigs(i)
        dut.i_sig.value = a
        dut.q_sig.value = b
        mi, mq = model.step(a, b)
        model_i.append(mi)
        model_q.append(mq)
        res_i[i - WARMUP] = hlmodel._s(int(dut.i_result.value), 13)
        res_q[i - WARMUP] = hlmodel._s(int(dut.q_result.value), 13)
        await FallingEdge(dut.clk)

    # Bit exact golden model check (allowing for pipeline/capture skew)
    di, maxi = hlmodel.find_offset(res_i, model_i)
    dq, maxq = hlmodel.find_offset(res_q, model_q)
    dut._log.info("Model alignment offset i=%d (maxdiff %d), q=%d (maxdiff %d)",
                  di, maxi, dq, maxq)
    assert maxi == 0, "i_result does not match golden model (maxdiff %d)" % maxi
    assert maxq == 0, "q_result does not match golden model (maxdiff %d)" % maxq

    # Spectrum of q_result (as the original bench plotted). With the complex
    # exponential drive i+jq = e^{j(wt+pi/2)}, the tx mixer output
    # q_result = i*sin + q*cos = cos(wt - nco) is a single real tone at
    # RX_FREQ - SIG_FREQ.
    s = spectrum.Spectrum(res_q, dt, window=spectrum.flattop)
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'mixtx1_spectrum.png')
    s.savepng(png, "Mix TX Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=100)
    s.printPeaks(peaks)

    n = len(s.sa)
    binsz = SAMPLING_FREQ / NUM_SAMPLES
    tone = RX_FREQ - SIG_FREQ
    idx = int(round(tone / binsz))
    lo = idx - CARRIER_BINS
    p = lo + int(np.argmax(s.sa[lo:idx + CARRIER_BINS + 1]))
    carrier_db = float(s.sa[p])
    assert p == idx, "tone not at %.6f MHz (found bin %d, expected %d)" % (
        tone / 1e6, p, idx)

    # SFDR: worst peak outside the tone main lobe and DC
    mask = np.ones(n, bool)
    mask[max(0, p - GUARD_BINS):p + GUARD_BINS + 1] = False
    mask[0:GUARD_BINS + 1] = False
    spur_idx = np.flatnonzero(mask)[int(np.argmax(s.sa[mask]))]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Tone %.6f MHz: %.2f dB; worst other spur %.2f dBc at %.6f MHz",
                  s.binFreq(p), carrier_db, spur_db - carrier_db,
                  s.binFreq(spur_idx))
    assert spur_db - carrier_db < SFDR_LIMIT_DB, \
        "spur %.2f dBc at %.6f MHz exceeds limit %.1f dBc" % (
            spur_db - carrier_db, s.binFreq(spur_idx), SFDR_LIMIT_DB)
