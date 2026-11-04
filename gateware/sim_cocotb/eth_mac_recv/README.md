# mac_recv (Ethernet header parser) test

## Overview

Unit-tests `mac_recv.v` (`rtl/ethernet/`), the first stage of the receive
path: it inspects the 14-byte Ethernet header of an incoming frame,
discards frames that are not for us, and opens the payload window for
`ip_recv`/`arp`. Frames are streamed one byte per clock while `rx_enable`
is high; the test records every byte that was on `data` during an
interval where `active` was high — i.e. the payload exactly as the DUT
understood it — and checks the header-derived outputs.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=mac_recv` (the DUT is used directly, no wrapper), source `mac_recv.v`, `--trace` enabled. `-Wno-CASEINCOMPLETE` waives the RTL's intentionally partial case statement: `ST_PAYLOAD` and `ST_ERROR` have no items at all, and `ST_ERROR` therefore has no transition out — `rx_enable` going low is what returns the machine to idle. |
| `test_mac_recv.py` | The six tests and the frame builder. |

## Behaviour under test

- **Destination MAC** — must be broadcast (all `0xFF`) or equal to
  `local_mac` compared byte-by-byte MSB-first; anything else sends the
  machine to `ST_ERROR`, so `active` never goes high and
  `remote_mac_valid` is not updated.
- **Source MAC** — shifted into `remote_mac` as it arrives
  (`{temp_remote_mac[39:0], data}`), so the first byte lands in the top
  byte, matching a Python integer built MSB-first.
- **Ethertype** — `0x0806` → `is_arp = 1`, `0x0800` → `is_arp = 0`, any
  other value (including a first byte that is not `0x08`) discards the
  packet. `remote_mac_valid` toggles only once the protocol byte has been
  accepted.
- `active = rx_enable & (state == ST_PAYLOAD)`, so it is high for exactly
  the intervals in which the byte currently on `data` belongs to the
  payload — the Ethernet CRC that trails the payload is not passed on
  because the upstream (`rgmii_recv`) window stops with it.
- `broadcast`/`unicast` are re-armed to 1 on every `rx_enable`-low edge,
  which is also what resets the state machine between frames.
- `clock` is the RGMII receive clock; the test runs it at 8 ns (125 MHz),
  the real byte rate, so each rising edge advances exactly one byte.

## Tests

1. **`test_mac_recv_unicast_ip`** — a 60-byte payload addressed to
   `local_mac` with ethertype `0x0800`: payload byte-exact, `is_arp` and
   `broadcast` clear, `remote_mac` is the sender, `remote_mac_valid`
   toggles.
2. **`test_mac_recv_broadcast_arp`** — all-`FF` destination, ethertype
   `0x0806`: payload passes, `is_arp` and `broadcast` both set.
3. **`test_mac_recv_foreign_dst_dropped`** — destination
   `00:11:22:33:44:55`: nothing is ever marked active and
   `remote_mac_valid` is untouched.
4. **`test_mac_recv_unknown_ethertype_dropped`** — valid broadcast
   destination with ethertype `0x0809`: discarded, and `is_arp` keeps its
   previous value (it is only written on the accepted-protocol path).
5. **`test_mac_recv_bad_dst_single_byte_off`** — destination
   `local_mac ^ 0x01` is neither broadcast nor unicast, so a one-bit
   difference is enough to drop the frame.
6. **`test_mac_recv_back_to_back_frames`** — a broadcast IP frame
   immediately followed (two idle `rx_enable`-low cycles apart) by a
   unicast ARP frame: both payloads come out correctly, `is_arp` reflects
   the *second* frame and `remote_mac` the second sender, proving each
   frame is parsed from scratch.

## Running

```bash
cd sim_cocotb/eth_mac_recv
make          # Verilator + cocotb; 6 tests, all pass in < 0.1 s
```
