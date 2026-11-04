# Shared helpers for the cocotb tests of rtl/ethernet.
#
# The Metis-style ethernet stack streams one byte per clock.  For the
# transmit modules data_out is a combinational slice of a shift register
# that advances on every rising edge while the module is active, so a
# byte is "on the wire" during the clock *interval* between two edges:
# the byte for interval j must be presented on data_in during interval
# j, and data_out is read after the edge that starts interval j (once
# combinational outputs have settled).  tx_stream() implements that
# convention.

import binascii

import cocotb
from cocotb.triggers import RisingEdge, Timer


CLK_PERIOD_NS = 8.0  # RGMII 125 MHz clock, any convenient period


def std_crc32(data):
    """Standard Ethernet FCS value (CRC-32/ISO-HDLC) of the byte string."""
    return binascii.crc32(bytes(data)) & 0xFFFFFFFF


def to_bytes(value, nbytes):
    return int(value).to_bytes(nbytes, "big")


async def init_inputs(dut, **signals):
    """Drive named DUT inputs (accepts python ints, bytes or iterables)."""
    for name, value in signals.items():
        sig = getattr(dut, name)
        if isinstance(value, (bytes, bytearray)):
            value = int.from_bytes(value, "big")
        sig.value = value
    await Timer(1, unit="ns")


async def apply_reset(dut, signals=("reset",), clock="clock", cycles=3):
    """Pulse one or more reset-style inputs, then leave them deasserted."""
    for name in signals:
        getattr(dut, name).value = 1
    await RisingEdge(getattr(dut, clock))
    for _ in range(cycles):
        await RisingEdge(getattr(dut, clock))
    for name in signals:
        getattr(dut, name).value = 0
    await Timer(1, unit="ns")


async def rx_stream(dut, data, enable="rx_enable", data_in="data",
                    clock="clock", extra_idle_cycles=2):
    """Stream one byte into the DUT per rising clock edge.

    rx_enable is held high with the next byte presented in every clock
    interval, then dropped for a few idle cycles so receive state
    machines can return to idle.
    """
    clk = getattr(dut, clock)
    en = getattr(dut, enable)
    di = getattr(dut, data_in)
    en.value = 1
    di.value = data[0] if data else 0
    await Timer(1, unit="ns")
    j = 0
    while j < len(data):
        await RisingEdge(clk)
        j += 1
        di.value = data[j] if j < len(data) else 0
        await Timer(1, unit="ns")
    en.value = 0
    for _ in range(extra_idle_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")


async def tx_stream(dut, payload, length_input=None, clock="clock",
                    enable="tx_enable", active="active",
                    data_in="data_in", data_out="data_out",
                    data_in_is_length=False, hold_cycles=None,
                    wait_for_active=False, data_delay=0,
                    timeout_cycles=4096):
    """Drive a transmit module and collect the bytes it puts on the wire.

    tx_enable is held high while the payload is streamed, one byte per
    clock.  `length_input`, if given, is loaded with len(payload) (or
    the full payload value if data_in_is_length) before enable rises.
    hold_cycles overrides how long tx_enable stays high (defaults to the
    payload length); data_in reads as zero past the payload end.

    data_delay shifts the payload one interval later per unit: with
    data_delay=1 payload[0] is presented during interval 1, matching
    upstream modules whose data_out/data_in is a registered output.
    wait_for_active skips (and counts) leading intervals in which active
    is still low, for modules that deassert active during the first
    enable cycle.

    Returns a list of bytes: data_out sampled during every interval in
    which active was high.  Callers must leave the DUT idle (reset
    released, a couple of clock edges run) before calling.
    """
    clk = getattr(dut, clock)
    en = getattr(dut, enable)
    act = getattr(dut, active)
    do = getattr(dut, data_out)

    n = len(payload)
    H = hold_cycles if hold_cycles is not None else n
    length = payload if data_in_is_length else n
    di = None if data_in in (None, "none") else getattr(dut, data_in)

    if length_input is not None and length_input != "none":
        getattr(dut, length_input).value = length
    if di is not None:
        di.value = payload[0] if payload else 0
    await Timer(1, unit="ns")
    # one idle edge so the shift register loads its header from the
    # now-valid length inputs (upstream holds length stable while idle)
    await RisingEdge(clk)
    await Timer(1, unit="ns")

    en.value = 1
    await Timer(1, unit="ns")  # let combinational active settle

    out = []
    j = 0  # intervals since tx_enable was raised
    k = 0  # intervals with active high
    while True:
        if act.value:
            out.append(int(do.value))
            k += 1
        elif k or not wait_for_active:
            break  # transmission ended (or never starts, no waiting)
        await RisingEdge(clk)
        j += 1
        if di is not None:
            idx = j - data_delay
            di.value = payload[idx] if 0 <= idx < n else 0
        if j >= H + data_delay:
            en.value = 0
        await Timer(1, unit="ns")
        if j > timeout_cycles:
            raise AssertionError(
                "active did not drop within %d cycles; captured %r"
                % (timeout_cycles, out))
    return out
