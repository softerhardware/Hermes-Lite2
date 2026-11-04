import os
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge

import numpy as np

# spectrum.py lives in the parent sim_cocotb directory
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))
import spectrum

SAMPLING_FREQ = 76800000.0
RX_FREQ = 7078132.0
NUM_SAMPLES = 16384
FULLSCALE = float(2**18) - 1

# Clock is nominally 76.8MHz (13.0208..ns). cocotb requires the period to be a
# whole number of simulator precision (1ps) steps with an integer half period,
# and the RTL is purely edge driven, so a rounded period is fine; all DSP
# maths below uses the nominal frequency.
CLK_PERIOD_NS = 13.022

# Automated check limits
CARRIER_BINS = 2       # carrier peak must land within this many FFT bins of expected
MAG_TOLERANCE = 0.001  # every sample magnitude within 0.1% of full scale
SFDR_LIMIT_DB = -80.0  # worst spur at least this far below the carrier
SPUR_GUARD_BINS = 25   # bins around the carrier excluded from the spur scan (window main lobe)
DC_LIMIT_DB = -80.0    # worst peak within a few bins of DC


@cocotb.test()
async def test_nco1(dut):

    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit='ns').start())

    dut.rst.value = 0
    phi = int(0x7fffffff * float(RX_FREQ) / (SAMPLING_FREQ / 2))
    dut.phi.value = phi
    dut._log.info("Driving phi = %d (%.6f Hz)", phi,
                  phi / float(2**32) * SAMPLING_FREQ)

    # Let the pipeline fill
    for _ in range(32):
        await FallingEdge(dut.clk)

    # Capture one complex sample per clock, as the original myhdl bench did
    samples = np.zeros(NUM_SAMPLES, 'complex64')
    for i in range(NUM_SAMPLES):
        cosv = int(dut.cos.value)
        sinv = int(dut.sin.value)
        # Outputs are sign-magnitude: bit 18 is the sign, bits 17:0 the magnitude
        icos = -(cosv & 0x3FFFF) if cosv >> 18 else cosv
        isin = -(sinv & 0x3FFFF) if sinv >> 18 else sinv
        samples[i] = complex(icos, isin)
        await FallingEdge(dut.clk)

    # Time domain check: constant envelope
    mag = np.abs(samples.astype('complex128')) / FULLSCALE
    dut._log.info("Sample magnitude: min %.6f max %.6f mean %.6f",
                  mag.min(), mag.max(), mag.mean())
    assert np.all(np.abs(mag - 1.0) < MAG_TOLERANCE), \
        "sample magnitude deviates more than %.2f%% from full scale" % (MAG_TOLERANCE * 100)

    dt = 1.0 / SAMPLING_FREQ
    s = spectrum.Spectrum(samples, dt, window=spectrum.flattop)

    # Visual representation of the spurs, saved next to this test
    png = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'nco1_spectrum.png')
    s.savepng(png, "NCO Spectrum")
    dut._log.info("Saved spectrum plot to %s", png)

    peaks = s.findPeaks(order=4, clipdb=100)
    s.printPeaks(peaks)

    n = len(s.sa)
    dc_idx = n // 2  # complex spectra are fftshifted, DC sits at n/2

    # Carrier frequency check
    binsz = SAMPLING_FREQ / NUM_SAMPLES
    exp_bin = int(round(RX_FREQ / binsz))
    lo, hi = dc_idx + exp_bin - 10, dc_idx + exp_bin + 11
    peak_idx = lo + int(np.argmax(s.sa[lo:hi]))
    carrier_db = s.sa[peak_idx]
    dut._log.info("Carrier peak at %.6f MHz, %.2f dB (expected %.6f MHz, bin %d, got bin %d)",
                  s.binFreq(peak_idx), carrier_db, RX_FREQ / 1e6, exp_bin, peak_idx - dc_idx)
    assert abs(peak_idx - (dc_idx + exp_bin)) <= CARRIER_BINS, \
        "carrier peak at bin %d, expected bin %d" % (peak_idx - dc_idx, exp_bin)

    # Spur scan: worst peak outside the carrier's main lobe
    mask = np.ones(n, bool)
    mask[peak_idx - SPUR_GUARD_BINS:peak_idx + SPUR_GUARD_BINS + 1] = False
    spur_indices = np.flatnonzero(mask)
    spur_pos = int(np.argmax(s.sa[mask]))
    spur_idx = spur_indices[spur_pos]
    spur_db = float(s.sa[spur_idx])
    dut._log.info("Worst spur %.2f dBc at %.6f MHz", spur_db, s.binFreq(spur_idx))
    assert spur_db < SFDR_LIMIT_DB, \
        "worst spur %.2f dBc at %.6f MHz exceeds limit %.1f dBc" % (
            spur_db, s.binFreq(spur_idx), SFDR_LIMIT_DB)

    # DC offset check
    dc_db = float(s.sa[dc_idx - 3:dc_idx + 4].max())
    dut._log.info("Worst peak near DC %.2f dBc", dc_db)
    assert dc_db < DC_LIMIT_DB, \
        "DC peak %.2f dBc exceeds limit %.1f dBc" % (dc_db, DC_LIMIT_DB)
