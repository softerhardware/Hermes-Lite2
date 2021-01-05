import numpy as np
import ft8d
import collections
import time
import socket
from maidenhead import maiden2distanceheading

ft8_spot = collections.namedtuple("ft8_spot", "sync xsnr xdt freq msgcall msggrid msg37")

class ft8_spots(object):
  def __init__(self,hostname,jobtime,ts,dial,beams):
    self.hostname = hostname
    self.jobtime = jobtime
    self.ts = ts
    self.dial = dial
    self.beams = beams

  def short_info(self):
    return "{0} {1} {2} {3} {4}".format(
      self.hostname,self.jobtime,self.ts,self.dial,len(self.beams))

  def basic_info(self):
    base = set()
    mixed = set()
    for beam,spots in self.beams.items():
      if beam == ((0,0),) or beam == ((1,0),):
        for spot in spots: base.add(spot.msg37)
      else:
        for spot in spots: mixed.add(spot.msg37)
    unique = len(mixed - base)
    missed = len(base - mixed)
    total  = len(base | mixed)
    return "host={0} jobtime={1} ts={2} dial={3} beams={4} unique={5} missed={6} total={7}".format(
      self.hostname,self.jobtime,self.ts,self.dial,len(self.beams),unique,missed,total)

  def update_stats(self,locations,stats,bins):

    for beam,spots in self.beams.items():
      for spot in spots:
        knownlocation = None
        if spot.msggrid != '':
          if spot.msgcall != '': locations[spot.msgcall] = spot.msggrid
          knownlocation = spot.msggrid
        elif spot.msgcall != '' and spot.msgcall in locations:
          knownlocation = locations[spot.msgcall]

        if knownlocation != None:
          d,h = maiden2distanceheading(knownlocation)
          h = int(h/bins) ## Reduce number of headings and bin ranges of headings
          if h not in stats: stats[h] = {}

          if beam not in stats[h]: stats[h][beam] = (0,0)

          totspots,totsnr = stats[h][beam]

          stats[h][beam] = (totspots+1,totsnr+spot.xsnr+27)







class ft8(object):
  def __init__(self,ts,dial,beams,iq):
    self.ts = ts
    self.dial = dial
    self.beams = beams
    self.iq = iq

  def stripiq(self):
    self.dtype = self.iq.dtype
    self.shape = self.iq.shape
    res = self.iq
    delattr(self,"iq")
    return res

  def restoreiq(self,msg):
    iq = np.frombuffer(msg, self.dtype)
    self.iq = iq.reshape(self.shape)
    delattr(self,"dtype")
    delattr(self,"shape")


  def _decode1(self,iq,apsym):
    spots = {}
    ndepth=3
    lsubtract = True
    ft8spots = []

    for ipass in range(5):

      newdat = True

      if ipass > 1:
        lsubtract = False
      else:
        lsubtract = True

      #if ipass >= 2: lsubtract = False
      #if ipass % 2:
      #  lsubtract = True
      #else:
      #  lsubtract = False


      s,candidate,ncand,sbase = ft8d.sync8(iq,400,3600,1.5,2000)
      #print("ncand",ncand)

      newspot = False
      for cand in range(ncand):
        sync = candidate[2,cand]
        f1 = candidate[0,cand]
        xdt = candidate[1,cand]

        xbase=10.0**(0.1*(sbase[int(round(f1/3.125))-1]-40.0))

        nharderrors,dmin,nbadcrc,iappass,msg37,msgcall,msggrid,xsnr = ft8d.ft8b(
          iq,newdat,0,2000,
          0,ndepth,False,False,0,lsubtract,False,
          0,0,f1,xdt,xbase,apsym)

        newdat = False

        msgcall = msgcall.decode()

        ##print(msgcall)
        if nbadcrc==0 and msgcall[0] !=' ' and msgcall[0] != '<':
          msg37 = msg37.decode()
          msggrid = msggrid.decode()
          msg37 = msg37.strip()
          if len(msg37) > 0:
            if msg37 not in spots:
              newspot = True
              spots[msg37] = True

              s = ft8_spot(min(sync,999.0),int(round(xsnr)),xdt,
                int(round(f1-2000+self.dial)),msgcall.strip(),msggrid.strip(),msg37)
              ft8spots.append(s)

      ## Early exits to save time
      #if not newspot: break
      if not newspot and ipass == 0: break
      if not newspot and ipass >= 2: break
    return ft8spots

  def decode(self):

    apsym = np.zeros((58,), dtype=np.intc)
    apsym[0] = 99
    apsym[29] = 99
    resbeams = {}
    hostname = socket.gethostname()

    jobtime = time.time()

    for beam in self.beams:
      iq = [(self.iq[r[0]] if r[1] == 0 else (self.iq[r[0]]*np.exp(-1j*(r[1]/360)*2*np.pi)))
        for r in beam]
      iq = sum(iq)/len(beam)
      ft8spots = self._decode1(iq,apsym)
      resbeams[beam] = ft8spots

    jobtime = time.time() - jobtime

    return ft8_spots(hostname,jobtime,self.ts,self.dial,resbeams)
