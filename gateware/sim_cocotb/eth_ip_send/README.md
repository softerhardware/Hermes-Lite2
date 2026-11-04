# ip_send (IPv4 header builder) test

## Overview

Unit-tests `ip_send.v` (`rtl/ethernet/`), which prepends the 22 bytes the
MAC layer needs in front of the upstream byte stream: the `0x0800`
ethertype followed by a 20-byte IPv4 header (version/IHL `0x45`, TOS 0,
total length `20 + length`, id 0, flags `0x4000`, TTL `0x80`, protocol
1 (ICMP) or 17 (UDP), a one's-complement header checksum, local IP,
destination IP). Every emitted byte is compared against a byte-exact
golden packet.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=ip_send`, source `ip_send.v`, `--trace` enabled. |
| `test_ip_send.py` | The five tests, the checksum mirror and the golden-packet model. |
| `../ethcommon.py` | Shared `tx_stream()` helper implementing the byte-per-clock transmit-interval convention (see its module docstring). |

## Stream layout

The payload is delayed behind the 22-byte header: interval *j* of the
`active` window carries header byte *j* for `j <= 22`, then
`data_in[j-22]`.

One documented RTL quirk is pinned by this test: `sending` only clears
one edge after `byte_no` reaches 0, so the module emits **one byte more**
than header + payload — a trailing byte (zero, once the testbench stops
driving `data_in`). In the full chain `mac_send`'s own byte counting
absorbs this byte; `udp_send` added a guard against it, `ip_send` never
did, so the empty-payload test expects it explicitly.

## Tests

1. **`test_ip_send_udp_frame`** — a 42-byte UDP payload emerges behind a
   well-formed header with protocol 17 and the right checksum.
2. **`test_ip_send_icmp_frame`** — `is_icmp = 1` switches the protocol
   field to 1 and the checksum changes accordingly.
3. **`test_ip_send_empty_payload`** — with `length = 0` the whole 22-byte
   header is still emitted, plus the one trailing zero byte (the
   `byte_no` countdown quirk).
4. **`test_ip_send_sizes`** — payload sizes 1, 20, 47, 48, 49, 100, 512;
   each golden packet must match and the `ip_packet_length` output must
   read `20 + size`.
5. **`test_ip_send_checksum_vectors`** — the combinational `checksum`
   output is spot-checked against an independent 16-bit one's-complement
   sum for three (length, protocol, src, dst) combinations, including
   1000 bytes and a broadcast destination.

## Running

```bash
cd sim_cocotb/eth_ip_send
make          # Verilator + cocotb; 5 tests, all pass in < 0.1 s
```
