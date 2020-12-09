import hermeslite
import VCDWriter


class debug(object):

  def __init__(self):
    self.hl = self.hl = hermeslite.discover_first()

  def text(self):

    ## Enable extra response to port 1025 for every packet set by HL2
    self.hl.command(0x39,bytes([0x0b,0x00,0x00,0x00]))

    try:

      while True:
        resp = self.hl._recv()
        if resp != None:
          print(resp.rem[:5])
        else:
          print("No Response")

    except KeyboardInterrupt:
      print('Interrupted')


    ## Enable extra response to port 1025 for every packet set by HL2
    self.hl.command(0x39,bytes([0x0a,0x00,0x00,0x00]))


  def vcd(self):

    def period(r):
      receivers = r.rem[4] & 0x0f
      sample_per = 1.0/(48000*(2**(r.rem[4] >> 6)))
      if receivers == 0:
        sample_per = sample_per * 126
      elif receivers == 1:
        sample_per = sample_per * 72
      elif receivers == 2:
        sample_per = sample_per * 50
      else:
        sample_per = sample_per * 38
      return int(sample_per * 1.0e9)


    fp = open("debug.vcd","w")

    if fp == None:
      print("Can't open vcd file to write")
      return 

    wr = VCDWriter.VCDWriter(fp, timescale='1 ns', date='today')

    resp = self.hl.response()

    ## Variables
    vals = []

    f = lambda r: r.rem[1]
    i = f(resp)
    v = wr.register_var('hl','tx_buffer_latency','integer',size=8,init=i)
    vals.append( (f,i,v) )

    #f = lambda r: ((r.rem[3] & 0xc0) << 2) | r.rem[2]
    #i = f(resp)
    #v = wr.register_var('hl','cw_hang_time','integer',size=11,init=i)
    #vals.append( (f,i,v) )

    f = lambda r: r.rem[3] & 0x1f
    i = f(resp)
    v = wr.register_var('hl','ptt_hang_time','integer',size=6,init=i)
    vals.append( (f,i,v) )

    f = lambda r: (r.rem[4] >> 5) & 0x01
    i = f(resp)
    v = wr.register_var('hl','cmd_ptt','wire',size=1,init=i)
    vals.append( (f,i,v) )

    #f = lambda r: r.ext_cw_key
    #i = f(resp)
    #v = wr.register_var('hl','ext_cw_key','wire',size=1,init=i)
    #vals.append( (f,i,v) )

    #f = lambda r: r.ptt_resp
    #i = f(resp)
    #v = wr.register_var('hl','ptt_resp','wire',size=1,init=i)
    #vals.append( (f,i,v) )

    #f = lambda r: r.pa_exttr
    #i = f(resp)
    #v = wr.register_var('hl','pa_exttr','wire',size=1,init=i)
    #vals.append( (f,i,v) )

    #f = lambda r: r.pa_inttr
    #i = f(resp)
    #v = wr.register_var('hl','pa_inttr','wire',size=1,init=i)
    #vals.append( (f,i,v) )

    f = lambda r: r.tx_on
    i = f(resp)
    v = wr.register_var('hl','tx_on','wire',size=1,init=i)
    vals.append( (f,i,v) )

    f = lambda r: (r.rem[4] >> 4) & 0x01
    i = f(resp)
    v = wr.register_var('hl','tx_wait','wire',size=1,init=i)
    vals.append( (f,i,v) )

    #f = lambda r: r.cw_on
    #i = f(resp)
    #v = wr.register_var('hl','cw_on','wire',size=1,init=i)
    #vals.append( (f,i,v) )

    f = lambda r: r.txfifo_recovery
    i = f(resp)
    v = wr.register_var('hl','txfifo_recovery','wire',size=1,init=i)
    vals.append( (f,i,v) )

    f = lambda r: round(0.667* r.txfifo_msbs,1)
    i = f(resp)
    v = wr.register_var('hl','txfifo_ms','real',size=8,init=i)
    vals.append( (f,i,v) )

    fpkt = lambda r: r.rem[0]
    i = fpkt(resp)
    v = wr.register_var('hl','pkt_cnt','integer',size=9,init=i)
    vals.append( (fpkt,i,v) )


    ts = 0

    ## Enable extra response to port 1025 for every packet set by HL2
    self.hl.command(0x39,bytes([0x0b,0x00,0x00,0x00]))

    try:

      while True:
        resp = self.hl._recv()
        if resp != None:
          ts = ts + period(resp)
          nvals = []
          for f,i,v in vals:
            ni = f(resp)
            if ni != i:
              wr.change(v,ts,ni)

            nvals.append((f,ni,v))
          vals = nvals

    except KeyboardInterrupt:
      print('Interrupted')


    ## Enable extra response to port 1025 for every packet set by HL2
    self.hl.command(0x39,bytes([0x0a,0x00,0x00,0x00]))






d = debug()

