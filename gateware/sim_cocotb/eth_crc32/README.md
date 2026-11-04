# crc32 (Ethernet FCS engine) test

## Overview

Unit-tests the nibble-table CRC-32 engine `crc32.v` (`rtl/ethernet/`)
exactly as the surrounding Metis-style RTL uses it. The module folds one
byte per clock into a 32-bit accumulator while `enable` is high, is
zeroed by `clear`, and exposes a **combinational** `result` that is the
accumulator *additionally* folded with the byte currently on `data` —
which is precisely the contract `mac_send` relies on. The tests model
that fold step-for-step, and separately cross-check the model against
`binascii.crc32` to prove the engine computes the standard Ethernet FCS.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=crc32`, source `crc32.v`. `-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC` waive the RTL's deliberate implicit width extension inside its table lookups. |
| `test_crc32.py` | The three tests plus the Python fold model. |

## Model

```python
fold(prev, b):            # one module step: low nibble first, then high
    lo  = (prev >> 4) ^ TABLE[(prev ^ b) & 0xF]
    return (lo >> 4) ^ TABLE[(lo ^ (b >> 4)) & 0xF]
```

`TABLE` is the 16-entry nibble table read out of `crc32.v`; iterating
`fold` over a whole stream reproduces `binascii.crc32`.

## Tests

1. **`test_crc32_stream_matches_reference`** — 10 random streams
   (1–127 bytes): after *every* byte, `result` must equal the fold model
   advanced by that byte; at the end the accumulated value must equal
   `binascii.crc32(data)`, tying the RTL to the standard CRC-32/ISO-HDLC.
2. **`test_crc32_fcs_residue`** — a frame followed by its FCS (inverted
   CRC, little-endian byte order — the order the wire uses) must leave
   the accumulator at the all-ones good-frame residue `0xFFFFFFFF`; a
   single-bit corruption must not. The final byte is re-applied with
   `enable` low so the accumulator settles without folding extra data.
3. **`test_crc32_clear_and_hold`** — bytes clocked while `clear` is
   asserted must not accumulate; `enable = 0` freezes the accumulator
   while `result` keeps tracking the live `data` byte; on re-enable the
   surviving accumulator is exactly `crc32(b"\x3c\x22")`.

## Running

```bash
cd sim_cocotb/eth_crc32
make          # Verilator + cocotb; 3 tests, all pass in < 0.1 s
```
