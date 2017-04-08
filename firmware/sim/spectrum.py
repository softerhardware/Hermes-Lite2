

import numpy as np
import matplotlib as mpl
mpl.use('Qt4Agg',warn=False)
##mpl.rcParams['agg.path.chunksize'] = 1000000
import matplotlib.pyplot as plt
import pyfftw, sys

from scipy import signal

class Spectrum:

  def __init__(self,npa,dt,window=None):

    n = len(npa)

    fftia = pyfftw.n_byte_align_empty(n, 16, 'float32')
    fftoa = pyfftw.n_byte_align_empty(int(n/2) + 1, 16, 'complex64')
    fft = pyfftw.FFTW(fftia,fftoa,flags=('FFTW_ESTIMATE',),planning_timelimit=60.0)

    maxv = npa.max()
    print("Max value is",maxv)

    if window: 
      w = window(n)
      fftia[:] = w * (npa/maxv) 
    else:
      fftia[:] = npa/maxv

    fft()

    self.sa = np.abs(fftoa)

    ## Scale amplitude for window
    if window:
      scale = 1.0/np.sum(window(10000)/10000.0)
      print("Scaling postwindow by",scale)
      self.sa = scale * self.sa

    ## 2.0 To get magnitude in terms of original V since half of spectrum is returned
    ## Result is vrms
    print("Converting to dBFS")

    maxv = self.sa.max()
    print("Max is",maxv)

    self.sa = 20.0*np.log10(self.sa/maxv) 

    self.mhz2bin = len(self.sa) * 1e6 * 2 * dt
    self.bin2mhz = 1.0/self.mhz2bin

    print("Spectrum Array length is",len(self.sa))


  def findPeaks(self,order=2,clipdb=None):

    sa = self.sa

    if clipdb: 
        normcarrier = self.sa.max()
        sa = np.clip(sa,-clipdb,normcarrier+1)

    res = signal.argrelmax(sa,order=order)[0]

    peaks = []
    for i in res:
        peaks.append( (self.sa[i],i*self.bin2mhz) )

    return peaks

  def printPeaks(self,peaks,maxtoprint=200):

    if len(peaks) > maxtoprint:
      print("Too many peaks to print")
      return
    else:
      print("Found {0} peaks".format(len(peaks)))

    print("|  MHz  |  dB  |")
    print("| -----:| ----:|")
    for (db,mhz) in peaks:
        print("| {0:10.6f} | {1:7.2f} |".format(mhz,db))




  def plot(self):

    sa = self.sa
    n = len(sa)

    title = "Spectrum"
    fig = plt.figure()
    fig.subplots_adjust(bottom=0.2)
    fig.suptitle(title, fontsize=20)
    sp = fig.add_subplot(111)

    xaxis = np.r_[0:n] * self.bin2mhz

    sp.plot(xaxis,sa) ##,'-',color='b',label='Spectrum')
    sp.set_ylabel("dBFS")
    sp.set_xlabel("MHz")

    plt.show()              


if __name__ == '__main__':
  npa = np.load("cosa.npy")

  dt = 1.0/73.728e6

  s = Spectrum(npa,dt,window=signal.flattop)
  peaks = s.findPeaks(order=4,clipdb=90)
  s.printPeaks(peaks)
  s.plot()
