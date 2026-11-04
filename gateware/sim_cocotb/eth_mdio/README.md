# mdio (IEEE 802.3 clause 22 management interface) test

## Overview

Unit-tests `mdio.v` (`rtl/ethernet/`) — the MDIO master that configures
and polls the PHY. The module shifts a 64-bit frame out MSB first, one
bit per **falling** clock edge (`mdc_pin` is just the clock), with
`ready` high while idle. A testbench PHY driver attached to the inout in
`tb_mdio.v` models the PHY side during reads, so both the command
framing on the wire and the read-back datapath are checked bit by bit.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=tb_mdio`, sources `mdio.v` + `tb_mdio.v`, `--trace` enabled. |
| `tb_mdio.v` | Wrapper exposing the `inout mdio_pin` as a plain wire with a second, testbench-controlled driver (`tb_en`/`tb_val`) so cocotb can force PHY-side bits. |
| `test_mdio.py` | The five tests, the write-frame golden and the read helper. |

## Framing and the two RTL quirks it pins

Write frame: 32×`1` preamble, `010100111`, 5-bit register address, TA
`10`, 16 data bits. Read frame: 32×`1`, `011000111`, register address,
then the driver releases the pin for the turnaround + 16 data bits,
shifting them into `rd_data`.

- **Opcodes are swapped** with respect to IEEE 802.3 clause 22 (write
  uses `01`, read `10`). This is what the Metis RTL encodes and what
  `phy_cfg.v` is built around, so the test pins it rather than the spec.
- **Read data lands one bit late.** `ST_READING` releases the pin on the
  edge ending interval 46 and its 16 `rd_data` shift-ins capture
  intervals 48..63, so against a clause-22 PHY (pull-up turnaround, then
  `data15..data0` in intervals 49..64) the captured word is
  `0x8000 | (data >> 1)` — `data0` falls on the closing edge and is never
  shifted in.

Interval model: interval *k* runs between falling edges `E(k-1)` and
`E(k)`; the state machine acts on the falling edge that opens it and
drives `bits[64-k]` for the whole interval, so sampling on `RisingEdge`
reads exactly one bit per falling edge.

## Tests

1. **`test_mdio_idle`** — idle: `ready` high and the preamble level
   (`wr_bits[63]` = 1) on the wire.
2. **`test_mdio_write_frame`** — a write request shifts out the complete
   64-bit golden frame, preamble first; `ready` drops for the transfer
   and returns high after 64 bits.
3. **`test_mdio_read_frame`** — the 46 command bits match
   preamble + read opcode + address, and `rd_data` equals
   `0x8000 | (phy_data >> 1)` (the one-bit-late capture).
4. **`test_mdio_read_all_ones`** — an all-ones bus (no PHY present) reads
   back as `0xFFFF`.
5. **`test_mdio_back_to_back`** — two writes issued back to back are both
   framed correctly: register 0 ← `0x1300` (restart autonegotiation) then
   register 9 ← `0x0200`, i.e. the real `phy_cfg` init sequence.

`setup()` quiesces the bus and waits for `ready` before each test so a
frame leaked from an earlier test can finish first.

## Running

```bash
cd sim_cocotb/eth_mdio
make          # Verilator + cocotb; 5 tests, all pass in < 0.1 s
```
