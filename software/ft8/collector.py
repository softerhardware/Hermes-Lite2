import ft8
import numpy as np
import hl2zmq

s = hl2zmq.tcp_collector_socket()

locations = {}
stats = {}
i = 20

while True:
  r = s.recv_pyobj()
  print(r.short_info())
  r.update_stats(locations,stats,10)
  if i == 0:
    print(stats)
    i = 20
  else:
    i = i-1
