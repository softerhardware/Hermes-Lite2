# Comparison with the wiki "Architecture" page

Compared: the wiki page <https://github.com/softerhardware/Hermes-Lite2/wiki/Architecture> (added 2026-09-06 by Steve Haynal, self-described as "AI generated and has not been verified") against `HL2_GATEWARE_ARCHITECTURE.md` / `HL2_GATEWARE_FINDINGS.md`, both checked against the RTL at commit `3e467fd` (2026-07-30). Upstream `master` is at the same commit; the only other branch, `experimental_protocol_changes`, was also searched for the constructs the wiki names.

Headline: the wiki is a usable high-level overview, but roughly a fifth of its concrete statements are wrong, and its clock-domain-crossing and command-bus sections describe source files and helpers that do not exist in any branch of the repository. It contains no register map and no defect analysis. The comparison also exposed two errors and one omission in my own documents, now corrected (Section 3).

---

## 1. Wiki statements about code that does not exist

| Wiki claim | What the repository contains | Evidence |
|---|---|---|
| "The authoritative address map, crossing contract and responder table live in `rtl/cmd_bus.vh`, included by every consumer"; `CMDA_*` symbols such as `CMDA_VNA_TXGAIN` | No such file in `master` or `experimental_protocol_changes`. Every consumer decodes raw hex literals; address 0x39 is decoded in six modules, 0x00 in three, with bit positions repeated in each | `git ls-tree` of both branches; `grep -r "cmd_addr == 6'h"` |
| "simple single-address slaves can use the `cmd_slave` capture helper from `rtl/cmd_slave.v` (see `dsopenhpsdr1`)" | No such file; `dsopenhpsdr1` decodes 0x0F and 0x39 inline (`dsopenhpsdr1.v:391-402`) | same |
| "All of the above are thin policy wrappers around one shared shell, `stream_fifo` in `rtl/fifos.v` … single point of configuration" | `fifos.v` holds five independent wrappers (`dsiq_fifo`, `dslr_fifo`, `usiq_fifo`, `usbs_fifo`, `asmi_fifo`), each instantiating `dcfifo`/`dcfifo_mixed_widths` directly with its own parameter list | `fifos.v:2-421` |
| CDC toolkit includes "`sync_qualifier` (multi-bit bus captured under a synced valid toggle) and `sync_handshake` (four-phase pulse transfer)" | `sync.v` has `sync`, `sync_pulse`, `sync_one`, and a two-register `sync_handshake` that is neither four-phase nor instantiated anywhere. Multi-bit buses are crossed by convention (toggle + quasi-static data), not by a primitive | `sync.v:28-106`; `grep -r sync_handshake` finds only the definition |
| "Every remaining raw crossing carries a `// QUASI_STATIC_CDC:` annotation for grep-ability" | Zero occurrences in the tree | `grep -r QUASI_STATIC_CDC` |
| "mixers and receivers are produced by two `generate` loops in `radio.v` (`MIXPAIR`/`RXCHAIN`)" | Explicit per-count blocks `if (NR >= 2) begin: MIX1_3 … RECEIVER1 … MIX4_5 … RECEIVER9` | `radio.v:508-703` |

Reading: these six items read like a refactoring plan (or a private working tree) rather than the released 74.2 gateware. Anyone using the wiki to navigate the code will look for files and symbols that are not there. The improvement I listed as "centralise the register decode" (findings, area 5) is essentially what the wiki already claims to be true.

---

## 2. Factual errors in the wiki

Each row gives the wiki statement, the behaviour in the RTL, and where to look.

| # | Wiki says | RTL does | Reference |
|---|---|---|---|
| 1 | Clock-tree diagram: "combinational mux + ÷2 toggle FF" feeds `clock_ethtxext` | Both transmit clocks (`clock_ethtxint`, `clock_ethtxext`) use `altclkctrl` instances. The logic mux with the ÷2 flop is the **receive** clock. The wiki's own paragraph under the table says this correctly, so the page contradicts itself | `hermeslite_core.v:356-399` |
| 2 | `ad9866`: "LVDS DDR serializer/deserializer", "DDR-deserialized 12-bit words", "DAC/LVDS serialization" | The AD9866 bus is 3.3 V single-ended LVCMOS, single-data-rate at 153.6 MHz with two 6-bit halves per sample. No DDR primitive is used on that path; `altddio_in/out` exist only for RGMII | `ad9866.v:158-229`, `boards/hl2b5up/general.tcl` (default I/O standard), `grep -rl altddio` |
| 3 | DAC serializer uses "EF FE framing" | 0xEF 0xFE is the Ethernet protocol preamble; the AD9866 bus is framed by `TXSYNC` only | `ad9866.v:185-201` |
| 4 | "`txquiet_n` gates the PA during silence" | It drives the AD9866 TXQUIET input (`= tx_en_d1`). PA and bias gating are `pwr_envpa/envbias/envop`, `pa_inttr/exttr` in `control` | `ad9866.v:205`, `control.v:359-365` |
| 5 | "RX/TX gain banks switch only outside transmit to avoid thumps" | With 0x0E bit 15 set the TX gain bank is applied **during** transmit; the RX bank is restored when `tx_en` drops, and gain is forced to 0 during CW | `ad9866.v:144-152` |
| 6 | Watchdog: "no valid packet start within ~4096 ms-ticks" | The tick is `watchdog_up`, toggled once per bandscope interval `(N+1) << rate` EP6 packets; 4095 ticks ≈ 21 s at 48 kSPS with one receiver and scales with rate and receiver count | `dsopenhpsdr1.v:406-414`, `usopenhpsdr1.v:242-247` |
| 7 | "`ds_cmd_*` — one command slot per packet" | One per 512-byte frame, two per 1032-byte packet | `dsopenhpsdr1.v:373-378` |
| 8 | "SDR data frame (port 512/513)" | UDP ports 1024/1025; 512 is `port >> 1` in the comparison | `dsopenhpsdr1.v:185`, `udp_recv.v:90` |
| 9 | Frame layout: I/Q rounds, mic bytes, "then a 5-byte command-response slot (`7F 7F 7F` + 40-bit resp)" | The sync bytes and the five response bytes come **first** in each 512-byte frame, followed by the I/Q rounds and padding | `usopenhpsdr1.v:377-414` |
| 10 | Command CDC is "safe because commands arrive milliseconds apart" | Consecutive frames' commands are ~4 µs apart at 1 Gb. The crossing is still safe, but for a different reason: the data is written before the toggle and is stable for the two or three destination cycles the synchroniser takes | `sync.v:49-64`, `hermeslite_core.v:765-769` |
| 11 | `dsiq_fifo`: "~8 ms buffer" | 16384 bytes = 4096 I/Q samples = 85 ms at 48 kSPS. The figure comes from a stale comment; the same comment's 10 ms / 5 ms marks are also wrong (¼ full = 21 ms, ⅛ full = 10.7 ms) | `fifos.v:34-42` |
| 12 | "`CicInterpM5` — CIC interpolate ×5" | "M5" is the filter order (five stages); the interpolation factor is `RRRR = 200` (384 kHz → 76.8 MHz) | `radio.v:93,1138`, `CicInterpM5.v:37-40` |
| 13 | TX gain: "CIC loss 0.61 × CORDIC 1.65 × ¼ × 4 ≈ 1.0" from the comment block at `radio.v:847-881` | That comment describes an earlier 2560:1 chain and is stale. The current chain measured from the coefficient files: FIR 0.814 × CIC 0.745 × CORDIC 1.647 ÷ 16 = 0.0624, so a full-scale 16-bit I/Q vector gives DAC code 2046 (unity at the rail) | `firrom/coefI8_1024.txt` (each phase sums to 0.814 × 2¹⁷), `radio.v:1145-1191` |
| 14 | "CORDIC everywhere for mixing (RX pre-mix handled by the shared `mix2` …) — shift/add only, no DSP blocks" | RX mixing is a ROM-based NCO with hardware multipliers (`lpm_mult`); `cordic.v` is instantiated only by `receiver.v`, which this variant does not use. Only the transmitter uses a CORDIC | `mix2.v:63-75`, `primitives/intel/multipliers.v`, `grep -rn "cordic cordic_inst"` |
| 15 | "Multipliers go exclusively through `primitives/*/multipliers.v` wrappers" | Inline `*` in the RX FIR (`firfilt.v:323,329`), the TX FIR (`FirInterp8_1024.v:215-216`), the 32×32 frequency multiply (`radio.v:321`) and the CALCTYPE-3 fine sine (`sincos.v:148`); the AK4951 sidetone uses `mult_s9_s8_s16`/`mult_s16_s8_s16` megafunctions | as listed |
| 16 | Slow ADC is an "ADS7828 poller" | The RTL addresses 7-bit 0x34, writes configuration 0x07 and reads 8 bytes with the upper nibble in the low four bits of each first byte — the MAX1236-family transaction. An ADS7828 answers at 0x48–0x4B with a different command byte. No other wiki page or repository file names the part, so the schematic was not checked | `slow_adc.v:117-181` |
| 17 | "PSU sync ~1.08 MHz square" | Divide-by-59 toggle: 125 MHz / (2 × 59) = 1.059 MHz (the wiki is close; my original figure of 2.12 MHz was the toggle rate and has been corrected) | `control.v:511-536` |
| 18 | hl2link "forwards commands and RX samples to a slave board, injects its samples into the master's upstream stream … stall handshakes" | Commands go master → slave; receiver samples go slave → master. The TX-I/Q frame type (11) and the stall request exist in the link module but are never used (`stall_req = 0`) | `hl2link_app.v:55-61` |
| 19 | CW "honouring … the internal iambic keyer (`cw_openhpsdr` + `iambic.v` on the 48 kHz domain)" presented as part of this variant | `hl2b5up_main` builds `CW = 1`: straight key and PTT taken from the phone jack through the debouncer. The iambic keyer exists only in the AK4951 variants (`CW = 2`); `cw_basic.v` is never instantiated by any variant | `variants/hl2b5up_main/hermeslite.v:105`, `control.v:783-823` |
| 20 | "Broadcast frames are accepted when running; unicast requires matching `local_ip`" | Broadcast to ports 1024/1025 is accepted regardless of `run`; the `run` input of `udp_recv` is not used inside the module | `udp_recv.v:26,86-92` |
| 21 | External amplifier: "Elecraft KPA-50 style amp" | Target is the JI1UDD HR50 amplifier; only the command format (`FA…;`) is Elecraft's | `hermeslite_core.v:109-110`, `extamp.v:1-3` |
| 22 | `USE_ALTSYNCRAM=1` "(infer M9K RAMs)" | Selects the `altsyncram` megafunction wrappers with `.mif` initialisation instead of the behavioural `$readmemb` models; both map to M9K | `firromH.v`, `firram36.v` |
| 23 | "ARP replies and ICMP replies are sent to that cached entry" (the `mac_recv`/`ip_recv` cache) | ARP uses the sender MAC captured at the start of the ARP frame and the sender IP from the ARP payload; only ICMP and DHCP use the `ip_recv` cache (and that path has the synchroniser bug B2) | `arp.v:67,88`, `network.v:700-706` |

Accurate wiki statements worth confirming: the reset timeline (0.41 / 0.82 / 6.5 / 13 / 26 ms), the 1/3/7 s DHCP retries and APIPA fallback, the 333-word start threshold, the EP4 sequence-number alignment, `CALCTYPE = 3` as an M9K-for-logic trade, the 976-tap four-engine FIR, the three-cycle frequency pipeline, PureSignal feeding receiver 2 with the DAC word, the VNA 1024-sample averaging, the `dsiq_fifo` drop-and-restart hysteresis, and the observation that `files.tcl` has duplicate entries.

---

## 3. Corrections made to my documents as a result of the comparison

| Item | Was | Now |
|---|---|---|
| Supply-sync frequency (architecture §13) | 2.12 MHz | 1.06 MHz (toggle every 59 cycles → period 118 cycles) |
| Simulation framework (findings, area 1; architecture §1) | "cocotb scripts" | MyHDL co-simulation testbenches under Icarus Verilog (`sim/test_cordic.py` imports `myhdl`) |
| `files.tcl` (architecture §1, findings area 5) | only "compiles unused files" | added the eight duplicated entries |
| Sensor ADC (architecture §2, §13) | "4-channel 12-bit I2C ADC at 0x34" | identified the transaction as MAX1236-compatible |

None of the twelve bugs or five improvement areas changed.

---

## 4. Coverage differences

| Topic | Wiki page | These documents |
|---|---|---|
| Register map with bit fields and consuming module | None (defers to the non-existent `cmd_bus.vh`) | Complete (architecture §7.1) |
| Command responses, alternate responses, status round-robin | One paragraph | Mechanism, timing and error path (§7.2) |
| Discovery / extended packet byte layout | Named only | Byte-by-byte (§9) |
| TX state machine, hang/latency timers, tape-recorder alignment | Named only | Full (§11.1–11.2) |
| hl2link framing and training sequence | One table row | Full (§15) |
| Versa 5 register sequences, EEPROM map, AD9866 SPI init table | Not covered | §12, §14, §7.1 |
| Timing constraints | Not covered | §18 |
| Gain figures | Stale comment repeated | Measured from coefficient files (§10.3, §11.3) |
| Diagrams | Mermaid | ASCII |
| Bugs and improvement areas | None | 12 bugs, 5 areas |

---

## 5. Cross-check against the wiki "Protocol" page (the official specification)

The Protocol page is hand-written and largely matches the RTL. Differences found while checking both analyses:

| Item | Protocol page | RTL |
|---|---|---|
| 0x00 bit 10 "VNA fixed RX gain (0 = −6 dB, 1 = +6 dB)" | Documented | No consumer of `cmd_data[10]` anywhere; not implemented |
| 0x2B predistortion field | `[19:16]` | `[17:16]` (`radio.v:291`) |
| 0x39 `[27:24]` | 0x8 enable / 0x9 disable watchdog | Also 0xA / 0xB = force-discovery-on-data off / on (`usopenhpsdr1.v:512-515`), undocumented |
| 0x3C/0x3D bit 23 "stop at end" | "not currently used" | Ignored, consistent |
| Discovery byte 0x1B | bit 7 key, bit 6 PTT, bits 1:0 clip count | Bits 5:2 also carry `pa_exttr`, `pa_inttr`, `tx_on`, `cw_on` (`control.v:899`), undocumented |
| Discovery bytes 0x25–0x29 | Reserved | Packet counter, TX buffer latency, CW hang, PTT hang, rate/PTT/wait/receivers (`EXTENDED_DEBUG_RESP`), undocumented |
| 0x17 defaults | 12 ms PTT hang, 20 ms latency | Matches `radio.v:934-935`; the packer's copies default to 4 ms / 10 ms until software writes them, so early discovery packets report those (`usopenhpsdr1.v:108-109`) |
| Classic response "C0[1] Dash always zero" | Documented | Matches (`control.v:472-475`) |
| Bandscope format byte 0x14 `[7:6] = 01` (16-bit) | Documented | `BANDSCOPE_BITS = 2'b01`; samples are 12-bit left-justified in 16 bits (`usopenhpsdr1.v:353,362`) |
| EEPROM read data layout `[31:24] = value, [15:8] = value` | Documented | Matches; boot-time reads use `[15:8]` (`i2c.v:518-568`) |
