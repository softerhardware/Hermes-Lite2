// ============================================================================
// cmd_bus.vh - Command bus address map and protocol contract.
//
// This is the single authoritative description of the Hermes broadcast
// command bus.  Include ONCE, inside the module that consumes commands:
//
//     `include "cmd_bus.vh"
//
// The bus is a BROADCAST, not a point-to-point bus: cmd_addr/cmd_data are
// driven by dsopenhpsdr1 (clock_ethrxint) or hl2link_app (clk_ad9866), and
// EVERY consumer domain receives a synced cmd_rqst pulse for every command
// and self-decodes the addresses it owns.  Several slaves intentionally
// decode the same address for different fields (see table).
//
// Crossing contract:
//   - cmd_addr/cmd_data are registered in the source domain and are stable
//     well before each cmd_cnt toggle crosses via sync_pulse into any
//     destination domain (commands are spaced milliseconds apart by the
//     protocol).  Slaves may therefore sample the words directly when their
//     local cmd_rqst pulse fires - no further synchronizers required.
//   - cmd_ack is LEVEL semantics: high when the subsystem is idle/ready,
//    low while it is busy executing.  Only control.v's response arbiter
//    consumes acks today.
//
// Read data: only the I2C subsystem returns read data today (generic I2C
// access via CMDA_I2C1/CMDA_I2C2, collected by control.v into response
// slots).  AD9866 register readback over SPI is NOT implemented; the
// response arbiter must not be expected to return meaningful data for
// other addresses.
//
// Address map (co-owners in parentheses):
//   00 GENERAL            rate/receivers/duplex (radio, usopenhpsdr1);
//                         misc enables: PSU sync disable, fan band-volts,
//                         filter select / Alex antenna (i2c_bus2)
//   01 TXFREQ             TX frequency (radio); monitored by extamp HR50
//                         announcer and band-volts DAC (control)
//   02..08 RXFREQ0..6     RX frequencies, receivers 0..6 (radio)
//   09 VNA_TXGAIN         VNA enable + scan count (radio, usopenhpsdr1),
//                         PA/TR flags (control), AD9866 TX gain
//                         (ad9866ctrl), AK4951 mic boost (i2c_bus2)
//   0a RXGAIN_PURESIG     PureSignal enable + VNA freq step (radio),
//                         RX gain (ad9866.v fast-LNA, ad9866ctrl SPI)
//   0b KEYER_SPEED        keyer speed/weight/mode/spacing (cw_openhpsdr)
//   0e LNA_TXGAIN         fast-LNA TX gain enable (ad9866.v)
//   0f KEYERAUX           CWX enable (dsopenhpsdr1), CW PTT delay
//                         (cw_openhpsdr)
//   10 CWHANG             CW hang time (radio, usopenhpsdr1,
//                         cw_openhpsdr)
//   11 PWM_LIMITS         TX envelope PWM min/max (radio), Mode-B memory
//                         timing (cw_openhpsdr)
//   17 LATENCY            tx buffer latency + PTT hang time (radio,
//                         usopenhpsdr1)
//   2b PREDISTORT         predistortion sub-index control (radio)
//   39 DEBUG              debug/synced-receivers/watchdog control
//                         (radio x2, usopenhpsdr1, dsopenhpsdr1)
//   3a REBOOT             request FPGA reboot (control)
//   3b AD9866_WRITE       generic AD9866 SPI register write (ad9866ctrl)
//   3c I2C1               generic I2C bus-1 write/read (i2c_bus2)
//   3d I2C2               generic I2C bus-2 write/read (i2c_bus2)
//   3f RESP_ERROR         value stamped into responses that could not be
//                         serviced (control only; not decodable input)
// ============================================================================

localparam CMDA_GENERAL          = 6'h00;
localparam CMDA_TXFREQ           = 6'h01;
localparam CMDA_RXFREQ0          = 6'h02;
localparam CMDA_RXFREQ1          = 6'h03;
localparam CMDA_RXFREQ2          = 6'h04;
localparam CMDA_RXFREQ3          = 6'h05;
localparam CMDA_RXFREQ4          = 6'h06;
localparam CMDA_RXFREQ5          = 6'h07;
localparam CMDA_RXFREQ6          = 6'h08;
localparam CMDA_VNA_TXGAIN       = 6'h09;
localparam CMDA_RXGAIN_PURESIG   = 6'h0a;
localparam CMDA_KEYER_SPEED      = 6'h0b;
localparam CMDA_LNA_TXGAIN       = 6'h0e;
localparam CMDA_KEYERAUX         = 6'h0f;
localparam CMDA_CWHANG           = 6'h10;
localparam CMDA_PWM_LIMITS       = 6'h11;
localparam CMDA_RXFREQ7          = 6'h12;
localparam CMDA_RXFREQ8          = 6'h13;
localparam CMDA_RXFREQ9          = 6'h14;
localparam CMDA_RXFREQ10         = 6'h15;
localparam CMDA_RXFREQ11         = 6'h16;
localparam CMDA_LATENCY          = 6'h17;
localparam CMDA_PREDISTORT       = 6'h2b;
localparam CMDA_DEBUG            = 6'h39;
localparam CMDA_REBOOT           = 6'h3a;
localparam CMDA_AD9866_WRITE     = 6'h3b;
localparam CMDA_I2C1             = 6'h3c;
localparam CMDA_I2C2             = 6'h3d;
localparam CMDA_RESP_ERROR       = 6'h3f;
