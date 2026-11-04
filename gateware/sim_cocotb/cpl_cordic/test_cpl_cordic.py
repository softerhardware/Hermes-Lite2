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
TX_FREQ = 24000000.0
SIG_FREQ = 12000.0
IN_WIDTH = 16
EXTRA_BITS = 5
OUT_WIDTH = 16
NUM_SAMPLES = 16384
WARMUP = 32
SIG_LEVEL = 2**15 - 1

CLK_PERIOD_NS = 13.022  # nominal 76.8MHz; see test_nco1 for rationale

# Automated check limits
CARRIER_BINS = 2      # tone peak must land within this many FFT bins
SFDR_LIMIT_DB = -70   # any other spur
GUARD_BINS = 40       # bins around a tone excluded from the spur scan


@cocotb.test()
async def test_cpl_cordic(dut):

    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit='ns').start())

    phi = int(0x7fffffff * float(TX_FREQ) / (SAMPLING_FREQ / 2))
    dut.frequency.value = phi
    dut.in_data_I.value = 0
    dut.in_data_Q.value = 0
    dut._log.info("Driving frequency = %d (%.6f Hz), input %.1f Hz",
                  phi, phi / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.CplCordic(phi, IN_WIDTH, EXTRA_BITS, OUT_WIDTH)

    def sigs(i):
        t = i * dt
        return (int(round(SIG_LEVEL * np.sin(2 * np.pi * SIG_FREQ * t))),
                int(round(SIG_LEVEL * np.cos(2 * np.pi * SIG_FREQ * t))))

    cosa = np.zeros(NUM_SAMPLES)
    cosb = np.zeros(NUM_SAMPLES)
    model_i = []
    model_q = []

    for i in range(WARMUP):
        a, b = sigs(i)
        dut.in_data_I.value = a
        dut.in_data_Q.value = b
        model.step(a, b)
        await FallingEdge(dut.clock)

    for i in range(WARMUP, WARMUP + NUM_SAMPLES):
        a, b = sigs(i)
        dut.in_data_I.value = a
        dut.in_data_Q.value = b
        mi, mq = model.step(a, b)
        model_i.append(mi)
        model_q.append(mq)
        cosa[i - WARMUP] = hlmodel._s(int(dut.out_data_I.value), OUT_WIDTH)
        cosb[i - WARMUP] = hlmodel._s(int(dut.out_data_Q.value), OUT_WIDTH)
        await FallingEdge(dut.clock)

    # Bit exact golden model check on both outputs
    di, maxi = hlmodel.find_offset(cosa, model_i)
    dq, maxq = hlmodel.find_offset(cosb, model_q)
    dut._log.info("Model alignment offset i=%d (maxdiff %d), q=%d (maxdiff %d)",
                  di, maxi, dq, maxq)
    assert maxi == 0, "out_data_I does not match golden model (maxdiff %d)" % maxi
    assert maxq == 0, "out_data_Q does not match golden model (maxdiff %d)" % maxq

    # Spectrum of out_data_I (as the original bench plotted). The drive
    # i+jq = j*exp(-j*w*t) is a negative-frequency tone at -SIG_FREQ; the
    # cordic rotates by the running NCO phase e^{+j*nco*t}, so out_data_I
    # is a single real tone at TX_FREQ - SIG_FREQ.
    s = spectrum.Spectrum(cosa, dt, window=spectrum.flattop)
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'cpl_cordic_spectrum.png')
    s.savepng(png, "CPL Cordic Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=90)
    s.printPeaks(peaks)

    n = len(s.sa)
    binsz = SAMPLING_FREQ / NUM_SAMPLES
    tone = TX_FREQ - SIG_FREQ
    idx = int(round(tone / binsz))
    lo = idx - CARRIER_BINS
    p = lo + int(np.argmax(s.sa[lo:idx + CARRIER_BINS + 1]))
    carrier_db = float(s.sa[p])
    assert abs(p - idx) <= CARRIER_BINS, "tone not near %.6f MHz (bin %d)" % (
        tone / 1e6, p)

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
