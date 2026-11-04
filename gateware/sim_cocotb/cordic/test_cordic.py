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
RX_FREQ = 20480000.0
SIG_FREQ = 20590000.0
IN_WIDTH = 12
EXTRA_BITS = 5
NUM_SAMPLES = 16384
WARMUP = 32
SIG_LEVEL = 2**(IN_WIDTH - 1) - 1

CLK_PERIOD_NS = 13.022  # nominal 76.8MHz; see test_nco1 for rationale

# Automated check limits
CARRIER_BINS = 2      # tone peak must land within this many FFT bins
SFDR_LIMIT_DB = -70   # any other spur
GUARD_BINS = 30       # bins around a peak excluded from the spur scan


@cocotb.test()
async def test_cordic(dut):

    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit='ns').start())

    # m2/m3 from the rtl pll, fs = 76.8MHz
    m2, m3 = 1876499845, 16777216
    freq = (int(RX_FREQ) * m2 + m3) >> 25
    dut.frequency.value = freq
    dut.in_data.value = 0
    dut._log.info("Driving frequency = %d (%.6f Hz), input %.1f Hz",
                  freq, freq / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.Cordic(freq, IN_WIDTH, EXTRA_BITS)

    def sample(i):
        return int(round(SIG_LEVEL * np.cos(2 * np.pi * SIG_FREQ * i * dt)))

    res = np.zeros(NUM_SAMPLES, 'complex64')
    model_i = []
    model_q = []

    # Capture on the falling edge after stepping the model, which advances
    # its registers past the same clock edge: captured values and returned
    # model values are then the same registers, at offset 0.
    for i in range(WARMUP):
        dut.in_data.value = sample(i)
        model.step(sample(i))
        await FallingEdge(dut.clock)

    for i in range(WARMUP, WARMUP + NUM_SAMPLES):
        a = sample(i)
        dut.in_data.value = a
        mi, mq = model.step(a)
        await FallingEdge(dut.clock)
        model_i.append(mi)
        model_q.append(mq)
        res[i - WARMUP] = complex(hlmodel._s(int(dut.out_data_I.value), 18),
                                  hlmodel._s(int(dut.out_data_Q.value), 18))

    # Bit exact golden model check (allowing for pipeline/capture skew)
    off, maxi, maxq = hlmodel.find_offset_iq(res, list(zip(model_i, model_q)))
    dut._log.info("Model alignment offset %d (maxdiff i=%d q=%d)", off, maxi, maxq)
    assert maxi == 0, "out_data_I does not match golden model (maxdiff %d)" % maxi
    assert maxq == 0, "out_data_Q does not match golden model (maxdiff %d)" % maxq

    # Spectrum: the complex output is in * exp(+j*nco phase), so a real
    # cosine at SIG_FREQ produces two equal sidebands: RX-SIG = -0.11 MHz
    # and SIG+RX = 41.07 MHz, which aliases (mod fs) to -35.73 MHz.
    s = spectrum.Spectrum(res, dt, window=spectrum.flattop)
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'cordic_spectrum.png')
    s.savepng(png, "Cordic Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=100)
    s.printPeaks(peaks)

    n = len(s.sa)
    dc_idx = n // 2
    binsz = SAMPLING_FREQ / NUM_SAMPLES

    def peak_near(freq_hz, span):
        idx = (dc_idx + int(round(freq_hz / binsz))) % n
        lo = idx - span
        p = (lo + int(np.argmax(s.sa[lo:idx + span + 1]))) % n
        return p, float(s.sa[p])

    wanted = RX_FREQ - SIG_FREQ              # lower sideband
    image = SIG_FREQ + RX_FREQ - SAMPLING_FREQ  # upper sideband, aliased
    dp, carrier_db = peak_near(wanted, CARRIER_BINS)
    ip, image_db = peak_near(image, CARRIER_BINS)
    dut._log.info("Wanted %.6f MHz: %.2f dB; image %.6f MHz: %.2f dB (%.2f dBc)",
                  s.binFreq(dp), carrier_db, s.binFreq(ip), image_db,
                  image_db - carrier_db)
    assert dp == (dc_idx + int(round(wanted / binsz))) % n, \
        "wanted tone not at %.6f Hz" % wanted
    assert ip == (dc_idx + int(round(image / binsz))) % n, \
        "image not aliased to %.6f Hz" % image
    # a real input splits equal power between the two sidebands
    assert abs(image_db - carrier_db) < 1.0, \
        "sidebands %.2f dB apart for a real input tone" % (image_db - carrier_db)

    # SFDR: worst peak outside the two sidebands and DC
    mask = np.ones(n, bool)
    for p in (dp, ip, dc_idx):
        mask[np.arange(p - GUARD_BINS, p + GUARD_BINS + 1) % n] = False
    spur_idx = np.flatnonzero(mask)[int(np.argmax(s.sa[mask]))]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Worst other spur %.2f dBc at %.6f MHz",
                  spur_db - carrier_db, s.binFreq(spur_idx))
    assert spur_db - carrier_db < SFDR_LIMIT_DB, \
        "spur %.2f dBc at %.6f MHz exceeds limit %.1f dBc" % (
            spur_db - carrier_db, s.binFreq(spur_idx), SFDR_LIMIT_DB)
