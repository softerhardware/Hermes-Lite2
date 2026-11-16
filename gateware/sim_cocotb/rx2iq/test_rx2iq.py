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
RX_FREQ = 5000000.0
SIG_FREQ = 5020000.0
CIC_DECIMATION = 8
VAR_DECIMATION = 12
NUM_SAMPLES = 2048          # decimB complex samples, like the original bench
CORDIC_SAMPLES = 8192       # plotted cordic stream length, like original
WARMUP = 128
FLUSH1_AT = 20
FLUSH2_AT = 64
IN_WIDTH = 12

CLK_PERIOD_NS = 13.564  # nominal 73.728MHz; cocotb Clock needs even ps

OUT_FREQ = SAMPLING_FREQ / (CIC_DECIMATION * VAR_DECIMATION)  # 768 kHz

# Automated check limits
CARRIER_BINS = 2      # tone peak must land within this many FFT bins
SFDR_LIMIT_DB = -22   # any other spur above 200kHz (cic.v now sign-
                      # extends its input; see rx1 notes)


@cocotb.test()
async def test_rx2iq(dut):

    cocotb.start_soon(Clock(dut.clock, CLK_PERIOD_NS, unit='ns').start())

    # m2/m3 from the rtl pll, fs = 73.728MHz (same values as test_rx2IQ.py)
    m2, m3 = 1954687338, 16777216
    freq = (int(RX_FREQ) * m2 + m3) >> 25
    dut.frequency.value = freq
    dut.in_data.value = 0
    dut.flushed1.value = 0
    dut.flushed2.value = 0
    dut._log.info("Driving frequency = %d (%.6f Hz), input %.1f Hz",
                  freq, freq / float(2**32) * SAMPLING_FREQ, SIG_FREQ)

    dt = 1.0 / SAMPLING_FREQ
    model = hlmodel.RxChain(
        freq, in_width=IN_WIDTH, extra_bits=5,
        cic_stages=3, cic_decimation=CIC_DECIMATION,
        cic_acc_width=27, cic_out_width=14,
        var=dict(stages=5, acc_width=37, out_width=16,
                 decimation=VAR_DECIMATION, iq=True))

    # full-scale sine (the original ran ampl=-0.5 1-bit mode for the
    # plot; full scale exercises the same datapath with better SFDR)
    def sig(i):
        return int(round(((2 ** (IN_WIDTH - 1)) - 1) *
                         np.sin(2 * np.pi * SIG_FREQ * i * dt)))

    cordic_res = []
    cic_res = []
    mdl_cic = []
    varcic_res = []
    mdl_var = []

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

    # The model is stepped through the same edge that closes the cycle;
    # capture on the falling edge sees the post-edge values (validated
    # convention, see the cordic test).
    i = WARMUP
    j = 0
    strobeA = []
    strobeB = []
    while j < NUM_SAMPLES:
        a = sig(i)
        dut.in_data.value = a
        _, _, cs, co, coq, vs, vo, voq = model.step(a, 1, 1)
        await FallingEdge(dut.clock)
        if len(cordic_res) < CORDIC_SAMPLES:
            cordic_res.append(
                hlmodel._s(int(dut.out_data_I.value), 18) -
                1j * hlmodel._s(int(dut.out_data_Q.value), 18))
        if int(dut.decimA_avail.value):
            cic_res.append(hlmodel._s(int(dut.decimA_realI.value), 14) -
                           1j * hlmodel._s(int(dut.decimA_realQ.value), 14))
            # keep the model sign convention (I - 1jQ) for comparison
            mdl_cic.append((co, -coq))
            strobeA.append(i)
        if int(dut.decimB_avail.value):
            varcic_res.append(hlmodel._s(int(dut.decimB_realI.value), 16) -
                              1j * hlmodel._s(int(dut.decimB_realQ.value), 16))
            mdl_var.append((vo, -voq))
            strobeB.append(i)
            j += 1
        i += 1

    gapsA = set(int(g) for g in np.diff(strobeA))
    gapsB = set(int(g) for g in np.diff(strobeB))
    dut._log.info("decimA gaps %s, decimB gaps %s", sorted(gapsA), sorted(gapsB))
    assert gapsA == {CIC_DECIMATION}, "decimA_avail not every %d cycles" % CIC_DECIMATION
    assert gapsB == {CIC_DECIMATION * VAR_DECIMATION}, \
        "decimB_avail not every %d cycles" % (CIC_DECIMATION * VAR_DECIMATION)

    # Bit exact golden model checks on both stages
    offA, dAi, dAq = hlmodel.find_offset_iq(cic_res, mdl_cic)
    dut._log.info("decimA alignment offset %d (maxdiff i=%d q=%d)", offA, dAi, dAq)
    assert dAi == 0 and dAq == 0, "decimA I/Q does not match model"
    offB, dBi, dBq = hlmodel.find_offset_iq(varcic_res, mdl_var)
    dut._log.info("decimB alignment offset %d (maxdiff i=%d q=%d)", offB, dBi, dBq)
    assert dBi == 0 and dBq == 0, "decimB I/Q does not match model"

    # Spectra of the three capture points (the original t.plot()).
    here = os.path.dirname(os.path.abspath(__file__))
    for name, npa, decim in (
            ('cordic', np.array(cordic_res[:8192], 'complex64'), 1),
            ('cic', np.array(cic_res[:8192], 'complex64'), CIC_DECIMATION),
            ('varcic', np.array(varcic_res, 'complex64'),
             CIC_DECIMATION * VAR_DECIMATION)):
        s = spectrum.SpectrumIQ(npa, dt, decim, window=spectrum.blackmanharris)
        png = os.path.join(here, 'rx2iq_%s_spectrum.png' % name)
        s.savepng(png, "rx2IQ %s Spectrum" % name.upper())
        dut._log.info("Saved %s spectrum plot to %s", name, png)

    # Checks on the final varcic IQ output
    s = spectrum.SpectrumIQ(np.array(varcic_res, 'complex64'), dt,
                            CIC_DECIMATION * VAR_DECIMATION,
                            window=spectrum.blackmanharris)
    peaks = s.findPeaks(order=4, clipdb=90)
    s.printPeaks(peaks)

    n = len(s.sa)
    dc_idx = n // 2

    def peak_near(freq_mhz, span):
        idx = (dc_idx + int(round(freq_mhz / s.bin2mhz))) % n
        lo = idx - span
        p = (lo + int(np.argmax(s.sa[lo:idx + span + 1]))) % n
        return p, float(s.sa[p])

    # I - 1jQ flips the complex spectrum (original convention), so the
    # wanted RX-SIG = -20kHz tone plots at +20kHz; the upper cordic
    # sideband SIG+RX aliases into the stopband.
    wanted = (SIG_FREQ - RX_FREQ) / 1e6      # MHz
    dp, carrier_db = peak_near(wanted, CARRIER_BINS)
    dut._log.info("Wanted %.6f MHz: %.2f dB", s.binFreq(dp), carrier_db)
    assert dp == (dc_idx + int(round(wanted / s.bin2mhz))) % n, \
        "wanted tone not at %+.6f MHz" % wanted

    # SFDR above the baseband image skirt: worst peak |f| > 200kHz
    mask = np.ones(n, bool)
    keep = np.abs(np.arange(n) - dc_idx) * s.bin2mhz > 0.2
    mask &= keep
    spur_idx = np.flatnonzero(mask)[int(np.argmax(s.sa[mask]))]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Worst spur above 200kHz: %.2f dBc at %.6f MHz",
                  spur_db - carrier_db, s.binFreq(spur_idx))
    assert spur_db - carrier_db < SFDR_LIMIT_DB, \
        "spur %.2f dBc at %.6f MHz exceeds limit %.1f dBc" % (
            spur_db - carrier_db, s.binFreq(spur_idx), SFDR_LIMIT_DB)
