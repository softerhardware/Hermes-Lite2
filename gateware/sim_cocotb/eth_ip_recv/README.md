# ip_recv (IPv4 header parser) test

## Overview

Unit-tests `ip_recv.v` (`rtl/ethernet/`), which parses the IPv4 header of
the incoming byte stream (starting at the version/IHL byte) and gates the
payload window for `udp_recv`/`icmp`. Packets are streamed one byte per
clock with `rx_enable` high; the test captures everything emitted while
`active` is high and checks the header-derived outputs.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=ip_recv`, source `ip_recv.v`, `--trace` enabled. |
| `test_ip_recv.py` | The eight tests plus the minimal IPv4 packet builder. |

## Observables

- `is_icmp` — protocol 1 → 1, protocol 17 → 0; any other protocol
  discards the packet.
- `remote_ip` / `remote_ip_valid` — sender address (header bytes 12–15);
  valid pulses once per packet that gets that far.
- `to_ip` / `to_ip_is_me` — destination address (bytes 16–19).
- A non-IPv4 version nibble, a wrong broadcast address, or an
  unsupported protocol sends the machine to `ST_DONE` (`active` never
  rises).
- `active = rx_enable & payload state`: high for exactly
  `total_length − 20` intervals starting at the first payload byte, so
  the Ethernet CRC trailing the payload is correctly ignored.

## Tests

1. **`test_ip_recv_udp_unicast`** — UDP packet to our IP: header parsed
   (`is_icmp` clear, `remote_ip`, `to_ip`, `to_ip_is_me`),
   `remote_ip_valid` toggles, and the payload captured for exactly its
   own length (the 4 trailing CRC filler bytes are not passed on).
2. **`test_ip_recv_icmp`** — protocol 1 raises `is_icmp`.
3. **`test_ip_recv_broadcast`** — `broadcast = 1` with a
   `255.255.255.255` destination is accepted and sets `to_ip_is_me`.
4. **`test_ip_recv_broadcast_mismatch_dropped`** — `broadcast = 1` but a
   destination that is neither all-255 nor `local_ip`: discarded before
   any payload.
5. **`test_ip_recv_foreign_unicast_passes_not_me`** — a unicast for
   another IP is still forwarded downstream by this RTL, just with
   `to_ip_is_me` cleared (pins the actual Metis behaviour).
6. **`test_ip_recv_bad_version_dropped`** — version nibble 6 discards the
   packet immediately.
7. **`test_ip_recv_unsupported_proto_dropped`** — TCP (6): discarded and
   `remote_ip_valid` does not pulse.
8. **`test_ip_recv_ihl6`** — an IHL=6 (24-byte) header correctly delays
   the payload start, **but** the `to_ip`/`is_me` comparisons use fixed
   byte offsets and end up reading the wrong bytes — the test asserts
   `to_ip_is_me` is *not* set here, pinning the known "assumes a 20-byte
   header" limitation rather than masking it.

## Running

```bash
cd sim_cocotb/eth_ip_recv
make          # Verilator + cocotb; 8 tests, all pass in < 0.1 s
```
