import ft8
import numpy as np
import hl2zmq
import time
import sys
from  multiprocessing import Process


def worker(index,server):
  s = hl2zmq.ipc_req_socket()
  ps = hl2zmq.tcp_push_socket(addr=server)

  while True:
    s.send(b'ready')
    j = s.recv_job(copy=False)
    ft8spots = j.decode()
    ps.send_pyobj(ft8spots)
    #print("Worker {0} done".format(index))



def broker(cpus,server):
  s = hl2zmq.tcp_req_socket(addr=server)
  ps = hl2zmq.ipc_router_socket()

  while True:

    ## Have at least one available worker
    address, empty, ready = ps.recv_multipart()

    ## Ready for job
    s.send(b'ready')

    ## Receive job
    j = s.recv_job(copy=False)

    origbeams = j.beams
    origiq = j.iq
    ## Divy out to CPUs
    for i in range(cpus):
      ## Need new CPU if not first
      if i > 0: address, empty, ready = ps.recv_multipart()
      beams = origbeams[i::cpus]
      if len(beams) > 0:
        j.beams = beams
        j.iq = origiq
        ps.send_job(address,j,copy=True)


if __name__ == "__main__":

  cpus = 2
  if len(sys.argv) > 1:
    cpus = int(sys.argv[1])

  server = "localhost"
  if len(sys.argv) > 2:
    server = sys.argv[2]

  print("Starting with cpus={0} and server={1}".format(cpus,server))

  ## Start broker
  Process(target=broker, args=(cpus,server)).start()

  ## Start one worker per CPU
  for i in range(cpus):
    Process(target=worker, args=(i,server)).start()
