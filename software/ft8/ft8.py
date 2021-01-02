import numpy as np
import ft8d


#import collections

## Rotation
#Job = collections.namedtuple("Job", "ts dial beams iq")
#Spot = collections.namedtuple("Spot", "ts dial")


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

              print("{0:6.1f} {1:5d} {2:6.2f} {3:6d} {4:20s} {5:20s}".format(
                min(sync,999.0),int(round(xsnr)),xdt,
                int(round(f1)),msgcall,msggrid))

      ## Early exits to save time
      #if not newspot: break
      if not newspot and ipass == 0: break
      if not newspot and ipass >= 2: break
    return ipass

  def decode(self):

    apsym = np.zeros((58,), dtype=np.intc)
    apsym[0] = 99
    apsym[29] = 99

    for beam in self.beams:
      iq = [(self.iq[r[0]] if r[1] == 0 else (self.iq[r[0]]*np.exp(-1j*(r[1]/360)*2*np.pi)))
        for r in beam]
      iq = sum(iq)/len(beam)
      print("BEAM",beam)
      ip = self._decode1(iq,apsym)
      print("IPASS",ip)

