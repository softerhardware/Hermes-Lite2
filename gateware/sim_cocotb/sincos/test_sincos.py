import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import numpy as np

# Full circle is 2**20 angles, outputs are sign-magnitude with
# magnitude scaled so that full scale is 2**18-1
POINTS = 2**20
RES = float(2**18) - 1

# Number of angles swept from 0, and max allowed squared-value error
# (matches the threshold the original myhdl test flagged on)
ANGLES = 20000
MAXDIFF_LIMIT = 0.01


def unpack(signmag):
    v = int(signmag)
    val = (v & 0x3FFFF) / RES
    return -val if v & (1 << 18) else val


@cocotb.test()
async def test_sincos(dut):

    cocotb.start_soon(Clock(dut.clk, 10.0, unit='ns').start())

    dut.angle.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)

    maxdiff = 0.0
    error = 0.0
    samples = 0

    for a in range(ANGLES):
        if (a % 10000) == 0:
            dut._log.info("Angle %d", a)

        dut.angle.value = a
        # Wait for the pipeline to settle
        for _ in range(6):
            await RisingEdge(dut.clk)

        gold_cos = np.cos(2 * np.pi * ((a + 0.5) / POINTS))
        gold_sin = np.sin(2 * np.pi * ((a + 0.5) / POINTS))

        calc_cos = unpack(dut.cos.value)
        calc_sin = unpack(dut.sin.value)
        samples += 1

        diff = abs((gold_cos**2) - (calc_cos**2))
        if diff > maxdiff:
            maxdiff = diff
        if diff > MAXDIFF_LIMIT:
            dut._log.warning("cos mismatch at angle %d: gold %f calc %f diff %f",
                             a, gold_cos, calc_cos, diff)
        error = error + diff

    average_error = error / samples

    dut._log.info("Average Error %f", average_error)
    dut._log.info("Max Diff %f", maxdiff)

    assert maxdiff < MAXDIFF_LIMIT, \
        "max squared-value diff %f exceeds limit %f" % (maxdiff, MAXDIFF_LIMIT)
