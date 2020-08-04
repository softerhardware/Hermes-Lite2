import socket, select, struct, collections, time

## The one response type received from the HL2
Response = collections.namedtuple('Response',
'type \
mac \
gateware \
radio_id \
use_eeprom_ip \
use_eeprom_mac \
favor_dhcp \
eeprom_ip \
eeprom_mac \
receivers \
board_id \
wideband_type \
response_data \
ext_cw_key \
tx_on \
adc_clip_cnt \
temperature \
fwd_pwr \
rev_pwr \
bias \
txfifo_recovery \
txfifo_msbs')


def decode(r):
  """Decode a received bytes object to a HL2 response."""
  ## Check length
  if len(r) != 60: return False
  ## Check cookie
  if r[0x0:0x2] != b'\xef\xfe': return False
  t = r[2]
  mac = "%02x:%02x:%02x:%02x:%02x:%02x" % struct.unpack("BBBBBB",r[3:9])
  gateware = "{0}.{1}".format(r[0x09],r[0x15])
  radio_id = r[0x0a]
  temp = r[0x0b]
  use_eeprom_ip  =  (temp & 0x80) != 0
  use_eeprom_mac = (temp & 0x40) != 0
  favor_dhcp = (temp & 0x20) != 0
  eeprom_ip = "%d:%d:%d:%d" % struct.unpack("BBBB",r[0x0d:0x11])
  eeprom_mac = "%02x:%02x:%02x:%02x:%02x:%02x" % struct.unpack("BBBBBB",r[0x03:0x07]+r[0x11:0x13])
  receivers = r[0x13]
  temp = r[0x14]
  board_id = temp & 0x3f
  wideband_type = 0x03 & (temp >> 6)
  response_data = struct.unpack('!L',r[0x17:0x1b])[0]
  temp = r[0x1b]
  ext_cw_key = (temp & 0x80) != 0
  tx_on     = (temp & 0x40) != 0
  adc_clip_cnt = temp & 0x03
  temperature = struct.unpack('!H',r[0x1c:0x1e])[0]
  # For best accuracy, 3.26 should be a user's measured 3.3V supply voltage.
  temperature = (3.26 * (temperature/4096.0) - 0.5)/0.01
  # TODO: Add proper power compoutation, maybe table interpolation like Quisk
  fwd_pwr = struct.unpack('!H',r[0x1e:0x20])[0]
  rev_pwr = struct.unpack('!H',r[0x20:0x22])[0]
  bias   = struct.unpack('!H',r[0x22:0x24])[0]
  bias   = ((3.26 * (bias/4096.0))/50.0)/0.04
  temp = r[0x24]
  txfifo_recovery = (temp & 0x80) != 0
  txfifo_msbs = (temp & 0x7f)
  return Response(t,mac,gateware,radio_id,use_eeprom_ip,use_eeprom_mac,favor_dhcp,eeprom_ip,eeprom_mac,
    receivers,board_id,wideband_type,response_data,ext_cw_key,tx_on,adc_clip_cnt,temperature,
    fwd_pwr,rev_pwr,bias,txfifo_recovery,txfifo_msbs)


def discover():
  """Discover available HL2s."""
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
  sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
  sock.setblocking(0)
  msg = bytes([0xEF,0xFE,0x02]+(0*[0]))
  sock.sendto(msg, ('255.255.255.255', 1025))

  responses = []
  while True:
    ready = select.select([sock], [], [], 1.0)
    if ready[0]:
      data, address = sock.recvfrom(60)
      print("Discover response from %s:%d" %(address[0], address[1]))
      r = decode(data)
      if r: responses.append((address[0],r))
    else:
      ## Timeout so no more units to discover
      break

  return responses



class HermesLite:
  # Hermes-Lite object
  def __init__(self,ip,timeout=2.0):
    self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    self.sock.setblocking(0)
    self.ip_port = (ip,1025)
    self.timeout = timeout
    self.wrcache = {}

  def _send(self,msg):
    """Low level send to HL2."""
    attempts = 3
    while attempts > 0:
      self.sock.sendto(msg, self.ip_port)
      ready = select.select([self.sock], [], [], self.timeout)
      if ready[0]:
        data, ip_port = self.sock.recvfrom(60)
        if ip_port != self.ip_port: continue
        return decode(data)
      attempts -= 1
      print("Retrying send")
    return None

  def command(self,addr,cmd):
    """Send command at address to HL2, cmd may be bytes or number.
      Returns a response."""
    if isinstance(cmd,int):
      cmd = struct.pack('!L',cmd)
    res = self._send(bytes([0xef,0xfe,0x05,addr<<1])+cmd)
    if res:
      self.wrcache[addr] = cmd

  def response(self):
    """Retrieve a response without sending address and command."""
    return self._send(bytes([0xef,0xfe,0x02,0x0,0x0,0x0,0x0,0x0]))

  def config_txbuffer(self,latency=10,ptt_hang=4):
    """Set buffer latency and ptt hang time in ms."""
    cmd = bytes([0x00,0x00,int(ptt_hang)&0x1f,int(latency)&0x7f])
    return self.command(0x17,cmd)

  def write_versa5(self,addr,data):
    """Write to Versa5 clock chip via i2c."""
    time.sleep(0.002)
    data = data & 0x0ff
    addr = addr & 0x0ff
    ## i2caddr is 7 bits, no read write
    ## Bit 8 is set to indicate stop to HL2
    ## i2caddr = 0x80 | (0xd4 >> 1) ## ea
    cmd = bytes([0x06,0xea,addr,data])
    return self.command(0x3c,cmd)

  def read_versa5(self,addr,fullrepsonse=False):
    """Read from Versa5 clock chip via i2c."""
    time.sleep(0.002)
    addr = addr & 0xff
    cmd = bytes([0x07,0xea,addr,0x00])
    res = self.command(0x3c,cmd)
    if fullresponse:
      return res
    else:
      return res.response_data & 0x0ff

  def reset_versa5(self):
    """Force reset of both PLL counters to synchronize clocks"""
    cmd = bytes([0x00,0x00,0x00,0x00])
    return self.command(0x39,cmd)

  def enable_cl2_copy_ad9866(self):
    """Enable CL2 output, copy of clock to AD9866."""
    self.write_versa5(0x62,0x3b) ## Clock2 CMOS1 output, 3.3V
    self.write_versa5(0x2c,0x01) ## Enable aux output on clock 1
    self.write_versa5(0x31,0x0c) ## Use clock1 aux output as input for clock2
    self.write_versa5(0x63,0x01) ## Enable clock2

  def enable_cl2_sync_76p8(self,iskw=0,fskw=31):
    """Enable CL2 synchronous output at 76.8MHz"""
    iskw = iskw & 0x0f
    iskw = iskw << 4
    fskw = fskw & 0x3f
    self.write_versa5(0x62,0x3b) ## Clock2 CMOS1 output, 3.3V
    self.write_versa5(0x3d,0x01) ## Set divide by 0x0110
    self.write_versa5(0x3e,0x10)
    self.write_versa5(0x31,0x81) ## Enable divider output for clock2
    self.write_versa5(0x3c,iskw) ## Write integer portion of skew
    self.write_versa5(0x3f,fskw) ## Write fractional portion of skew
    self.write_versa5(0x63,0x01) ## Enable clock2 output
    self.reset_versa5()

  def disable_cl2(self):
    """Disable CL2 clock output"""
    self.write_versa5(0x31,0x80) ## Disable divider output for clock2
    self.write_versa5(0x63,0x00) ## Disable clock2 output

  def enable_cl2_61p44(self):
    """Enable CL2 output at 61.44MH"""
    self.write_versa5(0x62,0x3b) ## Clock2 CMOS1 output, 3.3V
    self.write_versa5(0x2c,0x00) ## Disable aux output on clock 1
    self.write_versa5(0x31,0x81) ## Use divider for clock2
    ## VCO multiplier is shared for all outputs, set to 68 by firmware
    ## VCO = 38.4*68 = 2611.2 MHz
    ## There is a hardwired divide by 2 in the Versa 5 at the VCO output
    ## VCO to Dividers = 2611.2 MHZ/2 = 1305.6
    ## Target frequency of 61.44 requires dividers of 1305.6/61.44 = 21.25
    ## Frational dividers are supported
    ## Set integer portion of divider 21 = 0x15, 12 bits split across 2 registers
    self.write_versa5(0x3d,0x01)
    self.write_versa5(0x3e,0x50)
    ## Set fractional portion, 30 bits, 2**24 * .25 = 0x400000
    self.write_versa5(0x32,0x01) ## [29:22]
    self.write_versa5(0x33,0x00) ## [21:14]
    self.write_versa5(0x34,0x00) ## [13:6]
    self.write_versa5(0x35,0x00) ## [5:0] and disable ss
    self.write_versa5(0x63,0x01) ## Enable clock2

  def enable_cl1_direct(self):
    """Pass CL1 input directly with buffering to AD9866"""
    self.write_versa5(0x17,0x02) ## Change top multiplier to 0x22
    self.write_versa5(0x18,0x20)
    self.write_versa5(0x10,0xc0) ## Enable xtal and clock
    self.write_versa5(0x13,0x03) ## Switch to clock
    self.write_versa5(0x10,0x44) ## Enable clock input only and refmode
    self.write_versa5(0x21,0x0c) ## Use previous channel, direct input, may have skew

  def enable_cl1_pll1(self):
    """Use CL1 as input to PLL1 and then to AD9866"""
    self.write_versa5(0x17,0x02) ## Change top multiplier to 0x22
    self.write_versa5(0x18,0x20)
    self.write_versa5(0x10,0xc0) ## Enable xtal and clock
    self.write_versa5(0x13,0x03) ## Switch to clock
    self.write_versa5(0x10,0x40) ## Enable clock input only, won't lock to master

  def disable_cl1(self):
    """Stop using CL1 and revert to default xtal oscillator input"""
    self.write_versa5(0x10,0xc4) ## Enable xtal and clock
    self.write_versa5(0x21,0x81) ## Use and enable divider
    self.write_versa5(0x13,0x00) ## Use CL1 input instead of xtal
    self.write_versa5(0x10,0x80) ## Enable xtal input only
    self.write_versa5(0x17,0x04) ## Change top multiplier to 0x44
    self.write_versa5(0x18,0x40)


if __name__ == "__main__":
  responses = discover()
  if responses != []:
    hl = HermesLite(responses[0][0])
  else:
    print("No Hermes-Lite discovered")

