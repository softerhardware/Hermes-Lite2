import os

import numpy as np
import matplotlib as mpl

# Use the headless Agg backend so plots can be rendered to files when
# no display is available. Callers that want an interactive window can
# override this before importing pyplot.
mpl.use(os.environ.get("MPLBACKEND", "Agg"))
import matplotlib.pyplot as plt
import pyfftw

from scipy import signal

try:
    flattop = signal.flattop
    blackmanharris = signal.blackmanharris
except AttributeError:
    # scipy >= 0.18 deprecated signal.flattop in favour of signal.windows
    flattop = signal.windows.flattop
    blackmanharris = signal.windows.blackmanharris


class Spectrum:

  def __init__(self,npa,dt,window=flattop):

    n = len(npa)

    self.complexinput = npa.dtype == 'complex64'

    # pyfftw >= 0.13 uses empty_aligned(shape, dtype, n=alignment)
    if self.complexinput:
      fftia = pyfftw.empty_aligned(n, 'complex64', n=16)
      fftoa = pyfftw.empty_aligned(n, 'complex64', n=16)
    else:
      fftia = pyfftw.empty_aligned(n, 'float32', n=16)
      fftoa = pyfftw.empty_aligned(int(n/2) + 1, 'complex64', n=16)

    fft = pyfftw.FFTW(fftia,fftoa,flags=('FFTW_ESTIMATE',),planning_timelimit=60.0)

    maxv = npa.max()
    minv = npa.min()
    print("Max/Min is",maxv,minv)

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

    if self.complexinput:
      self.sa = np.concatenate( [self.sa[int(n/2):n],self.sa[0:int(n/2)]] )
    else:
      ## 2.0 To get magnitude in terms of original V since half of spectrum is returned
      self.sa = 2* self.sa

    ## Result is vrms
    print("Converting to dBFS")

    maxv = self.sa.max()
    print("Max is",maxv)

    self.sa = 20.0*np.log10(self.sa/maxv)

    if self.complexinput:
      self.mhz2bin = len(self.sa) * 1e6 * dt
    else:
      self.mhz2bin = len(self.sa) * 1e6 * 2 * dt

    self.bin2mhz = 1.0/self.mhz2bin

    print("Spectrum Array length is",len(self.sa))

  def binFreq(self,i):

    if self.complexinput:
      return (i - (len(self.sa)/2)) * self.bin2mhz
    else:
      return i * self.bin2mhz

  def findPeaks(self,order=2,clipdb=None):

    sa = self.sa

    if clipdb:
        normcarrier = self.sa.max()
        sa = np.clip(sa,-clipdb,normcarrier+1)

    res = signal.argrelmax(sa,order=order)[0]

    peaks = []
    for i in res:
        peaks.append( (self.sa[i],self.binFreq(i)) )

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

  def draw(self,fig,title='Spectrum'):

    sa = self.sa
    n = len(sa)

    if self.complexinput:
      xaxis = (np.r_[0:n] - (n/2)) * self.bin2mhz
    else:
      xaxis = np.r_[0:n] * self.bin2mhz

    sp = fig.add_subplot(111)
    sp.plot(xaxis,sa)
    sp.set_ylabel("dB")
    sp.set_xlabel("MHz")
    return sp

  def plot(self,title='Spectrum'):

    fig = plt.figure()
    fig.subplots_adjust(bottom=0.2)
    fig.suptitle(title, fontsize=20)
    self.draw(fig,title)
    plt.show()

  def savepng(self,filename,title='Spectrum'):
    """Render the spectrum to a PNG file (works headless)."""

    fig = plt.figure(figsize=(10,6))
    fig.subplots_adjust(bottom=0.15, top=0.9)
    fig.suptitle(title, fontsize=20)
    self.draw(fig,title)
    fig.savefig(filename, dpi=100)
    plt.close(fig)
    return filename


class SpectrumIQ(Spectrum):

  def __init__(self,npa,dt,decimation,window=flattop):

    n = len(npa)
    print("Length n is",n)

    # the spectrum is complex (centred at DC); inherited draw/findPeaks
    # rely on this flag
    self.complexinput = True

    fftpg = 10*np.log10(n)
    print("FFT Processing Gain {0:.1f} dB".format(fftpg))
    filterpg = 10*np.log10(decimation)
    print("Filter Processing Gain {0:.1f} dB".format(filterpg))
    totalpg=fftpg+filterpg
    print("Total Processing Gain {0:.1f} dB".format(totalpg))

    fftia = pyfftw.empty_aligned(n, 'complex64', n=16)
    fftoa = pyfftw.empty_aligned(n, 'complex64', n=16)

    fft = pyfftw.FFTW(fftia,fftoa) ##,flags=('FFTW_ESTIMATE',),planning_timelimit=60.0)

    ra = np.real(npa)
    ia = np.imag(npa)
    bitsused = int(np.ceil(np.log2(2*np.max([np.max(ra),np.abs(np.min(ra)),np.max(ia),np.abs(np.min(ia))]))))
    print("Input bits in use",bitsused)

    if window:
      w = window(n)
      fftia[:] = w * npa
    else:
      fftia[:] = npa

    fft()

    self.sa = np.abs(fftoa)

    ## Scale amplitude for window
    if window:
      scale = 1.0/np.sum(window(10000)/10000.0)
      print("Scaling postwindow by",scale)
      self.sa = scale * self.sa

    self.sa = np.concatenate( [self.sa[int(n/2):n],self.sa[0:int(n/2)]] )

    ## Result is vrms

    maxv = self.sa.max()

    self.sa = 20.0*np.log10(self.sa/maxv)

    w = int(n/4)
    print("Quarter noise floor means: {0:.1f} {1:.1f} {2:.1f} {3:.1f}".format(
      np.mean(self.sa[:w]),np.mean(self.sa[w:2*w]),np.mean(self.sa[2*w:3*w]),np.mean(self.sa[3*w:])))

    self.mhz2bin = len(self.sa) * 1e6 * dt * decimation
    self.bin2mhz = 1.0/self.mhz2bin

    print("Spectrum Array length is",len(self.sa))
