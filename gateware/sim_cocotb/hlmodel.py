"""Golden models for Hermes-Lite gateware DSP blocks, bit exact.

Each model replicates the RTL datapath (truncations, rounding, register
wrap widths) so cocotb tests can compare DUT outputs sample by sample.
A model consumes one input sample per clock and returns the output
register values *after* that clock edge.

Cocotb usually samples outputs on a falling edge, a few pipeline clocks
"behind" the input index that produced them, so use find_offset() to
align a captured array against the model stream rather than assuming a
particular latency.
"""

import os

import numpy as np

_COCOTB = os.path.abspath(os.path.dirname(__file__))
GATEWARE = os.path.abspath(os.path.join(_COCOTB, os.pardir))
RTL_NCO = os.path.join(GATEWARE, "rtl", "nco")
RTL_RADIO = os.path.join(GATEWARE, "rtl", "radio_openhpsdr1")


def _mask(v, n):
    return v & ((1 << n) - 1)


def _s(v, n):
    """Interpret the low n bits of v as two's complement."""
    v &= (1 << n) - 1
    return v - (1 << n) if v >> (n - 1) else v


def read_rom(name):
    """Read a binary ROM init file (as used by $readmemb) into a list of ints."""
    rom = []
    with open(os.path.join(RTL_NCO, name)) as f:
        for line in f:
            line = line.split('//')[0].strip()
            if line:
                rom.append(int(line, 2))
    return rom


# arctan table used by cordic.v / cpl_cordic.v (index 1..31, index 0 unused)
ATAN = [0, 633866811, 334917815, 170009512, 85334662, 42708931, 21359677,
        10680490, 5340327, 2670173, 1335088, 667544, 333772, 166886,
        83443, 41722, 20861, 10430, 5215, 2608, 1304, 652, 326, 163,
        81, 41, 20, 10, 5, 3, 1, 1]


class Sincos:
    """Golden model of rtl/nco/sincos.v (CALCTYPE 0 = finerom, 3 = CALCLOGIC7).

    step(angle20) presents the 20-bit angle for one clock and returns the
    (sin, cos) sign-magnitude 19-bit register values after that clock edge.
    Latency is 5 clocks.
    """

    # cop indexed by {coarse_cos[18], coarse_sin[18], fine_sign_d1}
    COP = {0b000: 1, 0b001: 0, 0b010: 0, 0b011: 1,
           0b100: 0, 0b101: 1, 0b110: 1, 0b111: 0}
    # sop indexed by {coarse_sin[18], coarse_cos[18], fine_sign_d1}
    SOP = {0b000: 0, 0b001: 1, 0b010: 1, 0b011: 0,
           0b100: 1, 0b101: 0, 0b110: 0, 0b111: 1}

    def __init__(self, calctype=3):
        assert calctype in (0, 3), "modelled: CALCTYPE 0 and 3"
        self.calctype = calctype
        self.coarse_rom = read_rom("sincos_coarse.txt")
        if calctype == 0:
            self.fine_rom = read_rom("sin_fine.txt")
        self.reset()

    def reset(self):
        self.s1 = (0, 0, 0, 0, 1)  # coarse_addr, sin_sign, cos_sign, faddr, fsign
        self.q = 0                 # coarserom q register (36b)
        self.sinp18 = 0
        self.cosp18 = 0
        self.finesig_pd1 = 1
        self.fine_sin = 0          # fine_sin register (CALC) / finerom q (ROM)
        self.csin = 0              # coarse_sin, sign magnitude 19b
        self.ccos = 0              # coarse_cos
        self.finesig_d1 = 1
        # umult_ABOpiped: ra <= opa; rb <= opb; ro <= ra*rb (2 clock latency)
        self.sinra = self.sinrb = 0
        self.cosra = self.cosrb = 0
        self.sinro = self.cosro = 0
        self.sc = self.cc = self.sop = self.cop = 0
        self.sin = self.cos = 0

    def _opb(self, fine):
        """sin_opb/cos_opb from the fine_sin register value."""
        if self.calctype == 3:
            return _mask(fine, 14) >> 7    # {11'h00, fine_sin[13:7]}
        return _mask(fine, 9)              # {9'h00, fine_sin}

    def step(self, angle20):
        # ---- new stage 1 (from the angle visible before this edge) ----
        quad = _mask(angle20, 20) >> 18
        coarse = (angle20 >> 10) & 0xFF
        fine = angle20 & 0x3FF
        n_s1 = (
            (~coarse & 0xFF) if (quad & 1) else coarse,
            (quad >> 1) & 1,
            ((quad >> 1) & 1) ^ (quad & 1),
            (fine & 0x1FF) if (fine >> 9) else (~fine & 0x1FF),
            0 if (fine >> 9) else 1,
        )

        # ---- new coarserom q + sign regs (from old stage 1) ----
        n_q = self.coarse_rom[self.s1[0]]
        n_sinp18 = self.s1[1]
        n_cosp18 = self.s1[2]
        n_finesig_pd1 = self.s1[4]

        # ---- new fine_sin register (from old stage 1 fine_addr) ----
        if self.calctype == 3:
            # 7'h65 * {fine_addr[8:3], 1'b1}, 14-bit register
            n_fine = _mask(0x65 * ((_mask(self.s1[3], 9) >> 3 << 1) | 1), 14)
        else:
            n_fine = self.fine_rom[self.s1[3]]

        # ---- new coarse_sin/cos + fine_sign_d1 (from old stage 2a regs) ----
        n_csin = (self.sinp18 << 18) | _mask(self.q >> 18, 18)
        n_ccos = (self.cosp18 << 18) | _mask(self.q, 18)
        n_finesig_d1 = self.finesig_pd1

        # ---- new multiplier pipes: ro <= ra*rb; ra <= opa; rb <= opb ----
        n_sinro = _mask(self.sinra * self.sinrb, 36)
        n_cosro = _mask(self.cosra * self.cosrb, 36)
        n_sinra = _mask(self.q >> 18, 18)   # coarse_sinp[17:0] (combinational)
        n_cosra = _mask(self.q, 18)
        n_sinrb = self._opb(self.fine_sin)

        # ---- new stage 3 (sc/cc latch coarse_sin/cos; sop/cop decode them) ----
        n_sc, n_cc = self.csin, self.ccos
        n_cop = self.COP[((self.ccos >> 18) << 2) | ((self.csin >> 18) << 1)
                         | self.finesig_d1]
        n_sop = self.SOP[((self.csin >> 18) << 2) | ((self.ccos >> 18) << 1)
                         | self.finesig_d1]

        # ---- new outputs (from old stage 3 + multiplier results) ----
        # CALCTYPE 0: scsf = sin_mult_res[26:17]; 3: [24:15]
        shift = 17 if self.calctype == 0 else 15
        scsf = _mask(self.sinro >> shift, 10)
        ccsf = _mask(self.cosro >> shift, 10)
        if self.sop:
            mag = _mask(_mask(self.sc, 18) - ccsf, 18)
        else:
            mag = _mask(_mask(self.sc, 18) + ccsf, 18)
        n_sin = mag | (self.sc >> 18 << 18)
        if self.cop:
            mag = _mask(_mask(self.cc, 18) - scsf, 18)
        else:
            mag = _mask(_mask(self.cc, 18) + scsf, 18)
        n_cos = mag | (self.cc >> 18 << 18)

        # ---- commit ----
        self.s1 = n_s1
        self.q = n_q
        self.sinp18, self.cosp18, self.finesig_pd1 = n_sinp18, n_cosp18, n_finesig_pd1
        self.fine_sin = n_fine
        self.csin, self.ccos, self.finesig_d1 = n_csin, n_ccos, n_finesig_d1
        self.sinro, self.cosro = n_sinro, n_cosro
        # cos_opb is wired to the same fine_sin value as sin_opb
        self.sinra, self.cosra = n_sinra, n_cosra
        self.sinrb = self.cosrb = n_sinrb
        self.sc, self.cc, self.sop, self.cop = n_sc, n_cc, n_sop, n_cop
        self.sin, self.cos = n_sin, n_cos
        return n_sin, n_cos


class Nco1:
    """Golden model of rtl/nco/nco1.v: phase accumulator feeding sincos."""

    def __init__(self, phi, calctype=3):
        self.phi = _mask(phi, 32)
        self.sincos = Sincos(calctype)
        self.acc = 0

    def step(self, rst=0):
        angle = self.acc >> 12  # angle visible to sincos during this cycle
        sin, cos = self.sincos.step(angle)
        self.acc = 0 if rst else _mask(self.acc + self.phi, 32)
        return sin, cos


def _quad(v):
    """mix1/mixtx1 ssin_q/scos_q: two's complement of sign-magnitude sin/cos,
    arithmetically shifted right one bit ({sign,~mag}+1 then [18:1])."""
    mag = v & 0x3FFFF
    if (v >> 18) & 1:
        return -(mag >> 1) - (mag & 1)   # floor(-mag / 2)
    return mag >> 1


class Mix1:
    """Golden model of rtl/nco/mix1.v.

    step(adc) advances one clock and returns the (i_data, q_data) visible
    at the falling edge that precedes that clock, i.e. exactly what a
    cocotb loop that captures before awaiting the falling edge sees. State
    mirrors the RTL registers (ssin_q/scos_q, the umult_ABOpiped ra/rb/ro
    pipes, the nco sin/cos registers) so no latency guessing is needed."""

    def __init__(self, phi, calctype=3):
        self.nco = Nco1(phi, calctype)
        self.sin = 0               # nco sin/cos registers
        self.cos = 0
        self.ssin_q = 0            # mix1 ssin_q/scos_q registers
        self.scos_q = 0
        # imult/qmult umult_ABOpiped pipes (ra, rb, ro)
        self.ira = self.qra = 0
        self.icrb = self.qrb = 0   # rb of the i/q multipliers
        self.iro = self.qro = 0

    @staticmethod
    def _round36(p):
        # i_data = i_data_d[28:11] + {17'h0, i_data_d[10]} (18-bit result)
        return _s(_mask(p >> 11, 18) + ((p >> 10) & 1), 18)

    def step(self, adc):
        # outputs visible before this edge
        i_data = self._round36(self.iro)
        q_data = self._round36(self.qro)

        # umult_ABOpiped: m = ra*rb; ro <= m; ra <= a; rb <= b (same edge).
        # imult.b = scos_q, qmult.b = ssin_q.
        n_iro = _mask(self.ira * self.icrb, 36)
        n_qro = _mask(self.qra * self.qrb, 36)
        n_ra = _s(adc, 12)

        sin, cos = self.nco.step()

        self.icrb, self.qrb = self.scos_q, self.ssin_q
        self.ssin_q, self.scos_q = _quad(self.sin), _quad(self.cos)
        self.sin, self.cos = sin, cos
        self.ira = self.qra = n_ra
        self.iro, self.qro = n_iro, n_qro
        return i_data, q_data


class Mixtx1:
    """Golden model of rtl/nco/mixtx1.v.

    step(i_sig, q_sig) advances one clock and returns the (i_result,
    q_result) visible at the falling edge preceding that clock. Mirrors the
    register pipeline: ssin_q/scos_q, the four 36-bit product registers,
    and the 13-bit i/q_rounded output registers."""

    def __init__(self, phi, calctype=3):
        self.nco = Nco1(phi, calctype)
        self.sin = 0
        self.cos = 0
        self.ssin_q = 0
        self.scos_q = 0
        self.ia = self.ib = self.qa = self.qb = 0   # 36-bit prod registers
        self.i_rounded = 0
        self.q_rounded = 0

    @staticmethod
    def _round20(d):
        # {d[19], d[19:8]} + {12'h0, d[7]} wrapped into 13 bits
        return _s(_mask((d >> 19 << 12) | _mask(d >> 8, 12), 13) +
                  ((d >> 7) & 1), 13)

    def step(self, i_sig, q_sig):
        # outputs visible before this edge
        out_i, out_q = self.i_rounded, self.q_rounded

        s = _s(i_sig, 18)
        t = _s(q_sig, 18)
        # products sampled at this edge with the current sq registers
        n_ia = _mask(s * self.scos_q, 36)
        n_ib = _mask(t * self.ssin_q, 36)
        n_qa = _mask(s * self.ssin_q, 36)
        n_qb = _mask(t * self.scos_q, 36)

        # i_data_d/q_data_d wires from the *pre-edge* product registers
        i20 = _mask(_mask(self.ia >> 16, 20) - _mask(self.ib >> 16, 20), 20)
        q20 = _mask(_mask(self.qa >> 16, 20) + _mask(self.qb >> 16, 20), 20)
        self.i_rounded = self._round20(i20)
        self.q_rounded = self._round20(q20)

        self.ssin_q, self.scos_q = _quad(self.sin), _quad(self.cos)
        sin, cos = self.nco.step()
        self.sin, self.cos = sin, cos
        self.ia, self.ib, self.qa, self.qb = n_ia, n_ib, n_qa, n_qb
        return out_i, out_q


class _CordicBase:
    """Shared NCO + CORDIC iteration for cordic.v and cpl_cordic.v."""

    def _advance_stages(self):
        """One clock of stages 1..STG-1, using the pre-edge X/Y/Z."""
        WR, WZ, STG = self.WR, self.WZ, self.STG
        X = list(self.X)
        Y = list(self.Y)
        Z = list(self.Z)
        for n in range(0, STG - 1):
            x, y, z = self.X[n], self.Y[n], self.Z[n]
            zsign = (z >> (WZ - 1 - n)) & 1
            xshr = x >> (n + 1)     # arithmetic (sign replicated) shift
            yshr = y >> (n + 1)
            # rounded arctan truncated to the WZ-1-n bit field
            a = _mask(self.ATAN[n + 1] >> (32 - WZ), WZ - 1 - n)
            a = _mask(a + ((self.ATAN[n + 1] >> (31 - WZ)) & 1), WZ - 1 - n)
            if zsign:
                X[n + 1] = _s(x + yshr + ((y >> n) & 1), WR)
                Y[n + 1] = _s(y - xshr - ((x >> n) & 1), WR)
            else:
                X[n + 1] = _s(x - yshr - ((y >> n) & 1), WR)
                Y[n + 1] = _s(y + xshr + ((x >> n) & 1), WR)
            if n < STG - 2:
                # only Z[n+1][WZ-2-n:0] is assigned; the unwritten upper
                # bits stay 0 and the carry out of the field is discarded
                field = z & ((1 << (WZ - 1 - n)) - 1)
                Z[n + 1] = _mask((field + a) if zsign else (field - a), WZ - 1 - n)
        self.X, self.Y, self.Z = X, Y, Z

    def _stage0_common(self):
        """{~p29, ~p29, phase[28:32-WZ-1]} for Z[0], and quadrant."""
        p = self.phase
        z = (p >> 29) & 1 ^ 1
        z0 = _s((z << (self.WZ - 1)) | (z << (self.WZ - 2)) |
                ((p >> (31 - self.WZ)) & ((1 << (self.WZ - 2)) - 1)), self.WZ)
        return z0, (p >> 30) & 3

    def _advance_nco(self):
        self.phase = 0 if self.freq == 0 else _mask(self.phase + self.freq, 32)


class Cordic(_CordicBase):
    """Golden model of rtl/radio_openhpsdr1/cordic.v.

    step(in_data) -> (out_I, out_Q) signed. Real input rotated by the
    running NCO phase; gain sqrt(2). Default IN_WIDTH=12, EXTRA_BITS=5:
    WR=18, WZ=16, STG=15, output is the raw final stage (latency 15)."""

    ATAN = ATAN

    def __init__(self, freq, in_width=12, extra_bits=5):
        self.freq = _mask(freq, 32)
        self.IN_WIDTH = in_width
        self.EXTRA_BITS = extra_bits
        self.WR = in_width + extra_bits + 1
        self.WZ = in_width + extra_bits - 1
        self.STG = in_width + extra_bits - 2
        self.phase = 0
        self.X = [0] * self.STG
        self.Y = [0] * self.STG
        self.Z = [0] * self.STG

    def step(self, in_data):
        # The pipeline advances STG-1=14 stage clocks per input sample, but
        # stage 0 also has a register, so the output that appears *after*
        # this clock (the one a cocotb capture on the following falling edge
        # sees) is the new final-stage value: 15 clocks after the input.
        ext = _s(_s(in_data, self.IN_WIDTH) << self.EXTRA_BITS, self.WR)
        z0, quad = self._stage0_common()
        if quad == 0:
            x0, y0 = ext, ext
        elif quad == 1:
            x0, y0 = _s(-ext, self.WR), ext
        elif quad == 2:
            x0, y0 = _s(-ext, self.WR), _s(-ext, self.WR)
        else:
            x0, y0 = ext, _s(-ext, self.WR)

        self._advance_stages()
        self._advance_nco()
        self.X[0], self.Y[0], self.Z[0] = x0, y0, z0
        return self.X[self.STG - 1], self.Y[self.STG - 1]


class CplCordic(_CordicBase):
    """Golden model of rtl/radio_openhpsdr1/cpl_cordic.v.

    step(in_I, in_Q) -> (out_I, out_Q). Default IN_WIDTH=16, EXTRA_BITS=5:
    WR=23, WZ=20, STG=19. With OUT_WIDTH < WR the output register rounds
    (one extra clock)."""

    ATAN = ATAN

    def __init__(self, freq, in_width=16, extra_bits=5, out_width=None):
        self.freq = _mask(freq, 32)
        self.IN_WIDTH = in_width
        self.EXTRA_BITS = extra_bits
        self.WR = in_width + extra_bits + 2
        self.WZ = in_width + extra_bits - 1
        self.STG = in_width + extra_bits - 2
        self.WO = out_width if out_width is not None else self.WR
        self.phase = 0
        self.X = [0] * self.STG
        self.Y = [0] * self.STG
        self.Z = [0] * self.STG
        self.round_I = 0
        self.round_Q = 0

    def step(self, in_I, in_Q):
        # Post-edge convention (empirically validated against the DUT):
        # capture at the falling edge of cycle i equals model state after
        # step(i).  The output register latches the pre-edge final stage.
        ei = _s(_s(in_I, self.IN_WIDTH) << self.EXTRA_BITS, self.WR)
        eq = _s(_s(in_Q, self.IN_WIDTH) << self.EXTRA_BITS, self.WR)
        z0, quad = self._stage0_common()
        if quad == 0:
            x0, y0 = ei - eq, ei + eq
        elif quad == 1:
            x0, y0 = -ei - eq, ei - eq
        elif quad == 2:
            x0, y0 = -ei + eq, -ei - eq
        else:
            x0, y0 = ei + eq, -ei + eq
        x0 = _s(x0, self.WR)
        y0 = _s(y0, self.WR)

        pre_x = self.X[self.STG - 1]
        pre_y = self.Y[self.STG - 1]
        self._advance_stages()
        self._advance_nco()
        self.X[0], self.Y[0], self.Z[0] = x0, y0, z0

        if self.WO != self.WR:
            self.round_I = _s(_mask(pre_x >> (self.WR - self.WO), self.WO) +
                              ((pre_x >> (self.WR - self.WO - 1)) & 1), self.WO)
            self.round_Q = _s(_mask(pre_y >> (self.WR - self.WO), self.WO) +
                              ((pre_y >> (self.WR - self.WO - 1)) & 1), self.WO)
            return self.round_I, self.round_Q
        return self.X[self.STG - 1], self.Y[self.STG - 1]


class Cic:
    """Golden model of rtl/radio_openhpsdr1/cic.v with in_strobe tied high
    and rst_all tied low (as the rx1/rx2 testbenches wire it).

    step(in_data) advances one clock; the returned (out_strobe, out_data)
    are the values visible on the following falling edge, i.e. the
    post-edge strobe register and the combinational rounding of the
    post-edge comb wire. in_data is the wire value sampled by the closing
    rising edge."""

    def __init__(self, stages, decimation, in_width, acc_width, out_width):
        self.S = stages
        self.D = decimation
        self.IW = in_width
        self.AW = acc_width
        self.OW = out_width
        self.sample_no = 0
        self.strobe = 0                 # out_strobe register (visible)
        # integrator registers; integ[0] is cic_integrator #0's out_data,
        # i.e. the register accumulating integrator_data[0] (the wire).
        self.integ = [0] * (stages + 1)
        # comb registers comb[1..S] hold comb_data[1..STAGES]; comb[0] is the
        # wire integrator_data[STAGES].
        self.comb = [0] * (stages + 1)
        self.prev = [0] * stages

    def step(self, in_data):
        # Post-edge convention (matches the cocotb capture-after-step
        # loop): the returned (out_strobe, out_data) are the wire/register
        # values after the rising edge closing this cycle, exactly what the
        # testbench samples with `if decimA_avail:` at the falling edge.
        # integrator_data[0] = { {(ACC_WIDTH-IN_WIDTH){1'b0}}, in_data },
        # i.e. the IN_WIDTH-bit pattern is zero extended (per the RTL)
        w0 = _mask(int(in_data), self.IW)
        # strobe register update uses pre-edge sample_no
        if self.sample_no == self.D - 1:
            n_sample = 0
            n_strobe = 1
        else:
            n_sample = self.sample_no + 1
            n_strobe = 0

        # comb stage updates (strobe visible during the ending cycle)
        comb = list(self.comb)
        prev = list(self.prev)
        if self.strobe:
            comb_wires = [self.integ[self.S]] + \
                         [self.comb[i] for i in range(1, self.S + 1)]
            for i in range(self.S):
                comb[i + 1] = _mask(comb_wires[i] - prev[i], self.AW)
                prev[i] = comb_wires[i]

        # integrator stage updates on in_strobe (always 1)
        integ = list(self.integ)
        for i in range(self.S):
            integ[i + 1] = _mask(integ[i + 1] + (w0 if i == 0 else self.integ[i]),
                                 self.AW)

        self.sample_no = n_sample
        self.strobe = n_strobe
        self.comb = comb
        self.prev = prev
        self.integ = integ

        # decimA_avail/decimA_real captured on the falling edge after the
        # edge closing this cycle: post-edge strobe register and combin-
        # ational rounding of the post-edge comb wire
        v = _s(comb[self.S], self.AW)
        n_vis = _s(_mask(v >> (self.AW - self.OW), self.OW) +
                   ((v >> (self.AW - self.OW - 1)) & 1), self.OW)
        return n_strobe, n_vis


class VarCic:
    """Golden model of rtl/radio_openhpsdr1/varcic.v with a constant
    decimation value."""

    GROWTH = {2: 5, 4: 10, 8: 15, 16: 20,
              3: 8, 6: 13, 12: 18, 24: 23,
              5: 12, 10: 17, 20: 22, 40: 27}

    def __init__(self, stages, in_width, acc_width, out_width, decimation):
        self.S = stages
        self.IW = in_width
        self.AW = acc_width
        self.OW = out_width
        self.dec = decimation
        self.sample_no = 0
        self.strobe = 0
        self.integ = [0] * (stages + 1)
        self.comb = [0] * (stages + 1)
        self.prev = [0] * stages
        g = self.GROWTH[decimation]
        self.msb = in_width + g - 1
        self.lsb = in_width + g - out_width
        self.out = 0                    # out_data register (visible)

    def _round(self, v):
        v = _s(v, self.AW)
        return _s(_mask(v >> self.lsb, self.OW) + ((v >> (self.lsb - 1)) & 1),
                  self.OW)

    def step(self, in_data, in_strobe):
        # out_data is a register: the value visible during this cycle was
        # latched at the previous edge from the pre-edge comb wire
        vis_out = self.out
        vis_strobe = self.strobe

        # sample counter
        if in_strobe:
            if self.sample_no == self.dec - 1:
                n_sample = 0
                n_strobe = 1
            else:
                n_sample = self.sample_no + 1
                n_strobe = 0
        else:
            n_sample = self.sample_no
            n_strobe = 0

        # comb stage updates on visible out_strobe
        comb = list(self.comb)
        prev = list(self.prev)
        if self.strobe:
            comb_wires = [self.integ[self.S]] + \
                         [self.comb[i] for i in range(1, self.S + 1)]
            for i in range(self.S):
                comb[i + 1] = _mask(comb_wires[i] - prev[i], self.AW)
                prev[i] = comb_wires[i]

        # integrator stage updates on visible in_strobe
        integ = list(self.integ)
        if in_strobe:
            for i in range(self.S):
                integ[i + 1] = _mask(integ[i + 1] +
                                     (self._sext_in(in_data) if i == 0 else self.integ[i]),
                                     self.AW)

        # out_data register: rounded comb_data[STAGES] *wire*, i.e. the
        # pre-edge comb[S] value, updated every clock (not strobe-gated)
        n_out = self._round(self.comb[self.S])

        self.sample_no = n_sample
        self.strobe = n_strobe
        self.comb = comb
        self.prev = prev
        self.integ = integ
        self.out = n_out
        return n_strobe, n_out

    def _sext_in(self, v):
        # integrator_data[0] = in_data (signed IN_WIDTH -> signed ACC_WIDTH)
        return _s(int(v), self.IW)


def find_offset(res, model, max_off=96, min_len=64):
    """Align captured res[] against model[] by a shift in either direction.

    Cocotb input writes are flushed on the first await and may be sampled
    one clock later than the model's first step, so the captured stream can
    lead or lag the model stream by a small constant.

    Returns (offset, maxabsdiff) minimising the max abs diff over the
    overlap; model[i+offset] should equal res[i] (offset may be negative)."""
    res = [int(v) for v in res]
    model = [int(v) for v in model]
    best = None
    for off in range(-max_off, max_off + 1):
        if off >= 0:
            n = min(len(res), len(model) - off)
            if n < min_len:
                break
            d = max(abs(res[i] - model[off + i]) for i in range(n))
        else:
            n = min(len(res) + off, len(model))
            if n < min_len:
                continue
            d = max(abs(res[i - off] - model[i]) for i in range(n))
        if best is None or d < best[1]:
            best = (off, d)
        if d == 0:
            break
    return best


def find_offset_iq(res, model, max_off=96, min_len=64):
    """Align I and Q components; returns (offset, maxdiff_i, maxdiff_q) with
    a single offset that minimises the larger of the two diffs.  As with
    find_offset, model[i+offset] should equal res[i]; offset may be
    negative."""
    ri = [int(v.real) for v in res]
    rq = [int(v.imag) for v in res]
    mi = [int(v[0]) for v in model]
    mq = [int(v[1]) for v in model]
    best = None
    for off in range(-max_off, max_off + 1):
        if off >= 0:
            n = min(len(ri), len(mi) - off)
        else:
            n = min(len(ri) + off, len(mi))
        if n < min_len:
            continue
        if off >= 0:
            di = max(abs(ri[i] - mi[off + i]) for i in range(n))
            dq = max(abs(rq[i] - mq[off + i]) for i in range(n))
        else:
            di = max(abs(ri[i - off] - mi[i]) for i in range(n))
            dq = max(abs(rq[i - off] - mq[i]) for i in range(n))
        d = max(di, dq)
        if best is None or d < best[1]:
            best = (off, di, dq)
        if d == 0:
            break
    return best


class RxChain:
    """Lock-step model of the rx1/rx2/rx2IQ testbench chains.

    step(in_data, flushed1, flushed2=1) advances one clock and returns the
    values visible on the following falling edge (post-edge convention,
    validated against the DUTs):

        (cordic_I, cordic_Q, cic_strobe, cic_out[, cic_Q_out]
            [, var_strobe, var_I[, var_Q]])

    Inter-module wires are passed through one clock of register delay
    (the p_* attributes), mirroring how the DUT registers each module's
    output.  The flushed gates replicate the testbench `assign`
    statements, so the cic/varcic models see the identical input stream
    as the DUT."""

    def __init__(self, freq, in_width=12, extra_bits=5,
                 cic_stages=3, cic_decimation=8, cic_acc_width=27,
                 cic_out_width=14, var=None):
        """var: None (rx1), or dict(stages, acc_width, out_width,
        decimation[, iq]) for rx2/rx2IQ.  With iq=True the chain has a
        second cic fed by the cordic Q output (rx2IQ wiring) and returns
        (vs, var_I, var_Q)."""
        self.cordic = Cordic(freq, in_width, extra_bits)
        self.cw = in_width + extra_bits + 1  # cordic word width into cic
        self.cic = Cic(cic_stages, cic_decimation, self.cw,
                       cic_acc_width, cic_out_width)
        self.iq = bool(var and var.get('iq'))
        if self.iq:
            self.cic_q = Cic(cic_stages, cic_decimation, self.cw,
                             cic_acc_width, cic_out_width)
        self.var = []
        if var is not None:
            n = 2 if self.iq else 1
            for _ in range(n):
                self.var.append(VarCic(var['stages'], cic_out_width,
                                       var['acc_width'], var['out_width'],
                                       var['decimation']))
        # inter-module wire values visible during the current cycle
        self.p_ci = self.p_cq = 0
        self.p_cs = self.p_co = self.p_coq = 0

    def step(self, in_data, flushed1=1, flushed2=1):
        # Wires between modules are registered once per clock: at the edge
        # closing this cycle the cic samples the cordic output that was
        # visible *during* the cycle, i.e. what cordic.step returned last
        # time.  Same for the varcic inputs (decimA_real/decimA_avail with
        # the flushed2 gate) one pipeline step later.
        ci, cq = self.cordic.step(in_data)
        cs, co = self.cic.step(self.p_ci if flushed1 else 0)
        outs = [ci, cq, cs, co]
        if self.iq:
            _, coq = self.cic_q.step(self.p_cq if flushed1 else 0)
            outs.append(coq)
        else:
            coq = None
        if self.var:
            vs, vo = self.var[0].step(self.p_co if flushed2 else 0, self.p_cs)
            outs += [vs, vo]
            if len(self.var) > 1:
                _, vo2 = self.var[1].step(self.p_coq if flushed2 else 0,
                                          self.p_cs)
                outs.append(vo2)
        self.p_ci, self.p_cq = ci, cq
        self.p_cs, self.p_co, self.p_coq = cs, co, coq
        return tuple(outs)
