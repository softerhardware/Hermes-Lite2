import socket, select, struct, collections, time, os
import shutil, tempfile, urllib.request
import numpy as np
import hermeslite
import hl2zmq
import numpy as np
import time
import ft8
import sys


class RX:

  def __init__(self,dialfreq):
    self.dialfreq = dialfreq

    self.hl = hermeslite.discover_first()

    self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    self.sock.setblocking(0)
    self.ip = self.hl.ip

    self.iq = np.zeros((2,60000,), dtype=np.complex64)

    self.s = hl2zmq.tcp_router_socket()

    ## Always include rx0 and rx1
    self.beams = [((0,0),),((1,0),)]

    ## Create beams, each beam is a list or RX streams with are rotated and summed
    for deg in np.linspace(0,360,14,endpoint=False):
      self.beams.append( ((0,0),(1,int(round(deg)))) )



  def sync(self):

    self.hl.synchronize_radios()

    ## Enable 2 receivers at 48kHz
    self.hl.command(0x00,bytes([0x0,0x0,0x0,0xc]))

    ##self.hl.command(0x00,bytes([0x0,0x0,0x0,0xc]))

    ## Set LNA to 19dB
    self.hl.command(0x0a,bytes([0x0,0x0,0x0,0x5f]))

    ## Set Dial Frequency
    self.hl.command(0x02,self.dialfreq)

    self.hl.command(0x03,self.dialfreq)

  def desync(self):
    self.hl.desynchronize_radios()


  def capture(self,captures=-1):

    self.hl.command(0x02,self.dialfreq)
    self.hl.command(0x03,self.dialfreq)


    ## Resync NCOs
    self.hl.command(0x39,bytes([0x00,0x00,0x00,0x90]))


    self.maxv = 0

    sample = 0

    ## Start radio
    self.sock.sendto(bytes([0xef,0xfe,0x04,0x81]+([0x0]*60)), (self.ip,1024))

    try:
      while captures != 0:
        self.iq.fill(0)
        ## Align to 15 seconds
        sample = 0
        while True:
          self._getdata(sample)
          t = time.gmtime()
          if t.tm_sec % 15 == 0: break;

        sample = sample + 72

        while sample < 58000:
          self._getdata(sample)
          sample = sample + 72

        ## Pop next available worker
        address, empty, ready = self.s.recv_multipart()

        self.s.send_job(address,ft8.ft8(int(time.time()),self.dialfreq,self.beams,self.iq),copy=True)

        #fn = "ft8_pub_{0}".format(int(time.time()))
        #np.save(fn,self.iq[0])

        if captures > 0: captures -= 1
        print("Max value is",self.maxv)
        self.maxv = 0

    except KeyboardInterrupt:
      print('Interrupted')

    ## Stop radio
    self.sock.sendto(bytes([0xef,0xfe,0x04,0x00]+([0x0]*60)), (self.ip,1024))


  def _getdata(self,sample):

    while True:
      ready = select.select([self.sock], [], [], 2.0)
      if ready[0]:
        data, ip_port = self.sock.recvfrom(1032)
        k = sample
        for base in [16,528]:
          for j in range(base,base+504,14):
            i1,q1,i2,q2 = struct.unpack("3s3s3s3s",data[j:j+12])
            ##print(data[j:j+12], end=" ")
            i1 = 100*(int.from_bytes(i1, byteorder='big', signed=True))/8388607.0
            q1 = -100*(int.from_bytes(q1, byteorder='big', signed=True))/8388607.0
            i2 = 100*(int.from_bytes(i2, byteorder='big', signed=True))/8388607.0
            q2 = -100*(int.from_bytes(q2, byteorder='big', signed=True))/8388607.0
            self.iq[0][k] = np.complex(i1,q1)
            self.iq[1][k] = np.complex(i2,q2)
            self.maxv = max(abs(i1),abs(q1),abs(i2),abs(q2),self.maxv)
            k += 1
        return





##rx = RX(14075500)
rx = RX(7075500)
if len(sys.argv) > 1: rx.sync()
rx.capture()

