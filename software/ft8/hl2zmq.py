import numpy
import zmq

class CoherentRXSocket(zmq.Socket):
    """A class with some extra serialization methods
    to send coherent RX data form the HL2
    """
    def send_job(self, address, job, flags=0, copy=True, track=False):
        """send decode job"""
        iq = job.stripiq()
        self.send(address, flags | zmq.SNDMORE)
        self.send(b'', flags | zmq.SNDMORE) ## Empty frame per zmq load balancing example
        self.send_pyobj(job, flags | zmq.SNDMORE)
        return self.send(iq, flags, copy=copy, track=track)

    def recv_job(self, flags=0, copy=False, track=False):
        """recv decode job"""
        job = self.recv_pyobj(flags=flags)
        msg = self.recv(flags=flags, copy=copy, track=track)
        job.restoreiq(msg)
        return job

class CoherentRXContext(zmq.Context):
    _socket_class = CoherentRXSocket


def ipc_pub_socket(fn="coherentrx"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.PUB)
  s.bind("ipc:///tmp/{0}".format(fn))
  return s

def ipc_sub_socket(fn="coherentrx"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.SUB)
  s.connect("ipc:///tmp/{0}".format(fn))
  return s

def tcp_pub_socket(port="5555"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.PUB)
  s.bind("tcp://*:%s" % port)
  return s

def tcp_sub_socket(port="5555"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.SUB)
  s.connect ("tcp://localhost:%s" % port)
  return s



def tcp_router_socket(addr="*",port="5555"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.ROUTER)
  s.bind("tcp://{0}:{1}".format(addr,port))
  return s

def tcp_req_socket(addr="localhost",port="5555"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.REQ)
  s.connect("tcp://{0}:{1}".format(addr,port))
  return s


def tcp_collector_socket(addr="*",port="5556"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.PULL)
  s.bind("tcp://{0}:{1}".format(addr,port))
  return s

def tcp_push_socket(addr="localhost",port="5556"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.PUSH)
  s.connect("tcp://{0}:{1}".format(addr,port))
  return s


def ipc_router_socket(fn="ft8"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.ROUTER)
  s.bind("ipc:///tmp/{0}".format(fn))
  return s

def ipc_req_socket(fn="ft8"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.REQ)
  s.connect("ipc:///tmp/{0}".format(fn))
  return s

def ipc_router_socket(fn="ft8"):
  ctx = CoherentRXContext()
  s = ctx.socket(zmq.ROUTER)
  s.bind("ipc:///tmp/{0}".format(fn))
  return s
