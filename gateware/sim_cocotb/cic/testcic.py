import os
import sys, random
import cocotb
import logging
from cocotb.clock import Clock
import time
from array import array as Array
from cocotb.triggers import Timer, FallingEdge, ClockCycles

import numpy as np


MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "hdl")
MODULE_PATH = os.path.abspath(MODULE_PATH)


async def signal(dut,sigfreq,sampfreq):

    i = sigfreq
    while True:
        v = int(round((2**17-1)*np.sin(2*np.pi*i/sampfreq)))
        dut.in_data <= v
        await FallingEdge(dut.clock)
        i += sigfreq
        i = i % sampfreq


def setup_dut(dut):
    cocotb.start_soon(Clock(dut.clock, 13.02, unit='ns').start())
   

@cocotb.test(skip = False)
async def test_0(dut):

    setup_dut(dut)
    dut.in_strobe.value = 1
    dut.in_data.value = 0x7fff

    for k in range(400): await FallingEdge(dut.clock)
   
