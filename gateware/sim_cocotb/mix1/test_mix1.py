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
RX_FREQ = 24000000.0
SIG_FREQ = 24006123.0
NUM_SAMPLES = 16384
WARMUP = 32
ADC_FULLSCALE = 2**11 - 1

CLK_PERIOD_NS = 13.022  # nominal 76.8MHz; see test_nco1 for rationale

# Automated check limits
CARRIER_BINS = 3      # carrier peak must land within this many FFT bins
IMAGE_LIMIT_DB = -70  # lower sideband (image) rejection
SFDR_LIMIT_DB = -70   # any other spur
GUARD_BINS = 30       # bins around a peak excluded from the spur scan


@cocotb.test()
async def test_mix1(dut):

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit='ns').start())

    phi = int(0x7fffffff * float(RX_FREQ) / (SAMPLING_FREQ / 2))
    dut.rst.value = 0
    dut.phi.value = phi
    dut.adc.value = 0
    dut._log.info("Driving phi = %d (%.6f Hz), input signal %.1f Hz",
                  phi, phi / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.Mix1(phi)

    def adc_sample(i):
        return int(round(SIG_LEVEL * np.sin(2 * np.pi * SIG_FREQ * i * dt)))

    SIG_LEVEL = ADC_FULLSCALE

    # Warmup, then one complex sample per clock (same capture as the myhdl bench)
    res = np.zeros(NUM_SAMPLES, 'complex64')
    model_i = []
    model_q = []

    for i in range(WARMUP):
        dut.adc.value = adc_sample(i)
        model.step(adc_sample(i))
        await FallingEdge(dut.clk)

    for i in range(WARMUP, WARMUP + NUM_SAMPLES):
        a = adc_sample(i)
        dut.adc.value = a
        mi, mq = model.step(a)
        model_i.append(mi)
        model_q.append(mq)
        res[i - WARMUP] = complex(hlmodel._s(int(dut.i_data.value), 18),
                                  hlmodel._s(int(dut.q_data.value), 18))
        await FallingEdge(dut.clk)

    # Keep clocking so the model pipeline can drain into the captured range
    for i in range(WARMUP + NUM_SAMPLES, WARMUP + NUM_SAMPLES + 64):
        model.step(adc_sample(i))
        await FallingEdge(dut.clk)

    # Bit exact golden model check (allowing for pipeline/capture skew)
    di, maxi = hlmodel.find_offset(res.real, model_i)
    dq, maxq = hlmodel.find_offset(res.imag, model_q)
    dut._log.info("Model alignment offset i=%d (maxdiff %d), q=%d (maxdiff %d)",
                  di, maxi, dq, maxq)
    assert maxi == 0, "i_data does not match golden model (maxdiff %d)" % maxi
    assert maxq == 0, "q_data does not match golden model (maxdiff %d)" % maxq

    # Spectrum: i+jq = adc * exp(+j*nco phase), so the negative-frequency
    # half of the real ADC input mixes to -(SIG_FREQ-RX_FREQ) and the
    # positive-frequency half to SIG_FREQ+RX_FREQ, which aliases (mod fs)
    # to SIG_FREQ+RX_FREQ-sampling.
    s = spectrum.Spectrum(res, dt, window=spectrum.flattop)
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mix1_spectrum.png')
    s.savepng(png, "Mix Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=100)
    s.printPeaks(peaks)

    n = len(s.sa)
    dc_idx = n // 2
    binsz = SAMPLING_FREQ / NUM_SAMPLES

    def peak_near(freq, span):
        idx = (dc_idx + int(round(freq / binsz))) % n
        lo = idx - span
        p = lo + int(np.argmax(s.sa[lo:idx + span + 1]))
        return p % n, float(s.sa[p % n])

    wanted = -(SIG_FREQ - RX_FREQ)          # desired downconverted signal
    usb = SIG_FREQ + RX_FREQ - SAMPLING_FREQ  # aliased upper sideband
    dp, carrier_db = peak_near(wanted, CARRIER_BINS)
    up, usb_db = peak_near(usb, CARRIER_BINS)
    dut._log.info("Wanted %.6f MHz: %.2f dB; upper sideband %.6f MHz: %.2f dB (%.2f dBc)",
                  s.binFreq(dp), carrier_db, s.binFreq(up), usb_db,
                  usb_db - carrier_db)
    assert dp == (dc_idx + int(round(wanted / binsz))) % n, \
        "wanted tone not at %.6f Hz" % wanted
    assert up == (dc_idx + int(round(usb / binsz))) % n, \
        "upper sideband not aliased to %.6f Hz" % usb
    # Both halves of the real input tone must downconvert with equal gain
    assert abs(usb_db - carrier_db) < 1.0, \
        "upper sideband %.2f dBc off the wanted tone" % (usb_db - carrier_db)
    # SFDR: worst peak outside the wanted tone, its aliased upper sideband,
    # and DC
    mask = np.ones(n, bool)
    for p in (dp, up, dc_idx):
        mask[np.arange(p - GUARD_BINS, p + GUARD_BINS + 1) % n] = False
    spur_pos = int(np.argmax(s.sa[mask]))
    spur_idx = np.flatnonzero(mask)[spur_pos]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Worst other spur %.2f dBc at %.6f MHz",
                  spur_db - carrier_db, s.binFreq(spur_idx))
    assert spur_db - carrier_db < SFDR_LIMIT_DB, \
        "spur %.2f dBc at %.6f MHz exceeds limit %.1f dBc" % (
            spur_db - carrier_db, s.binFreq(spur_idx), SFDR_LIMIT_DB)
