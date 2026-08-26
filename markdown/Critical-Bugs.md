# Critical Bugs in the Hermes-Lite 2 Gateware

This page documents the five most critical defects found in a review of the RTL for
the `hl2b5up_main` variant (see [Architecture](Architecture)). They are ranked by
combined severity × likelihood. Several smaller issues are listed at the end.

*Companion pages: [Architecture](Architecture) · [Refactor Plan](Refactor-Plan)*

---

## Summary

| # | Bug | File(s) | Effect |
|---|-----|---------|--------|
| 1 | Debouncer "stable" test is wrong (`\|` instead of `~\|`) | `rtl/debounce.v:35` | Key/inhibit bounce passes straight through — CW keying artifacts, PTT-inhibit chatter |
| 2 | Ethernet receive path performs no frame integrity checking | `ethernet/mac_recv.v`, `ip_recv.v`, `rgmii_recv.v`, + parser resync in `dsopenhpsdr1.v` | Corrupted/hostile frames can reach the protocol FSM of a **transmitter**; worst case unwanted RF |
| 3 | Clock-domain-crossing defects around ARP/DHCP (and a broken CDC primitive) | `ethernet/dhcp.v:214/234`, `ethernet/network.v:700-708`, `sync.v:101-103` | Rare metastability events can hang DHCP lease renewal or address replies to the wrong host |
| 4 | Command/read-back path errors: AD9866 reads return I²C data, RX-gain update commented out, no I²C stall timeout | `control.v:422-433/871-880`, `ad9866ctrl.v:113,120`, `i2c_master.v`, `i2c_bus2.v` | Host loses register read-back and (on some variants) RX gain control; one stuck I²C transaction wedges all host control until power cycle |
| 5 | FIFO occupancy bus driven by two conflicting megafunction outputs | `fifos.v:241 & 248` (`usiq_fifo`) | Undefined value gates the main RX sample path backpressure — sample drops/clicks possible |

---

## Bug 1 — The debouncer does not debounce

**Location:** `gateware/rtl/debounce.v:35`

```verilog
assign stable = (&pb_history) | (|pb_history);   // all-ones OR *any*-ones
```

The intent (per the header comment *"Debounce with immediate response if last signal
stabilized"*) is clearly:

```verilog
assign stable = (&pb_history) | (~|pb_history);  // all-ones OR all-zeros
```

As written, `stable` is true whenever the 6-sample history contains **any** 1, so
after the first press edge `clean_pb <= pb` follows the raw input on every
millisecond tick. Contact bounce produces exactly what a debouncer exists to remove:
multiple clean pulses per press.

**Impact on this variant:** `hl2b5up_main` builds with `CW=1`, so
`debounce de_phone_tip` feeds `ext_cwkey` → `cw_keydown` into the TX state machine
(`control.v:773,791-795`). A mechanical key or PTT closure on the phone jack can
produce spurious keyed RF elements. `de_txinhibit` has the same defect, so a bouncy
external inhibit input chatters `ext_txinhibit`. Also note `pb` is an asynchronous
pin sampled with no synchronizer stage.

**Fix:** one-line change as above; optionally add a `sync` stage ahead of the
history shifter. Trivially validated with the existing MyHDL bench style.

---

## Bug 2 — No integrity checking anywhere in the Ethernet receive path

The stack trusts every frame that survives MAC filtering. Four independent gaps
combine into one systemic problem for a device that keys a transmitter from network
input.

**Evidence:**

1. **FCS never verified.** Neither `mac_recv.v` nor any other module computes or
   checks the CRC32 over received frames; `crc32.v` is only used on transmit
   (`mac_send.v:75`). Any frame with correct dst-MAC is parsed regardless of damage.
2. **IP header checksum never verified.** `ip_recv.v` parses version, length,
   protocol and addresses but accumulates no checksum.
3. **Preamble filter dead branch (dangling else).** `rgmii_recv.v:93-104`: the
   `else preamble_cnt <= MIN_PREAMBLE_LENGTH` binds to the inner `if (data == 8'h55)`,
   so the intended "wrong byte restarts preamble detection" branch can never fire.
   Any junk containing ≥6 `0x55` followed by `0xD5` is accepted.
4. **Length truncation.** `ip_recv.v:68` / `udp_recv.v:93` store total length as 11
   bits (`packet_len[10:8] <= data[2:0]`); frames >2047 bytes are silently misframed.

Downstream, `dsopenhpsdr1.v` re-synchronizes on magic bytes (`EF FE`) anywhere in the
payload and accepts commands embedded in them. So a corrupted broadcast packet — or
anything crafted by another host on the LAN, since there is no session concept — can
inject frequency changes, PTT (`CMDCTRL` bit 0), or RUNSTOP into a radio that may be
transmitting. The practical result ranges from audio glitches to **off-frequency or
unintended transmissions**, which matters for regulatory and hardware-safety reasons.

**Fix direction:** check FCS residual (magic 0xDEBB20E3) before asserting payload
valid; add IP header checksum accumulation (a small adder over 10 words); fix the
dangling else with explicit `begin/end`; widen the length field to 12 bits. All are
small, localized changes; FCS checking is the highest-value one.

---

## Bug 3 — CDC defects in the ARP/DHCP control path

> **Status: fixed** by the R4 CDC-toolkit refactor (see
> [Refactor Plan](Refactor-Plan) §R4): the DHCP request path now uses a
> toggle request/acknowledge handshake, `network.v` captures the remote IP
> under its synced valid pulse, the broken `sync_handshake` primitive was
> reimplemented as a proper four-phase handshake, and the CW keyer
> parameters are captured atomically via `sync_qualifier`. Kept below as a
> record of the original review finding.

Two concrete violations, plus one latent one in the shared primitive itself:

**a) DHCP send-request clear samples multi-bit state directly across domains**
(`dhcp.v`):

```verilog
214: sync sync_inst1 (.clock(tx_clock), .sig_in(rx_send_request), .sig_out(send_request)); // set: proper sync
234:     if (state == DHCPSEND) rx_send_request <= 1'b0;   // clear: rx_clock sampling raw tx-domain bus
```

The request is *set* via a proper synchronizer but *cleared* by comparing the
tx-domain `state` register inside an rx_clock block. Metastability or torn sampling
of `state` can either lose a Discover/Request transmission (DHCP retry masks it at
boot) or wedge the lease-renewal exchange introduced in the N2ADR updates.

**b) Asymmetric capture discipline in `network.v:685-708`.** The tx-clock block
captures `remote_mac` only when its synced valid pulse fires (`remote_mac_valid_sync`,
line 700) — correct — but captures `remote_ip_sync <= remote_ip` from the **raw**
rx-domain `remote_ip_valid` (line 704). A metastable capture loads a stale/wrong
source IP used for ICMP replies and the DHCP server address.

**c) The CDC primitive `sync_handshake` itself is broken** (`sync.v:98-103`): it
crosses `indomain` into `clk_outdomain` with a **single flop and no destination-side
synchronizer** — the classic violation the module family exists to prevent.
Fortunately nothing instantiates it today, but it is a loaded foot-gun for future
work (see [Refactor-Plan](Refactor-Plan) §R4).

Related pattern worth noting: `cw_openhpsdr.v:75-91` ships eight multi-bit registers
from `clk` to the 48 kHz iambic domain with no qualification (quasi-static in
practice, but a live speed change mid-element tears).

**Fix direction:** mirror the `remote_mac` pattern for `remote_ip`; replace the
`state == DHCPSEND` poll with a synced toggle handshake like the set path; delete or
repair `sync_handshake`.

---

## Bug 4 — Command/read-back subsystem returns wrong data and can wedge permanently

Three defects in the mechanism every host register access depends on:

**a) AD9866 register reads return I²C data.** In `control.v`'s response FSM:

```verilog
422  RESP_READ:
...
427        end else if (~cmd_ack_ad9866) begin
428          resp_cmd_data_next = cmd_resp_data_i2c; // FIXME: suppor read cmd_resp_data_ad9866
```

When the AD9866 SPI controller signals a completed read, the I²C read-data register
is captured instead (the author left the same FIXME in the alt-response copy at
line 877). Host software reading AD9866 state gets whatever the EEPROM sequencer
last returned. There is also no arbitration when both slaves ack low simultaneously.

**b) RX gain writes are no-ops on non-fast-LNA variants.** In `ad9866ctrl.v` the
register updates are commented out:

```verilog
113:    //rx_gain <= rx_gain_next;
120:  //rx_gain_next = rx_gain;
```

`CMD_IDLE` still detects a changed gain (line 150) and jumps to `CMD_RXGAIN`, which
then transmits the **old** `rx_gain` value over SPI. The missing default assignment
also infers a latch on `rx_gain_next`. `hl2b5up_main` prunes this path
(`FAST_LNA=1`, gains handled in `ad9866.v`), but every `FAST_LNA=0` build — e.g.
`hl2b3to4_main` from the same tree — cannot set receiver attenuation.

**c) No timeout anywhere in the I²C chain.** `i2c_master.v` waits indefinitely for
SCL/SDA (`delay_scl`/`delay_sda` states), so a slave that clock-stretches forever or
an SDA stall leaves `ready` low forever; `i2c_bus2` command states then hang, and
`control.v`'s RESP FSM parks in `RESP_ACK`/`RESP_READ` waiting for `cmd_ack_i2c`.
Every host interaction that requires responses stalls while the radio keeps
transmitting on its last commanded frequency until power-cycle. `lost_clock`
recovery only covers the AD9866-clock-loss case, not a stuck bus.

**Fix direction:** add a second read-data port from `ad9866ctrl` and mux on which
ack dropped; restore the two commented lines (and re-test with `test_i2c_bus2.py`);
add a prescaler-bus timeout + bus-recovery (9 SCL toggles) in the master, feeding an
error response instead of silence.

---

## Bug 5 — `usiq_fifo` shorts write- and read-side occupancy counters onto one net

> **Status: fixed** by the R3 FIFO-library refactor (see
> [Refactor Plan](Refactor-Plan) §R3): all FIFOs are built on a shared
> `stream_fifo` shell whose write-side and read-side counts are structurally
> separate nets, and `usiq_fifo` backpressure now uses the write-side count.
> Kept below as a record of the original review finding.

**Location:** `gateware/rtl/fifos.v:222-255` (`usiq_fifo`):

```verilog
236 ) fifo_i (
...
241   .wrusedw (wr_tlength),
...
248   .rdusedw (wr_tlength),
```

Both the write-domain occupancy output (`wrusedw`) and the read-domain occupancy
output (`rdusedw`) of the `dcfifo` megafunction drive the same wire. These are
independently computed values in different clock domains; electrically the net ends
up contended (or Quartus arbitrarily picks one driver). That wire is then used as
the near-full watermark:

```verilog
255 assign wr_tready = (wr_tlength > 11'd1012) ? 1'b0 : 1'b1;
```

So the backpressure gating the **primary receive sample path**
(`radio → usiq_fifo → usopenhpsdr1 → UDP`) tests an undefined occupancy. In
simulation the value is X; in hardware it depends on synthesis resolution. Because
the read side normally drains faster than 48 ksps × channels fills, the bug is
mostly dormant — but under upstream backpressure (slow host, pause storms) the FIFO
can overflow silently, dropping I/Q words mid-frame and producing clicks or corrupted
frames rather than clean flow control.

**Fix:** split into `wr_tlength`/`rd_tlength` nets (as `dsiq_fifo` correctly does),
drive `wr_tready` from the write-side count, and expose the read-side count as the
existing `rd_tlength` output. Zero resource cost; removes undefined behaviour from
the audio path.

---

## Honorable mentions (not top-5, but should be on the radar)

| Issue | Location | Note |
|---|---|---|
| Combinational RX clock mux + flop-as-clock for 100 Mb/s mode | `hermeslite_core.v:395-399` | Glitch-prone mux selecting between `phy_rx_clk` and a ÷2 toggle FF; safe only because speed changes happen with link down |
| Frequency multiply crosses domains unguarded | `radio.v:316-321` | Author's own comment: *"not guarded by CDC handshake… This really should be done on the PC"* — works because commands are spaced milliseconds apart |
| `last_chan` not clamped to built NR | `radio.v:269-274,767` | A host requesting more receivers than `NR` indexes undriven arrays; garbage upstream samples |
| Lost-update on amp UART announcer | `extamp.v:118-122` | Frequency change during a message is silently absorbed; amp never told |
| hl2link data path uses single-flop sampled input | `hl2link.v:267-286` | Negotiation is double-synced, payload is not; relies on mesochronous boards |
| Source MAC derived from raw jumper pin combinationally | `hermeslite_core.v:444` | Bouncing contact can glitch MAC bytes mid-frame construction |
| Watchdog disable bit accepted from any RUNSTOP byte | `dsopenhpsdr1.v:399-401` | Bit 7 of any data frame kills the run watchdog until next RUNSTOP |
| Asymmetric NCO accumulator reset | `nco2.v:29-37` | Reset clears `angle0` only; harmless today, surprising later |
| `udp_send` byte counter has no reset | `udp_send.v:53,80` | First post-configuration packet length depends on uninitialized state |
| PHY polling assumes KSZ9021-style reg 0x1F | `phy_cfg.v:104-109` | Other PHYs report garbage speed bits; link detect may fail |
