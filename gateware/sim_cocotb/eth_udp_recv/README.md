# udp_recv (UDP header parser / demux) test

## Overview

Unit-tests `udp_recv.v` (`rtl/ethernet/`), which parses the 8-byte UDP
header arriving while `rx_enable` (the IP payload window) is high and
demultiplexes the payload to either the normal `active` output or the
DHCP path. Datagrams are streamed one byte per clock; the test records
what appears on `active` and on `dhcp_active` and compares against the
injected payload, plus the header-derived destination registers.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=udp_recv`, source `udp_recv.v`, `--trace` enabled. |
| `test_udp_recv.py` | The six tests and the datagram builder. |

## Behaviour under test

- `remote_port` = source port, `to_port` = destination port.
- `to_port == 68` (DHCP) routes the payload to `dhcp_active` instead of
  `active`.
- Broadcast packets must go to port 1024 or 1025; unicast must have
  `local_ip == to_ip`, otherwise the packet is discarded.
- `udp_destination_valid` toggles once the header is verified;
  `udp_destination_ip`/`_mac` latch `remote_ip`/`remote_mac`.
- `active = rx_enable & payload state & !dhcp_data`: exactly
  `udp_length − 8` intervals measured from the first payload byte.
- Two idle `rx_enable`-low cycles are left after each datagram because
  the state machine only returns to IDLE on edges with `rx_enable` low
  (that is how `rgmii_rx_active` drops between real frames).
- ARP traffic bypasses this module entirely (that is `network.v`'s job),
  so all stimulus here is UDP.

## Tests

1. **`test_udp_recv_unicast`** — unicast to `local_ip`: payload
   byte-exact, nothing on the DHCP path, `to_port` / 
   `udp_destination_port` / `_ip` / `_mac` all correct and
   `udp_destination_valid` toggled.
2. **`test_udp_recv_broadcast_discovery_ports`** — broadcast to 1024 and
   1025 passes even though `to_ip` doesn't match `local_ip`; port 1026 is
   dropped.
3. **`test_udp_recv_wrong_unicast_ip_dropped`** — unicast whose `to_ip`
   differs from `local_ip` is discarded.
4. **`test_udp_recv_dhcp`** — `to_port` 68 sends the payload out
   `dhcp_active` with `active` kept low.
5. **`test_udp_recv_empty_payload`** — a zero-length datagram still
   toggles `udp_destination_valid`; and because `byte_no` (9 at payload
   start) has already passed `packet_len` (8), `active` stays high until
   `rx_enable` drops — the test asserts the four filler bytes to pin this
   RTL quirk.
6. **`test_udp_recv_lengths`** — payload sizes 1, 2, 16, 512, 1024: the
   `active` window is exactly UDP length − 8 regardless of what follows.

## Running

```bash
cd sim_cocotb/eth_udp_recv
make          # Verilator + cocotb; 6 tests, all pass in < 0.1 s
```
