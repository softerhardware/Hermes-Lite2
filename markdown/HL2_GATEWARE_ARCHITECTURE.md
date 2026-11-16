# Hermes-Lite 2 Gateware — Architecture and Detailed Reference

Target: Intel/Altera Cyclone IV E **EP4CE22E22C8** (144-pin EQFP, speed grade 8, 22 320 LEs, 66 M9K blocks = 594 kbit, 66 18×18 multipliers, 4 PLLs).
Reference build: `variants/hl2b5up_main` (gateware version **74.2**, `hermeslite_core.v:142-143`). All file references are relative to `gateware/`.

This document describes what the RTL actually does as of commit `3e467fd`. It was produced by reading every module compiled into the hl2b5up_main variant. Companion document: `HL2_GATEWARE_FINDINGS.md` (bugs and improvement areas).

---

## 1. Build variants and parameters

Every variant is a thin top-level wrapper (`variants/<name>/hermeslite.v`) that instantiates `hermeslite_core` with a parameter set. The board directory (`boards/hl2b5up/`) supplies pins, I/O standards, PLL placement, timing constraints and the file list.

| Parameter | hl2b5up_main | Meaning |
|---|---|---|
| `BOARD` | 5 | Board revision reported in discovery byte 20 (`{2'b01, BOARD[5:0]}`) |
| `MAC` | 00:1c:c0:a2:13:dd | Default MAC; bit 1 is inverted by jumper input `io_cn10` (`io_alternate_mac`) |
| `NR` | 4 | Receivers (max 10 in `radio.v`) |
| `NT` | 1 | Transmitter present (0 removes the whole TX chain and the 16 kB TX FIFO) |
| `CLK_FREQ` | 76 800 000 | ADC/DAC clock; selects NCO constant, CIC rates, TX interpolation |
| `UART` | 1 | JI1UDD HR50 amplifier band-data UART on `io_db1_3` |
| `ATU` | 1 | ICOM AH-4 tuner sequencer on `io_db1_5/6` |
| `FAN` | 1 | Fan PWM on `io_db1_4` (or MI0BOT band-volts DAC) |
| `PSSYNC` | 1 | Switch-mode supply sync clocks `pwr_clk3p3/1p2` |
| `CW` | 1 | 0 = none, 1 = straight key on phone jack, 2 = openHPSDR iambic keyer |
| `LRDATA` | 0 | Use of PC→radio audio bytes: 0 unused, 1 predistortion LUT, 2 EER envelope |
| `ASMII` | 1 | In-system EPCS flash programming + remote update |
| `HL2LINK` | 1 | Two-board synchronisation link on `io_link_rx/tx` |
| `FAST_LNA` | 1 | LNA gain sent through the AD9866 TX data bus (no SPI) |
| `AK4951` | 0 | Local audio codec companion board |
| `EXTENDED_RESP` | 1 | Port-1025 command responses in discovery-format packets |
| `EXTENDED_DEBUG_RESP` | 1 | Extra status bytes (37–41) in the discovery packet |
| `DSIQ_FIFO_DEPTH` | 16384 | TX I/Q FIFO depth in bytes |
| `BYPASS_VERSA` | 0 | AD9866 register 4 = 0x36 (use AD9866 internal clock path) |

Other variants: `hl2b5up_6rx` (NR=6, NT=0), `hl2b5up_cicrx` / `hl2b3to4_cicrx` (NR=10, NT=0, CIC-only receivers), `hl2b5up_15ce` (NR=2, for EP4CE15), `hl2b5up_ak4951v3/v4` (AK4951=1, CW=2), `hl2b5up_bypassversa`, `hl2b5up_4000` (`receiver_4000.v`), `hl2b2_main` (BOARD=2 reports version 54.x), `hl2b3to4_main`. The `radioberry_*` variants share `rtl/radioberry/` and are Cyclone 10 LP targets; they are outside the scope of this document.

Build macros (`hermeslite.qsf`): `BETA5=1`, `USE_ALTSYNCRAM=1` (selects Altera ROM/RAM megafunctions instead of inferred `$readmemb` memories). `AK4951` and `HALFDUPLEX` are additional macros used by some modules (note the AK4951 feature is controlled by **both** a parameter and a macro; see findings).

Build flow: `make` in the variant directory runs `quartus_sh --flow compile`, then `quartus_cpf` produces `.jic`, `.jam`, `.svf`; `variants/Makefile release_test` copies `.rbf` files into `bitfiles/testing/<date>_<major>p<minor>_<hash>`. `boards/hl2b5up/files.tcl` lists eight files twice (`firfilt.v`, `CicInterpM5.v`, `firram36I_1024.v`, `FirInterp8_1024.v`, `firram36.v`, `vna_scanner.v`, `firromH.v`, `firromI_1024.v`) and compiles receiver families (`receiver.v`, `receiver2/`, `qs1r/`, `receiver_ciconly.v`, `receiver_4000.v`) that this variant never instantiates; Quartus tolerates both. Simulation: `sim/` holds MyHDL co-simulation testbenches run with Icarus Verilog (`sim/Makefile` runs only `test_cordic.py`).

---

## 2. Hardware context (what the FPGA talks to)

| Device | Interface | Gateware modules |
|---|---|---|
| AD9866 12-bit mixed-signal front end (ADC + DAC, 76.8 MHz) | 6-bit interleaved RX bus + RXSYNC/RXCLK, 6-bit interleaved TX bus + TXSYNC, 3-wire SPI, PGA5, MODE, RST | `ad9866.v`, `ad9866ctrl.v` |
| KSZ9031RNX (or KSZ9021) Gigabit PHY | RGMII (4-bit DDR), MDIO/MDC, 125 MHz reference in, reset in | `ethernet/*` |
| Renesas 5P49V5923 "Versa 5" clock generator | I2C bus 1 (`clk_scl1/sda1`), 7-bit address 0x6A | `i2c.v` |
| MCP4662 dual digital pot with EEPROM (bias + config store) | I2C bus 2 (`io_scl2/sda2`), 7-bit address 0x2C | `i2c.v`, `i2c_bus2.v` |
| MCP23008 I/O expander (filter/antenna relays) | I2C bus 2, address 0x20 | `i2c_bus2.v` |
| 4-channel 12-bit I2C ADC, MAX1236-compatible (temperature, forward/reverse power, PA bias current) | I2C bus 3 (`io_adc_scl/sda`), address 0x34 | `slow_adc.v` |
| EPCS16 configuration flash | Active-serial (ASMI megafunction) | `asmi_interface.v`, `remote_update.v` |
| AK4951 audio codec (companion board) | I2S + I2C bus 1 (address 0x12) | `localaudio/*` |
| Second HL2 (hl2link) | 2 + 2 LVCMOS pins `io_link_rx/tx` | `hl2link.v`, `hl2link_app.v` |
| Phone jack (key/PTT), CN8/9/10 jumpers, DB1 header, 4 LEDs, PA/TR relay drives, supply sync | GPIO | `control.v` |

---

## 3. Module hierarchy (hl2b5up_main)

```
hermeslite (variants/hl2b5up_main/hermeslite.v)         top: pin names only
└── hermeslite_core (rtl/hermeslite_core.v)             clocks, resets, FIFOs, CDC, glue
    ├── ethpll (altpll)                                  125 MHz → 125/0°, 125/90°, 2.5, 25, 12.5 MHz
    ├── ad9866pll (altpll)                               76.8 MHz → 76.8, 153.6, 245.76 MHz, 48 kHz
    ├── altclkctrl ×2                                    1 Gb/100 Mb TX clock muxes
    ├── network (ethernet/network.v)                     MAC/IP/UDP/ARP/ICMP/DHCP + PHY config
    │   ├── phy_cfg → mdio                               PHY init and link status polling
    │   ├── rgmii_recv → ddio_in                         DDR nibble capture, preamble detect
    │   ├── mac_recv, ip_recv, udp_recv                  receive parsers
    │   ├── arp, icmp (+icmp_fifo), dhcp                 responders
    │   ├── udp_send → ip_send → mac_send (+crc32)       transmit header shifters
    │   └── rgmii_send → ddio_out
    ├── dsopenhpsdr1 (dsopenhpsdr1.v)                    Protocol-1 downstream decoder (rx clock)
    ├── usopenhpsdr1 (usopenhpsdr1.v)                    Protocol-1 upstream packer (tx clock)
    ├── dsiq_fifo, usiq_fifo, usbs_fifo, asmi_fifo       dual-clock FIFOs (fifos.v)
    ├── ad9866 (ad9866.v)                                ADC capture / DAC interleave / fast LNA
    ├── radio (radio_openhpsdr1/radio.v)                 DSP: NCOs, receivers, transmitter, VNA
    │   ├── vna_scanner
    │   ├── mix2 ×2 (NR=4) → nco2 → sincos → coarserom/finerom + lpm_mult
    │   ├── receiver_nco ×4 → cic, varcic ×2, firX8R8 → fir256 ×4 → firromH, firram36
    │   ├── FirInterp8_1024 → firromI_1024, firram36I_1024
    │   ├── CicInterpM5
    │   └── cpl_cordic
    ├── control (control.v)                              slow-domain supervisor (2.5 MHz)
    │   ├── i2c → i2c_bus2 → i2c_master                  Versa/EEPROM/expander
    │   ├── slow_adc → i2c_master                        sensor ADC
    │   ├── ad9866ctrl                                   AD9866 SPI
    │   ├── led_flash ×2, debounce ×3
    │   ├── extamp (UART), exttuner (ATU)
    │   └── cw_basic / cw_openhpsdr → iambic             (selected by CW)
    ├── hl2link_app → hl2link                            two-board link
    ├── asmi_interface → asmi_asmi_parallel_0            flash programming
    ├── remote_update → altera_remote_update_core        image selection / reboot
    └── sync, sync_pulse, sync_one                       CDC primitives (sync.v)
```

---

## 4. Clocks, resets and clock domains

### 4.1 Clock generation

`ethpll` (`ethpll.v`, input 125 MHz from the PHY, `inclk0_input_frequency = 8000` ps):

| Output | Name in core | Frequency | Phase | Use |
|---|---|---|---|---|
| c0 | `clock_125_mhz_0_deg` | 125 MHz | 0° | internal TX logic clock at 1 Gb |
| c1 | `clock_125_mhz_90_deg` | 125 MHz | 90° (3000 ps) | RGMII TX clock output to PHY at 1 Gb |
| c2 | `clk_ctrl` | 2.5 MHz | 0° | control block, I2C, MDIO, DHCP FSM |
| c3 | `clock_25_mhz` | 25 MHz | 99° (11000 ps) | RGMII TX clock output at 100 Mb |
| c4 | `clock_12p5_mhz` | 12.5 MHz | 0° | internal TX logic clock at 100 Mb |

`ad9866pll` (`ad9866pll.v`, input 76.8 MHz from the AD9866 CLKOUT, `self_reset_on_loss_lock = ON`, `areset = ~ethup`):

| Output | Name | Frequency | Use |
|---|---|---|---|
| c0 | `clk_ad9866` | 76.8 MHz | all DSP, AD9866 data, hl2link |
| c1 | `clk_ad9866_2x` | 153.6 MHz | AD9866 6-bit bus interleaving, NCO time-multiplex, RX FIR MACs |
| c2 | `clk_envelope` | 245.76 MHz | EER PWM ramp (LRDATA=2 only) |
| c3 | `clk_ad9866_slow` | 48 kHz | iambic keyer tick |

Ethernet speed muxing (`hermeslite_core.v:353-399`): `speed_1gb` from the PHY status is registered on `clk_ctrl` and drives two `altclkctrl` muxes (`clock_ethtxint` = 125 or 12.5 MHz; `clock_ethtxext` = 125/90° or 25 MHz → `phy_tx_clk`). The receive clock is muxed in logic: `clock_ethrxint = speed_1gb ? phy_rx_clk : phy_rx_clk_div2` (the comment notes the clkctrl primitive would not map for this case).

### 4.2 Reset sequence

There is no global reset. `ethup = ethpll_locked & phy_rst_n` (PHY reset is an RC on the board, ~50 ms). `control.v:187-205` runs a free 16-bit counter on `clk_ctrl` once `ethup` is true (it never restarts):

| Count | Time after ethup | Event |
|---|---|---|
| 1024 | 0.41 ms | `clk_i2c_rst` released — I2C controllers run, AK4951 PDN released |
| 2048 | 0.82 ms | `clk_i2c_start` — Versa 5 initialisation sequence starts, then EEPROM read |
| 16384 | 6.5 ms | `slow_adc_rst` released; `use_eeprom_config` latched (ignore EEPROM IP/MAC if key and PTT are both grounded) |
| 32768 | 13 ms | `rffe_ad9866_rst_n` high |
| 65535 | 26 ms | `ad9866_rst = ~saturated | ~ad9866up` released once the AD9866 PLL locks → SPI register init runs |

The AD9866 PLL is held in reset until `ethup`, so nothing in the 76.8 MHz domain runs before the PHY is out of reset. `rst_all`/`rst_nco` are software resets that exist only with `HL2LINK=1` (command 0x39). The `radio` input `rst_channels` is never connected.

### 4.3 Clock domains and crossings

| Domain | Clock | Contents |
|---|---|---|
| ETH-RX | `clock_ethrxint` (125 / 12.5 MHz from PHY) | `rgmii_recv`, `mac/ip/udp_recv`, ARP/ICMP/DHCP receive halves, `dsopenhpsdr1`, FIFO write ports |
| ETH-TX | `clock_ethtxint` (125 / 12.5 MHz from PLL) | `usopenhpsdr1`, `udp/ip/mac_send`, `rgmii_send`, transmit halves of ARP/ICMP/DHCP, FIFO read ports |
| CTRL | `clk_ctrl` 2.5 MHz | `control`, I2C, MDIO, network state machine (runs on **negedge**), ASMI, remote update |
| DSP | `clk_ad9866` 76.8 MHz | `radio`, `ad9866`, `hl2link`, `localaudio` |
| DSP2X | `clk_ad9866_2x` 153.6 MHz | inside `ad9866`, `mix2/nco2/sincos`, `fir256` |

The SDC (`boards/hl2b5up/timing.sdc:70-82`) declares three asynchronous groups: {ETH-TX + CTRL + PHY 125 MHz}, {ETH-RX}, {all AD9866 PLL outputs + 76.8 MHz input}.

CDC primitives (`sync.v`):
- `sync` — 2-flop synchroniser for level signals.
- `sync_pulse` — 3-flop chain, output = XOR of the last two stages: converts a **toggle** in the source domain into a one-cycle pulse. This is the universal "event" mechanism (`cmd_cnt`, `discover_cnt`, `alt_resp_cnt`, `ds_pkt_cnt`, `resp_rqst`, `rxclrstatus`, `dsiq_sample`, `watchdog_up`, …).
- `sync_one` — rising-edge detector of a synchronised level; used for the 1 ms / 0.25 ms pulses going from CTRL into faster domains.

The command bus (Section 7) relies on the convention "write data, then toggle the counter"; consumers sample the data several cycles after their local pulse, so the multi-bit data is quasi-static when read. FIFOs are Altera `dcfifo` / `dcfifo_mixed_widths` with 4-stage pointer synchronisers.

---

## 5. Data flow overview

```
 PC ──UDP 1024/1025──► KSZ9031 ──RGMII──► rgmii_recv → mac_recv → ip_recv → udp_recv
                                                                     │ (byte stream + to_port + broadcast)
                                                                     ▼
                                        dsopenhpsdr1 (frame sync, C&C, PTT, I/Q bytes, ASMI data)
                                          │ cmd_addr/data/cnt          │ 9-bit bytes {tuser,byte}
                                          ▼                             ▼
                              [hl2link_app (master/slave routing)]   dsiq_fifo 16 kB (ETH-RX → DSP)
                                          │                             │ 4×9 → 36-bit words @ 48 kHz
                                          ▼                             ▼
                control ◄─ cmd ─► radio ◄─ cmd ─► ad9866 ◄─ cmd ─► ad9866ctrl/i2c/…      radio TX:
                 (2.5 MHz)         │                                               FIFO → TX FSM → FIR×8 → CIC×200 → CORDIC → DAC
                                   │ rx samples (24-bit I,Q per receiver, tlast)
                                   ▼
                             usiq_fifo 1024 words (DSP → ETH-TX)      usbs_fifo 2048×12 (ADC raw for bandscope)
                                   │                                          │
                                   ▼                                          ▼
                             usopenhpsdr1 (EP6 I/Q frames, EP4 bandscope, discovery, responses)
                                   │ udp_tx_request / data / length
                                   ▼
                             udp_send → ip_send → mac_send → rgmii_send ──RGMII──► PHY ──► PC
```

Sample rates (CLK_FREQ = 76.8 MHz): ADC 76.8 MSPS → receiver output 48/96/192/384 kSPS (decimation 1600/800/400/200). TX: 48 kSPS in → ×8 FIR → ×200 CIC → 76.8 MSPS DAC.

---

## 6. Ethernet and IP stack (`rtl/ethernet/`)

The stack is the Metis/openHPSDR byte-serial stack (VE3NEA/VK6APH) with HL2 modifications. Every layer is a shift-register header generator (TX) or a byte-counting parser (RX); there is no packet buffering except the ICMP echo FIFO.

### 6.1 PHY configuration (`phy_cfg.v`, `mdio.v`)
- `mdio` bit-bangs a 64-bit MDIO frame on `clk_ctrl` (MDC = 2.5 MHz), PHY address 7. State changes on the falling edge of MDC; read data is shifted in on the falling edge (see findings for the sampling-edge caveat).
- `phy_cfg` continuously alternates reads of register 0x1F (PHY Control: speed bits 6:5, duplex bit 3) and register 0x03 (PHY ID2, bits 5:4 = 01 identifies a KSZ9021). On `init_request` (once, network state `ST_PHY_INIT`) it writes: for KSZ9021 the extended registers 0x104 = 0xC277 and 0x105 = 0x2222 (RGMII clock/data pad skews via MMD registers 0x0B/0x0C), then for both PHYs register 9 = 0x0200 (advertise 1000BASE-T full duplex only) and register 0 = 0x1300 (restart auto-negotiation).
- `phy_connected_int = duplex && speed != 00 && speed != 11` (10 Mb is treated as "not connected").

### 6.2 Network state machine (`network.v:128-285`, negedge `clk_ctrl`)
`START → PHY_INIT → PHY_CONNECT` (wait for link; latch `speed_1gb_i`) `→ PHY_SETTLE` (1 s) → either `RUNNING` with the EEPROM static IP (if `eeprom_config[7] & ~eeprom_config[5]`) or DHCP: `DHCP_REQUEST → DHCP` (retransmit discover at 1, 3, 7 s; after 15 s fall back to the static IP if `eeprom_config[7] & eeprom_config[5]`, else APIPA `169.254.<mac[15:8]>.<mac[7:0]>`) `→ DHCP_RENEW_WAIT` (half the lease, 12 h if none) `→ RENEW_REQ → RENEW_ACK`. Link loss returns to `PHY_CONNECT`. Outputs `network_state_dhcp`/`network_state_fixedip` are low once an address is valid; both feed `have_ip` in the packer and the LED logic.

`rx_reset`/`tx_reset` (state ≤ PHY_SETTLE) hold ARP/ICMP/DHCP/MAC/UDP senders and the RGMII receiver in reset while the speed is being switched.

### 6.3 Receive path
- `rgmii_recv`: `altddio_in` (inverted clock) captures nibble pairs; at 100 Mb the same nibble is presented on both edges and a `realign` flag re-pairs nibbles across the divided clock. Preamble detector requires ≥5 bytes of 0x55 then 0xD5.
- `mac_recv`: checks destination = local MAC or FF:FF:FF:FF:FF:FF, records `remote_mac`, decodes EtherType 0x0806 (ARP) / 0x0800 (IP), toggles `remote_mac_valid`.
- `ip_recv`: IPv4 only; saves total length, protocol (1 ICMP / 17 UDP), `remote_ip`, `to_ip`, `to_ip_is_me`; toggles `remote_ip_valid` at header byte 17; for broadcast MACs, each destination byte must be 255 or match the local IP byte (directed broadcast accepted).
- `udp_recv`: extracts source port (`remote_port` → `udp_destination_port`), destination port `to_port`; accepts DHCP (port 68), broadcast only to ports 1024/1025, unicast only if `to_ip == local_ip`; toggles `udp_destination_valid` at UDP byte 6; `udp_rx_active` marks payload bytes.

### 6.4 Transmit arbitration (`network.v:441-469`)
Fixed priority when idle: ARP reply > ICMP reply > DHCP > UDP port 1024 (`udp_tx_request == 2'b10`, `PT_UDP0`) > UDP port 1025 (`2'b11`, `PT_UDP1`). `tx_ready → tx_start` gives `udp_send` one cycle of header lead. Destinations:

| Traffic | Destination MAC/IP/port |
|---|---|
| ARP reply | requester (captured in `arp`) |
| ICMP echo reply | `remote_mac_sync` / `remote_ip_sync` (see findings, bug B2) |
| DHCP | broadcast, then server after ACK (`dhcp.v:342-343`) |
| UDP0 (EP6/EP4 data, discovery replies, ASMI status) | `run_destination_*` = last sender to port 1024 **while `run` was 0** (`network.v:693-697`) |
| UDP1 (extended/alt responses) | `udp_destination_*_sync` = last sender to port 1025 |

Header generation: `udp_send` (8-byte header, local port 1024/1025 or 68 for DHCP, no checksum), `ip_send` (20-byte header, ones-complement checksum computed combinationally from the multi-cycle-constrained inputs, DF flag set, TTL 0x80, no fragmentation, `ip_id` is disabled/commented), `mac_send` (14-byte header, pads to 46 bytes, appends CRC32 from `crc32.v` nibble tables), `rgmii_send` (8-byte preamble, 12-byte inter-frame gap, `altddio_out`).

### 6.5 ARP, ICMP, DHCP
- `arp.v`: answers requests for `local_ip` with a fixed 28-byte reply; request/grant handshake between rx and tx clocks via `sync`.
- `icmp.v`: answers echo requests (type 8) by streaming the payload through a 1 kB `icmp_fifo` and recomputing the checksum; detects **ICMP port unreachable** (type 3 whose embedded UDP source port is 1024) and asserts `dst_unreachable`, which forces `dsopenhpsdr1` to stop the stream (`run = 0`).
- `dhcp.v`: builds DISCOVER (244/250 bytes, includes requested IP if a previous lease exists), REQUEST (256 bytes, with server identifier) and RENEW (250 bytes) messages; parses OFFER/ACK, option 51 (lease) and 54 (server IP); XID = {MAC[15:0], free-running counter frozen at first discover}.

---

## 7. Command/control fabric

All configuration flows through one bus: `cmd_addr[5:0]`, `cmd_data[31:0]`, `cmd_cnt` (toggle), plus `cmd_is_alt` (came from port 1025) and `cmd_resprqst` (C0 bit 7). Producers:
1. `dsopenhpsdr1` (ETH-RX domain): C&C bytes of every 512-byte frame (`ds_cmd_*`).
2. `hl2link_app` (DSP domain, HL2LINK=1 only): re-times `ds_cmd_*` into the DSP domain, forwards them over the link when master, or injects commands received from the master when slave. With HL2LINK=0 the `ds_cmd_*` signals are wired straight through (`hermeslite_core.v:1253-1257`).

Each consumer has its own `sync_pulse` on `cmd_cnt`: `cmd_rqst_ad9866` (radio, ad9866, localaudio, hl2link_app), `cmd_rqst_usopenhpsdr1`, `cmd_rqst_dsopenhpsdr1`, `cmd_rqst_io` (control and everything under it). Address 0x39 is decoded by six modules; 0x00 by three; the bit assignments below are exactly what the RTL implements.

### 7.1 Register map (C0[6:1] = address, C1..C4 = data[31:0])

| Addr | Bits | Function | Consumer |
|---|---|---|---|
| 0x00 | 25:24 | RX sample rate 0=48k 1=96k 2=192k 3=384k | `radio`, `usopenhpsdr1` |
| | 23:17 | Filter/relay select → MCP23008 GP6..GP0 | `i2c_bus2` |
| | 16 | `pa_mode` (EER PWM enable, LRDATA=2) | `radio` |
| | 13 | RX antenna select → MCP23008 GP7 | `i2c_bus2` |
| | 12 | Disable supply sync clocks | `control` (PSSYNC) |
| | 11 | Band-volts DAC mode on fan pin (FAN=1) / AK4951 speaker on | `control`, `i2c_bus2` |
| | 6:3 | Number of receivers − 1 (`last_chan`); also sets bandscope interval `(N+1) << rate` | `radio`, `usopenhpsdr1` |
| | 2 | Duplex | `radio` |
| 0x01 | 31:0 | TX frequency (Hz); also band data for UART amplifier and band-volts | `radio`, `control` |
| 0x02–0x08 | 31:0 | RX1–RX7 frequency (Hz) | `radio` |
| 0x12–0x16 | 31:0 | RX8–RX12 frequency (only RX8–RX10 can exist) | `radio` |
| 0x09 | 31:28 | AD9866 TX gain (register 0x0A low nibble) | `ad9866ctrl` |
| | 23 | VNA mode | `radio`, `control`, `usopenhpsdr1` |
| | 20 | ATU tune request | `exttuner` |
| | 19 | PA enable (`pa_enable`) | `control` |
| | 18 | Disable T/R relay in low-power mode (`tr_disable`) | `control` |
| | 17 | ATU bypass | `exttuner` |
| | 16 | AK4951 mic boost | `i2c_bus2` (AK4951) |
| | 15:0 | VNA scan point count (0 = PC drives the scan) | `radio` |
| 0x0A | 22 | PureSignal feedback (receiver 2 mixer takes the DAC word) | `radio` |
| | 6:0 | LNA gain: bit 6 = raw 6-bit value; else Hermes attenuator encoding | `ad9866` (FAST_LNA) / `ad9866ctrl` |
| 0x0B | 22,15:14,13:8,7,6:0 | Keyer reverse, mode, speed, spacing, weight | `cw_openhpsdr` |
| 0x0E | 15,14,13:8 | TX-time LNA gain enable/format/value | `ad9866` (FAST_LNA) |
| 0x0F | 24 | CWX enable (PC-keyed CW via I/Q stream flags) | `dsopenhpsdr1` |
| | 23:16 | Sidetone volume | `localaudio` |
| | 15:8 | CW PTT delay (ms) | `cw_openhpsdr` |
| 0x10 | 31:24,17:16 | CW hang time (10 bits, ms) | `radio`, `cw_*`, `usopenhpsdr1` |
| | 15:8,3:0 | Sidetone frequency | `localaudio` |
| 0x11 | 31:24,17:16 / 15:8,1:0 | EER PWM min / max | `radio` |
| | ~24,17:16 | Mode-B dot memory inhibit | `cw_openhpsdr` |
| 0x17 | 12:8 | PTT hang time (ms; 31 = immediate exit) | `radio` |
| | 6:0 | TX buffer latency (ms, default 20) | `radio` |
| 0x2B | 31:24 = 0 → 17:16 | Predistortion mode (LRDATA=1) | `radio` |
| 0x39 | 27, 26:24 | 1 = watchdog off, 0 = on, 3 = force discovery on data, 2 = off | `dsopenhpsdr1`, `usopenhpsdr1` |
| | 23, 21:16 | Synced-receiver map (hl2link slave) | `radio` |
| | 11:8 | 1001 = become link master, 1000 = release (resets link) | `hl2link_app` |
| | 7, 4 | Reset request: bit4 = 0 → `rst_all`, 1 → `rst_nco` | `hl2link_app` |
| | 3:0 | Versa 5 sequences: 8 = CL2 resync, A = CL2 off, B = CL2 on, C = CL1 off (internal xtal), D = CL1 on (external clock) | `i2c` |
| 0x3A | 0 | Reboot from flash when not running | `control`, `remote_update` |
| 0x3B | 31:24 = 0x06, 20:16, 7:0 | AD9866 SPI register write (addr, data) | `ad9866ctrl` |
| 0x3C | 31:25 = 0x03, 24 = read, 22:16 = 7-bit addr, 15:8 = reg, 7:0 = data | I2C bus 1 pass-through (Versa 5, AK4951) | `i2c_bus2` |
| 0x3D | same | I2C bus 2 pass-through (MCP4662 EEPROM, MCP23008) | `i2c_bus2` |
| 0x3F | — | Reserved: address of an **error** response | `control` |

MCP4662 EEPROM usage (read at boot by `i2c.v` STATE_EEPROM1-7; commands are `{reg<<4, 0xC}` = read): reg 6 = config (bit7 use EEPROM IP, bit6 use EEPROM MAC, bit5 favour DHCP), regs 8–11 = static IP, regs 12–13 = MAC low 16 bits, regs 2–3 = non-volatile bias wipers.

### 7.2 Responses
- **Normal response** (C0 bit 7 set, port 1024): `control.v:385-481`. The command is echoed in the next-but-one EP6 C&C slot as `C0 = {1, addr, ptt}`, `C1..C4 = data` — for I2C reads the returned bytes. If `ad9866ctrl` or the I2C engine was busy, C0 = 0xFF|… with address 0x3F (error). One response slot is used every second EP6 packet; the round-robin status addresses are skipped while a response is queued.
- **Alternate response** (any command on port 1025): `control.v:826-905` + `usopenhpsdr1` `discover_state = 2'b11`: a 60-byte discovery-format packet is sent to the port-1025 sender with bytes 23–26 = read data and byte 27 = `resp_control`.
- **Status round-robin** (no command pending): C0 = {000, slot, key, 0, ptt}: slot 0 → C1 = {000111, ~tx_inhibit, adc_overload}, C3 = TX FIFO status, C4 = version; slot 1 → temperature, forward power; slot 2 → reverse power, bias current; slot 3 → 16-bit debug word (zero).

---

## 8. Downstream decoder (`dsopenhpsdr1.v`, ETH-RX domain)

A 44-state byte machine over the UDP payload (`eth_valid`), only for ports 1024/1025 (`eth_port[15:1] == 512`):

```
0xEF 0xFE  cmd  ──┬─ 0x01 → ENDPOINT (0x02) → 4-byte sequence number (ignored) → two frames of
                  │        0x7F 0x7F 0x7F  C0 C1 C2 C3 C4  + 63 × (L1 L0 R1 R0 I1 I0 Q1 Q0)
                  ├─ 0x02 → DISCOVERY  (toggle discover_cnt, remember port)
                  ├─ 0x03 → ASMI: 0x01 = program (count[13:0], 256-byte blocks), 0x02 = erase
                  ├─ 0x04 → RUN/STOP: bit0 run, bit1 wide spectrum, bit7 watchdog disable
                  └─ 0x05 (port 1025, unicast only) → single C&C block (SYNC → CMD → END)
```

- Frame sync byte 3 (`SYNC0`) must be 0x7C–0x7F; its two LSBs are the hl2link **command mask** (bit1 = forward to remote, bit0 = apply locally).
- C0: bit7 response requested, bits 6:1 address, bit0 PTT (`ds_cmd_ptt`). `ds_cmd_cnt` toggles at C4.
- Audio bytes L/R are exposed as `dsethlr_tvalid` (used only by LRDATA/AK4951 FIFOs). I/Q bytes are pushed into `dsiq_fifo` as 9-bit `{tuser, byte}` words when `ds_cmd_ptt` is set, or when CWX is active (`cwx_pushiq`, held for 500 ms after the last CWX flag). `tuser` carries PTT on the I1 byte and the previous sample's CWX key-down / key-up flags (bits 0 and 3 of the I0 byte) on I0/Q1.
- Watchdog: `watchdog_cnt` increments on every `watchdog_up` toggle from the packer (one per bandscope interval, i.e. every `(N+1)<<rate` EP6 packets); cleared by each received data frame; 4095 ticks without downstream traffic → `run = 0`. Disabled by RUN byte bit 7 or command 0x39.
- `dst_unreachable` (ICMP) also forces `run = 0`.

---

## 9. Upstream packer (`usopenhpsdr1.v`, ETH-TX domain)

Priority in `START`: hl2link stall → discovery/alt-response/ASMI status (60 bytes) → EP6 data (needs `us_tlength > 333` words, `have_ip`, `run`) → EP4 bandscope (when `bs_cnt` expires and `wide_spectrum`).

- **EP6**: `EF FE 01 06 seq[3:0]` + two 512-byte frames: `7F 7F 7F` + 5 response bytes (`resp`, pulses `resp_rqst` toward `control`) + rounds of `{I[23:0], Q[23:0]} × receivers` big-endian + 2 mic bytes (zero; VNA flag bit only) until fewer than one round remains, then zero padding. `us_tlast` from the FIFO marks the last word of a round.
- **EP4**: `EF FE 01 04 seq` + 512 × 16-bit little-endian samples `{adc[11:0], 0000}` from `usbs_fifo` (2048 contiguous raw ADC samples captured when the FIFO is empty; four packets per capture). The 20-bit sequence numbers reset when `run` drops; EP4 sequence LSBs are aligned to the capture.
- **Discovery / extended packet** (60 bytes): 0 = EF, 1 = FE, 2 = status (02 idle, 03 running / erase done, 04 send more), 3–8 MAC, 9 = version major, 10 = 06 (HL) or 01 if `io_cn9` open, 11 = `{eeprom_config[7:5],0}`, 13–16 = EEPROM IP, 17–18 = EEPROM MAC, 19 = NR (×2 when link master), 20 = `{01, BOARD}`, 21 = version minor, 23–26 = response data, 27 = `{key, ptt, ext_tr, int_tr, tx_on, cw_on, clip[1:0]}`, 28–29 temperature, 30–31 forward, 32–33 reverse, 34–35 bias, 36 = TX FIFO status `{recovery, level[6:0]}`, 37 = packets received (mod 256), 38 = buffer latency, 39–40 = CW/PTT hang, 41 = `{rate, ptt, tx_wait, receivers}`.
- `watchdog_up` toggles once per bandscope interval and is the time base of the downstream watchdog.
- With `force_discover_en` (0x39 sub-command 3) an extended packet is sent after every EP6 packet.

---

## 10. Receive DSP (`radio.v`, `receiver_nco.v`, `nco/`)

### 10.1 Frequency word
`freqcomp = cmd_data * M2 + M3` with `M2 = 2^57 / 76.8e6 = 1 876 499 845`, `M3 = 2^24` (rounding); the phase increment is `freqcomp[56:25]` (32-bit, 2^32 = 76.8 MHz). The 32×32 multiply has a 2-cycle pipeline (`CMD_FREQ1/2/3`, multicycle constraint on the hl2link path). Address → NCO index mapping (`radio.v:324-377`): 0x01 → TX (15), 0x02..0x08 → RX0..RX6, 0x12..0x16 → RX7..RX11; in link modes the map interleaves local/remote receivers. Non-duplex with one receiver ties RX0 to the TX frequency.

### 10.2 NCO and mixer (`mix2.v`, `nco2.v`, `sincos.v`)
One `mix2` serves two receivers by time-multiplexing on `clk_ad9866_2x`: `nco2` ping-pongs two 32-bit phase accumulators (`angle0/angle1`); `sincos` splits the top 20 phase bits into quadrant (2), coarse (8 → 256-entry 36-bit ROM of sin/cos), fine (10) and applies a first-order correction `sin(a+b) ≈ sin a + b·cos a` with the fine sine from a ROM (`CALCTYPE 0`, NR>5) or a small logic multiplier (`CALCTYPE 3`, 7×7, NR≤5). Results are sign-magnitude 19-bit; `mix2` converts to two's complement, multiplies with the sign-extended 12-bit ADC sample in `lpm_mult` (2-stage pipeline), rounds `[28:11]` → 18-bit I/Q. `mix2_0` is reset when `rst_nco` or when the VNA TX phase word is zero (phase alignment); `mix2_2` takes the DAC word instead of the ADC when PureSignal is enabled and transmitting.

### 10.3 Decimation chain (`receiver_nco.v`)
| Stage | Module | Rate | Widths | Notes |
|---|---|---|---|---|
| 1 | `cic` 3-stage, R = 5 (`CICRATE`) | 76.8 M → 15.36 M | 18 in, 25 acc, 16 out | gain 5³ / 2⁹ ≈ 0.24 |
| 2 | `varcic` 5-stage, R = 40/20/10/5 | → 384 k / 768 k / 1.536 M / 3.072 M | 16 in, 43 acc, 16 out | output bit position selected per rate (`GROWTH5..40`) |
| 3 | `firX8R8` polyphase, 976 taps, R = 8 | → 48/96/192/384 k | 18 in, 24 acc/out | four `fir256` engines, each two phases, on `clk_ad9866_2x`; coefficient ROMs `coefL4*` (sum ≈ 5.09 × 2¹⁷ → ≈ 0.64 of full scale) |

Each `fir256` stores 256 I/Q samples in a 36-bit RAM (two banks) and runs `TAPS+4 = 126` MAC cycles per output; the write strobe from the 76.8 MHz domain is re-timed to a single 153.6 MHz pulse. `firX8R8` sums the eight phase partials A,B,C,D,A,B,C,D as samples arrive and asserts `y_avail` at `wstate == 8`.

Variants: `receiver_ciconly.v` (10-receiver builds, no FIR), `receiver2/` (NH6Z 122.88 MHz style), `receiver_4000.v`, `qs1r/` — compiled into the file list but only instantiated by their variants.

### 10.4 Sample round state machine (`radio.v:707-839`)
On `rx_data_rdy[0]` (all receivers strobe together) and `rx_tready`, states `RXUS_I → RXUS_Q` emit 24-bit I then Q per channel up to `last_chan`, `tlast` on the last Q. Link modes: master interleaves samples received over the link (`RXUSLM_*`, local receivers on even channels, remote on odd); slave sends its samples over the link (`RXUSLS_*`, `ls_valid/ls_done`). A new strobe during a link transfer aborts the round ("Escape").

### 10.5 VNA (`vna_scanner.v`)
With `vna=1` and `vna_count=0` the PC steps the TX frequency (`VNA_PC_SCAN`; RX0 phase follows the TX phase). With `vna_count>0` the FPGA scans: start at the TX frequency, add the RX0 word per point, wait `DECIMATION = 40·5·8·6 = 9600` clocks (8 kSPS output), accumulate 1024 mixer outputs, emit `acc[27:4]`; a zero sample marks the start of each sweep. `tx_zero` resets the mixer phase when the TX word is zero.

---

## 11. Transmit DSP (`radio.v:883-1357`)

### 11.1 TX I/Q FIFO ("tape recorder")
`dsiq_fifo` (16384 × 9-bit write, 4096 × 36-bit read, showahead). Write side drops data when full and re-enables at 1/4 full on a frame boundary (`allow_push`). Read status `{recovery_flag, level[11:5]}` is sampled by `dsiq_sample` (every second EP6 packet) and reported as TX FIFO status. The FSM below controls the read strobe: it stalls (`PRETX`) for `tx_buffer_latency` (default 20 ms) so the FIFO fills, counts the samples the interpolator asked for meanwhile (`accumdelay`), and frees exactly that many in `NOTX` to keep the PC and radio time-aligned.

### 11.2 TX state machine
```
NOTX ──(key | ext PTT | CWX flags | MOX with data)──► PRETX ──latency expired──► PTTTX (data)
                                                          │                       └─ key → CWTX
                                                          └─ key → CWTX ◄─────────── CWHANG
PTTTX: pops samples on FIR request; on data stop, hang for ptt_hang_time (or exit immediately if 31)
CWTX : ramps tx_cwlevel 0 → 0x4D800 linearly (1/clk, ≈4.1 ms), holds while keyed, ramps down, then
       CWHANG for cw_hang_time (quarter-ms units) before NOTX; ext PTT + key bypasses the latency timers
```
`tx_on` (relays, bias) is 1 in every state but `NOTX`; `cw_on` is 1 in `CWTX/CWHANG`. Both go through `control` (`int_tx_on = (tx_on | ext_ptt) & ~tx_inhibit & run & ~overheat`).

### 11.3 Interpolation and up-conversion
| Stage | Module | Rate | Notes |
|---|---|---|---|
| 1 | `FirInterp8_1024` | 48 k → 384 k | 1024 taps, 8 phases × 128, coefficients ×8 (each phase sums to 0.814 × 2¹⁷), 20-bit out; ≈135 clocks per output, must stay < 200 |
| 2 | `CicInterpM5` | 384 k → 76.8 M | 5-stage, R = 200, 51-bit accumulators (GBITS = 31), 16-bit out, gain 200⁴/2³¹ ≈ 0.745 |
| 3 | `cpl_cordic` | — | 16-bit I/Q → rotation by `tx0_phase`; 23-bit internal, 19 stages, output 16-bit; gain 1.647 |
| 4 | `>>> 2`, `[11:0]` | — | to the 12-bit DAC (`tx_data_dac`), truncated, no saturation |

End-to-end: 0.814 × 0.745 × 1.647 / 16 = 0.0624 → a full-scale 16-bit I/Q vector (32767) produces 2046, i.e. unity gain to the DAC rail. CW/VNA drive `tx_i = 0x4D80` (or the CW ramp) with `tx_q = 0`, giving 2042.

LRDATA options: 1 = two 4096-entry 13-bit predistortion LUTs written from the audio bytes and applied as `LUTI[I] − LUTI[Q] + LUTQ[(I+Q)/√2]`; 2 = EER: envelope `√(I²+Q²)` from a second ×5 interpolator, compared against a 1024-step 240 kHz ramp on `clk_envelope` to produce `io_tx_envelope_pwm_out` (PWM_min/max limits from 0x11).

---

## 12. AD9866 interface

`ad9866.v` (full-duplex mode, `rffe_ad9866_mode = 1`):
- **TX**: on `clk_ad9866_2x`, `tx_sync` alternates; the low 6 bits go out with `TXSYNC = 1`, the high 6 with `TXSYNC = 0`; `TXQUIET_N = tx_en`. With `FAST_LNA` the RX-PGA gain is written through the same bus: when a gain change is pending (`update_gain`), the upper 6 bits are replaced by the gain and `PGA5` is pulsed instead of `TXSYNC` (AD9866 register 0x0B bit 2 enables this). Gain selection: RX gain normally; TX gain during transmit if enabled; 0 during CW.
- **RX**: `RX[5:0]` and `RXSYNC` are registered twice on `clk_ad9866_2x`; when `RXSYNC` was high the two halves are assembled `{d2, d1}` and re-registered on `clk_ad9866`. The AD9866 `RXCLK` pin is not used as a clock; the SDC treats the inputs as arriving 0–4.5 ns after a virtual 153.6 MHz clock.
- Status: `rxclip` (sample = ±full scale), `rxgoodlvl` (|sample| ≥ 3/4 scale); both are sticky until `rxclrstatus`, which is toggled every `clk_ctrl` cycle (0.4 µs).

`ad9866ctrl.v`: after `ad9866_rst` a 20-entry init table is walked (writes only where the enable bit is set: reg 0x06 = 0x54 disable CLKOUT2, 0x07 = 0x30 DC-offset cal + RX filter, 0x0B = 0x04 fast PGA, 0x0C = 0x43 TX two's complement/interp, 0x0D = 0x03 RX two's complement, 0x0E = 0x81 IAMP, 0x10 = 0x80 / 0x11 = 0x00 TX gain, 0x12 = 0x00; with `BYPASS_VERSA` also 0x04 = 0x36). Runtime: 0x09 bits 31:28 → register 0x0A (TX gain); 0x0A → register 0x09 (RX gain, only when `FAST_LNA = 0`); 0x3B generic write. 16-bit SPI frames `{000, addr[4:0], data[7:0]}` at 1.25 MHz, three wires (no read-back).

---

## 13. Control block (`control.v`, 2.5 MHz)

- **Timers**: `qmsec_pulse` every 625 clocks (250 µs), `msec_pulse` every 4 of those, `led_count` (ms) → `led_saturate` every 64 ms.
- **LEDs** (active low): D2 run — solid when running or slave link; else blink 512 ms (KSZ9031) / 256 ms (KSZ9021) when `ethup`. D3 — TX on when running; else solid = DHCP address, blink = fixed/APIPA. D4 — RX good-level flash when running; else solid = 1 Gb, blink = 100 Mb. D5 — ADC clip flash when running; else on when the AD9866 PLL is locked and the clock measures < 80 MHz (`fast_clk_cnt`, a 0.8 µs window counted on `clk_ad9866`).
- **Outputs**: `pwr_envbias = pwr_envpa = int_tx_on & ~vna & pa_enable`; `pwr_envop = pa_exttr = int_tx_on`; `pa_inttr = int_tx_on & ~vna & (pa_enable | ~tr_disable)`; `rffe_rfsw_sel = ~vna & pa_enable`.
- **Supply sync** (PSSYNC): the 125 MHz clock is divided by 59 and the outputs toggle on each terminal count, giving 125 / (2 × 59) = 1.06 MHz square waves for the 3.3 V converter and, offset by 17 counts (≈ 100°), the 1.2 V converter (`control.v:511-536`).
- **Fan** (FAN=1): hysteretic 5-state controller sampled with the sensor ADC, 2-of-3 voting: off / 50 % / 75 % / 100 % / overheat (TX disabled) at 37/40/45/55 °C rising and 35/37/40/50 °C falling (12-bit codes from `T = (code·3.26/4096 − 0.5)/0.01`). Alternatively (0x00 bit 11) the pin becomes a 12-bit PWM DAC that outputs 0.23 V per band (10 bands from the TX frequency) for external amplifiers.
- **UART** (UART=1): `extamp.v` sends the Elecraft `FA000nnnnnnnnnnn;` VFO string at 9600 baud whenever the TX frequency changes and again after each PTT (inverted line for the level shifter).
- **ATU** (ATU=1): `exttuner.v` AH-4 protocol: 71 ms delay → START low, wait ≤ 511 ms for KEY low → 311 ms hang → carrier for ≤ 4095 ms until KEY high → 71 ms → PASS/FAIL; `txinhibit` gates the transmitter during the sequence.
- **CW**: CW=1 uses the debounced tip (key) and ring (PTT) of the phone jack directly; CW=2 runs the VK6PH iambic keyer (`iambic.v`, 48 kHz tick, dot/dash delays computed in `cw_openhpsdr.v` from speed/weight) with CW PTT delay and hang time.
- **Sensor ADC** (`slow_adc.v`): writes configuration byte 0x07 (scan channels 0–3, single-ended) then reads 8 bytes, each channel returned as `{1111, D11:8}, {D7:0}`; this is the MAX1236-family transaction at 7-bit address 0x34. Channels: ain0 = reverse power, ain1 = temperature, ain2 = bias current, ain3 = forward power. Sampled every second EP6 response while running, else every 64 ms.
- **Clock monitor**: if the 76.8 MHz clock disappears or exceeds 80 MHz, `lost_clock` returns the Versa 5 to its crystal (`CL1OFF` sequence) and requests an hl2link reset.
- **Reboot**: command 0x3A bit 0 while `run = 0` → `hl2_reset` → `remote_update` reconfigures from flash.

---

## 14. I2C subsystem

- `i2c_master.v` (Alex Forencich, MIT) — generic master with command/data streams; `prescale = 2` → SCL ≈ 312 kHz at 2.5 MHz.
- `i2c_bus2.v` — command decoder in front of one master, switching physical buses with `en_i2c2` (bus 2 = `cmd_addr 0x3D` or the MCP23008): pass-through writes (`addr, reg, data`) and 4-byte reads (returned as `resp_data`, byte 2 used for the MCP4662 low data byte); automatic MCP23008 write (`0x20`, register 0x0A, `{ant, filter[6:0]}`) whenever 0x00 bits 23:17/13 change; AK4951 speaker/mic-boost writes under `AK4951`. A command arriving while busy is dropped and reported by `cmd_ack = 0`.
- `i2c.v` — sequencer: Versa 5 init (registers 0x17/0x18 = 0x0440 divider, 0x1E/0x1F RC control, 0x2D/0x2E output-1 divider, 0x60 = 0x3B enable output 1), then (AK4951 builds) codec init, then the seven EEPROM reads. Runtime sequences for hl2link clock sharing: `CL2ON` (route the 76.8 MHz reference to clock output 2 for the slave, with skew and resync), `CL2OFF`, `CL1ON` (switch the PLL to the external clock input with `0x10 = 0x44`, `0x13 = 0x03`), `CL1OFF`.

---

## 15. hl2link (`hl2link.v`, `hl2link_app.v`)

A synchronous 2-bit-per-clock serial link at 76.8 MHz between two boards sharing one reference clock (the master exports its clock on Versa output 2; the slave switches to it with `CL1ON` during link training).

- Frame: 2-bit type (01 command 38 bits, 10 RX sample 24 bits, 11 TX I/Q 32 bits), payload MSB-first two bits per clock, then `{parity, 1}`; the receiver flags `recv_error` on parity mismatch.
- Training: master sends 10 → slave 01 → master 01 → slave 10 → master 11 → slave 11 while requesting `CL1ON`; when the slave's clock has switched both go to 00 and `running = 1`. `linkrx_stable` requires two identical consecutive samples.
- Master forwards every Ethernet command whose mask bit 1 is set (0x39 with 1001 in bits 11:8 enables master mode); the slave ignores its own Ethernet commands while linked and executes commands received over the link. Slave receiver samples are sent up the link and interleaved by the master as odd channels, so the PC sees 2×NR receivers.

---

## 16. Local audio (AK4951 variants)

`localaudio.v`: I2S master (`i2s_ak4951.v`, BCLK = 76.8 MHz/25 ≈ 3.07 MHz, 64 BCLK per frame → 48 kHz), sends the PC audio L/R words from `dslr_fifo` or a sidetone (`cw_sidetone.v`: 1024-entry sine table, frequency and volume from 0x10/0x0F, profile from the CW ramp) when `cw_on`; returns the left microphone channel as `au_rdata`, which replaces the mic bytes in EP6 (`usiq_fifo` `tuser` becomes 16 bits).

---

## 17. Flash programming and remote update

- Flash layout (EPCS16, 2 MB): factory image at 0x000000, application image at 0x100000. `asmi_interface.v` erases sectors 0x100000–0x1F0000 on the ASMI erase command, then programs 256-byte pages from `asmi_fifo` as the PC streams them (each 256-byte block is acknowledged with a "send more" discovery packet, status 0x04; final block → 0x03 and reconfiguration after a delay). Bit order is reversed into the ASMI block.
- `remote_update.v`: on power-up in the factory image, reads the reconfiguration status; if clean, sets the watchdog, writes boot address 0x100000 and reconfigures into the application image. Holding key and PTT grounded at power-up (`factory`) stays in the factory image. In the application image, `reboot` (ASMI done or command 0x3A) triggers a reconfiguration.

---

## 18. Timing constraints (`boards/hl2b5up/timing.sdc`)

- Generated clocks for both PLLs, both TX clock muxes (`-add` exclusive pairs), the logic RX clock mux (`clock_ethrxintfast/slow`) and the RGMII TX output clock.
- RGMII per AN477: TX output delay ±1.0/−0.8 ns on both edges (PHY TX delay disabled); RX input delay +0.6/−1.0 ns against a virtual 8 ns clock (PHY adds 1.0–2.6 ns, clock shifted 90°). Same-edge/opposite-edge false paths.
- MDIO: 10 ns in/out delays referenced to `phy_mdc`.
- AD9866: inputs 0–4.5 ns after `virt_ad9866_rxclk_rx` (153.6 MHz virtual); outputs +1.4/−1.3 ns to `virt_ad9866_rxclk_tx`.
- Multicycle: DHCP/ICMP/UDP length and destination registers → `ip_send` shift register (2–3 cycles); `cmd_data` → `freqcompp` (2 cycles, hl2link path); **all** paths from the 153.6 MHz clock to the 76.8 MHz clock (setup and hold 2, "for FIR").
- False paths on all slow GPIO, LEDs, I2C pins, `phy_rst_n`, `phy_mdc`, `pwr_*`, `pa_*`.

---

## 19. Memory and FIFO budget

| FIFO / memory | Size | Clocks | Purpose |
|---|---|---|---|
| `dsiq_fifo` | 16384 × 9 b (≈16 M9K) | ETH-RX → DSP | TX I/Q, 85 ms at 48 kSPS |
| `usiq_fifo` | 1024 × 27 b | DSP → ETH-TX | RX I/Q words + tlast + mic bits |
| `usbs_fifo` | 2048 × 12 b | DSP → ETH-TX | bandscope capture |
| `dslr_fifo` | 8192 × 8 b | ETH-RX → DSP | audio bytes (LRDATA/AK4951 only) |
| `asmi_fifo` | 1024 × 8 b | ETH-RX → CTRL | flash pages |
| `icmp_fifo` | 1024 × 8 b | ETH-RX → ETH-TX | echo payload |
| RX FIR sample RAM | 4 × 256 × 36 b | DSP2X | polyphase history |
| RX FIR coefficient ROM | 4 × 256 × 18 b | DSP2X | `coefL4*.mif` |
| TX FIR RAM/ROM | 128 × 36 b, 1024 × 18 b | DSP | `coefI8_1024.mif` |
| NCO ROMs | 256 × 36 b + 512 × 9 b per `sincos` | DSP2X | sin/cos coarse, fine |

Multipliers: 2 per `mix2` (18×18), 2 per `sincos` (unsigned, ROM mode), 2 per `fir256` (8 for four engines), 2 in `FirInterp8`, 3 for the 32×32 frequency multiply, plus the CORDIC (adders only).
