import socket, select, struct, collections, time, os
import shutil, tempfile, urllib.request, netifaces

# Send commands to the Hermes Lite 2 on port 1025.
# Original author Steve Haynal, KF7O.
# Changed April 2023 by N2ADR to add support for the IO board.

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
ptt_resp \
pa_exttr \
pa_inttr \
tx_on \
cw_on \
adc_clip_cnt \
temperature \
fwd_pwr \
rev_pwr \
bias \
txfifo_recovery \
txfifo_msbs \
rem')


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
  ptt_resp = (temp & 0x40) != 0
  pa_exttr = (temp & 0x20) != 0
  pa_inttr = (temp & 0x10) != 0
  tx_on = (temp & 0x08) != 0
  cw_on = (temp & 0x04) != 0
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
    receivers,board_id,wideband_type,response_data,ext_cw_key,ptt_resp,pa_exttr,pa_inttr,tx_on,cw_on,
    adc_clip_cnt,temperature,fwd_pwr,rev_pwr,bias,txfifo_recovery,txfifo_msbs,r[0x25:])

def discover_by_port(ifaddr=None, port=1025, verbose=2):
  """Discover available HL2s on one interface/NIC for one UDP port."""
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
  sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
  sock.setblocking(0)
  if ifaddr != None: sock.bind((ifaddr,port)) 
  msg = bytes([0xEF,0xFE,0x02]+(57*[0]))
  sock.sendto(msg, ('255.255.255.255', port))
  responses = []
  while True:
    ready = select.select([sock], [], [], 1.0)
    if ready[0]:
      data, address = sock.recvfrom(60)
      if ifaddr and ifaddr == address[0]: continue
      if verbose >= 2: 
        print("Discover response from %s:%d" %(address[0], address[1]))
      r = decode(data)
      if r: responses.append((address,r))
    else:
      ## Timeout so no more units to discover
      break
  return responses

def discover(ifaddr=None, verbose=2):
  """Discover available HL2s on one interface/NIC and return their responses."""
  responses = discover_by_port(ifaddr, 1025, verbose)
  if responses != []: return responses
  ## Try port 1024 if no responses so gateware update can at least work
  if verbose >= 2: 
    print("Trying port 1024. Only gateware update will work on units without port 1025 enabled.")
  return discover_by_port(ifaddr, 1024, verbose)

def discover_all(verbose=2):
  """Discover all HL2s on all interfaces and return list of their responses."""
  # Use AF_INET because HL2 only supports IPv4 and not IPv6 
  PROTO = netifaces.AF_INET   
  # Fetch list of network interfaces, remove 'lo' if present
  ifaces = [iface for iface in netifaces.interfaces() if iface != 'lo']
  # Get (address, name) tuples for all addresses for each remaining interface
  if_addrs = [(netifaces.ifaddresses(iface), iface) for iface in ifaces]
  # Keep interfaces with IPv4 addresses, drop others
  if_addrs = [(t[0][PROTO], t[1]) for t in if_addrs if PROTO in t[0]]
  # Keep the value of the 'addr' field from interfaces that have them
  iface_addrs = [(d['addr'], t[1]) for t in if_addrs for d in t[0] \
    if 'addr' in d]
  # Keep interfaces that do not have 127.0.0.1 as an address (loopback)
  iface_addrs = [ t for t in iface_addrs if t[0] != '127.0.0.1']
  # Do discovery on all remaining interfaces that have IP addresses
  responses = []
  for ifa in iface_addrs: 
    if verbose >= 2: 
      print("\nPerforming discovery: interface %s, IP %s" % (ifa[1],ifa[0]))
    d = discover(ifaddr=ifa[0],verbose=verbose)
    if d != []:
      for r in d:
        if verbose >= 1: 
          print('Discovered radio: IP %s MAC %s GW %s #RX %d' % 
            (r[0][0],r[1].mac,r[1].gateware,r[1].receivers))
        responses.append(r)
  return responses

def discover_first(verbose=2):
  """Discover all HL2s on all interfaces and return the first HL2 found."""
  """Verbose can be >=2 (all output), 1 (only on discovery), or 0 (no output)"""
  responses = discover_all(verbose)
  if responses != []:
    return HermesLite(responses[0][0])
  else:
    return None

class HermesLite:
  # Hermes-Lite object
  def __init__(self,ip_port):
    self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    self.sock.setblocking(0)
    self.ip = ip_port[0]
    self.port = ip_port[1]
    self.wrcache = {}

  def _send(self,msg,port=None,timeout=2.0,attempts=3):
    """Low level send to HL2."""
    if port == None: port = self.port
    while attempts > 0:
      self.sock.sendto(msg, (self.ip,port))
      ready = select.select([self.sock], [], [], timeout)
      if ready[0]:
        data, ip_port = self.sock.recvfrom(60)
        if ip_port != (self.ip,port):
          print("Wrong ip_port",ip_port,self.ip,port)
          continue
        return decode(data)
      attempts -= 1
      print("Retrying send")
    return None

  def _recv(self,port=None,timeout=2.0):
    """Low level receive from HL2."""
    if port == None: port = self.port

    ready = select.select([self.sock], [], [], timeout)
    if ready[0]:
      data, ip_port = self.sock.recvfrom(60)
      if ip_port != (self.ip,port):
        print("Wrong ip_port",ip_port,self.ip,port)
        return None
      else:
        return decode(data)
    else:
      return None

  def command(self,addr,cmd,sleep=0.2,timeout=2.0,attempts=3):
    """Send command at address to HL2, cmd may be bytes or number.
      Returns a response."""
    if isinstance(cmd,int):
      cmd = struct.pack('!L',cmd)
    ## send to both units for now
    res = self._send(bytes([0xef,0xfe,0x05,0x7f,addr<<1])+cmd+bytes([0x0]*51),\
      timeout=timeout,attempts=attempts)
    if res:
      self.wrcache[addr] = cmd
    time.sleep(sleep)
    return res

  def response(self):
    """Retrieve a response without sending address and command."""
    return self._send(bytes([0xef,0xfe,0x02]+([0x0]*57)))

  def write_ad9866(self,addr,data):
    """Write to AD9866 via SPI."""
    time.sleep(0.002)
    data = data & 0x0ff
    addr = addr & 0x0ff
    cmd = bytes([0x06,addr,0x0,data])
    return self.command(0x3b,cmd)

  def enable_ad9866_2xclk(self):
    return self.write_ad9866(0x04,0x36)

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

  def read_versa5(self,addr,fullresponse=False):
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
    cmd = bytes([0x00,0x00,0x00,0x08])
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
    """Enable CL2 output at 61.44MHz"""
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

  def enable_cl1_cl2_10mhz(self):
    """Use 10MHz CL1 as input to PLL1 and then to AD9866"""
    # Multiplying 10MHz by 288 will give us the desired 2880.0MHz VCO.
    # We then need to use the output divider (18.75 * 2) to get us down
    # to the required 76.8 MHz.

    self.write_versa5(0x10,0xc0) ## Enable xtal and clock
    self.write_versa5(0x13,0x03) ## Switch to clock
    self.write_versa5(0x10,0x40) ## Enable clock input only, won't lock to master

    # Output Divider 1
    self.write_versa5(0x2d,0x01) ## Change top divider to 0x012
    self.write_versa5(0x2e,0x20)
    self.write_versa5(0x22,0x03) ## Change fractional divider to 0x3000000
    self.write_versa5(0x23,0x00)
    self.write_versa5(0x24,0x00)
    self.write_versa5(0x25,0x00)

    # PLL multiplier
    self.write_versa5(0x19,0x00) ## Change fractional multiplier to 0x000000
    self.write_versa5(0x1A,0x00)
    self.write_versa5(0x1B,0x00)
    self.write_versa5(0x18,0x00) ## Change top multiplier to 0x120. LSB first to prevent VCO > 2900MHz
    self.write_versa5(0x17,0x12)
  
  # Following Clk1 config to use 10MHz input, now config Clk2 for 10Mhz output.  
    #def enable_cl2_10mhz(self):
    """Enable CL2 output at 10MHz"""
    # Multiplying 10MHz by 288 will give us the desired 2880.0MHz VCO.
    # We then need to use the output divider (288 / 2 ==> 144, or 0x90) 
    # to get us down to the required 10.000 MHz.
    self.write_versa5(0x62,0x3b) ## Clock2 CMOS1 output, 3.3V
    self.write_versa5(0x2c,0x00) ## Disable aux output on clock 1
    self.write_versa5(0x31,0x81) ## Use divider for clock2
    self.write_versa5(0x3d,0x09) ## Change top divider to 0x090
    self.write_versa5(0x3e,0x00)
    
    # PLL multiplier
    self.write_versa5(0x32,0x00) ## Change fractional divider to 0x0000000
    self.write_versa5(0x33,0x00)
    self.write_versa5(0x34,0x00)
    self.write_versa5(0x35,0x00)
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

  def synchronize_radios(self):
    ## Enable clock output on CL2 of master
    self.command(0x39,bytes([0x00,0x00,0x00,0x0b]))
    ## Establish link from master to secondary unit
    self.command(0x39,bytes([0x00,0x00,0x09,0x00]))
    ## Reset all pipelines in both units
    self.command(0x39,bytes([0x00,0x00,0x00,0x80]))
    ## Syncronize Rx1 on both units (RX1 from secondary is in place of RX2 on master)
    self.command(0x39,bytes([0x00,0x81,0x00,0x00]))
    ## Make sure RX1 and RX2 are at the same frequency before NCO reset
    self.command(0x02,14074000)
    ## Reset the NCOs
    self.command(0x39,bytes([0x00,0x00,0x00,0x90]))

  def desynchronize_radios(self):
    ## Disable master
    self.command(0x39,bytes([0x00,0x00,0x08,0x00]))
    ## Disable clock output on CL2 of master
    self.command(0x39,bytes([0x00,0x00,0x00,0x0a]))

  def enable_txlna(self,gain=-12):
    """Set and enable the hardware managed LNA for TX"""
    gain = -12 if gain < -12 else gain
    gain = 48 if gain > 48 else gain
    gain = (gain + 12) | 0xc0
    cmd = bytes([0x00,0x00,gain,0x00])
    return self.command(0x0e,cmd)

  def disable_txlna(self,gain=-12):
    """Disable the hardware managed LNA for TX"""
    cmd = bytes([0x00,0x00,0x00,0x00])
    return self.command(0x0e,cmd)

  def set_cwhangtime(self,hangtime=10):
    """Set CW hang time 0 to 1023 ms"""
    hangtime = hangtime & 0x3ff
    return self.command(0x10,hangtime)

  def config_txbuffer(self,latency=10,ptt_hang=4):
    """Set buffer latency and ptt hang time in ms."""
    cmd = bytes([0x00,0x00,int(ptt_hang)&0x1f,int(latency)&0x7f])
    return self.command(0x17,cmd)

  def write_eeprom(self, addr, data):
    """Write values into the MCP4662 EEPROM registers"""
    ## For example, to set a fixed IP of 192.168.33.20
    ## hw.WriteEEPROM(8,192)
    ## hw.WriteEEPROM(9,168)
    ## hw.WriteEEPROM(10,33)
    ## hw.WriteEEPROM(11,20)
    ## To set the last two values of the MAC to 55:66
    ## hw.WriteEEPROM(12,55)
    ## hw.WriteEEPROM(13,66)
    ## To enable the fixed IP and alternate MAC, and favor DHCP
    ## hw.WriteEEPROM(6, 0x80 | 0x40 | 0x20)
    ## See https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol
    time.sleep(0.002)
    data = data & 0x0ff
    addr = (addr << 4) & 0x0ff
    ## i2caddr is 7 bits, no read write
    ## Bit 8 is set to indicate stop to HL2
    ## i2caddr = 0x80 | (0xd4 >> 1) ## ea
    cmd = bytes([0x06,0xac,addr,data])
    return self.command(0x3d,cmd)

  def read_eeprom(self, addr, fullresponse=False):
    """Read values from the MCP4662 EEPROM registers"""
    time.sleep(0.002)
    addr = ((addr << 4) & 0xff) | 0x0c
    cmd = bytes([0x07,0xac,addr,0x00])
    res = self.command(0x3d,cmd)
    if fullresponse:
      return res
    else:
      return (res.response_data >> 8) & 0x0ff

  def read_bias(self):
    """Read configuration setting for bias0 and bias1"""
    bias0 = self.read_eeprom(0x2)
    bias1 = self.read_eeprom(0x3)
    print("Bias0={0} Bias1={1}".format(bias0,bias1))
    return bias0,bias1

  def get_use_eeprom_ip(self):
    """Get the current use_eeprom_ip flag"""
    res = self.read_eeprom(0x6)
    return (res & 0x80) != 0

  def set_use_eeprom_ip(self):
    """Set the use_eeprom_ip flag"""
    res = self.read_eeprom(0x6)
    res = res | 0x80
    self.write_eeprom(0x6,res)

  def clear_use_eeprom_ip(self):
    """Clear the use_eeprom_ip flag"""
    res = self.read_eeprom(0x6)
    res = res & 0x7f
    self.write_eeprom(0x6,res)

  def get_use_eeprom_mac(self):
    """Get the current use_eeprom_mac flag"""
    res = self.read_eeprom(0x6)
    return (res & 0x40) != 0

  def set_use_eeprom_mac(self):
    """Set the use_eeprom_mac flag"""
    res = self.read_eeprom(0x6)
    res = res | 0x40
    self.write_eeprom(0x6,res)

  def clear_use_eeprom_mac(self):
    """Clear the use_eeprom_mac flag"""
    res = self.read_eeprom(0x6)
    res = res & 0xbf
    self.write_eeprom(0x6,res)

  def get_favor_dhcp(self):
    """Get the current favor_dhcp flag"""
    res = self.read_eeprom(0x6)
    return (res & 0x20) != 0

  def set_favor_dhcp(self):
    """Set the favor_dhcp flag"""
    res = self.read_eeprom(0x6)
    res = res | 0x20
    self.write_eeprom(0x6,res)

  def clear_favor_dhcp(self):
    """Clear the favor_dhcp flag"""
    res = self.read_eeprom(0x6)
    res = res & 0xdf
    self.write_eeprom(0x6,res)

  def get_eeprom_ip(self):
    """Get fixed IP"""
    b0 = self.read_eeprom(0x08)
    b1 = self.read_eeprom(0x09)
    b2 = self.read_eeprom(0x0a)
    b3 = self.read_eeprom(0x0b)
    eeprom_ip = "%d.%d.%d.%d" % (b0,b1,b2,b3)
    return eeprom_ip

  def set_eeprom_ip(self,ip="0.0.0.0"):
    """Set fixed IP. ip is string like '192.168.33.1'"""
    ip = ip.split('.')
    b0 = int(ip[0])
    b1 = int(ip[1])
    b2 = int(ip[2])
    b3 = int(ip[3])
    self.write_eeprom(0x08,b0)
    self.write_eeprom(0x09,b1)
    self.write_eeprom(0x0a,b2)
    self.write_eeprom(0x0b,b3)

  def get_eeprom_mac(self):
    """Read last two digits of alternate MAC"""
    b0 = self.read_eeprom(0x0c)
    b1 = self.read_eeprom(0x0d)
    eeprom_altmac = "%02x:%02x" % (b0,b1)
    return eeprom_altmac

  def set_eeprom_mac(self,mac="0:0"):
    """Set last two digits of alternate MAC. mac is hex string like 'bf:10'"""
    mac = mac.split(':')
    b0 = int(mac[0],16)
    b1 = int(mac[1],16)
    self.write_eeprom(0x0c,b0)
    self.write_eeprom(0x0d,b1)

  def update_gateware(self,filename,filename_checks=True):
    """Program gateware with .rbf file"""
    if filename_checks and filename.split(".")[1] != "rbf":
      print("ERROR: File {} must have .rbf extension.".format(filename))
      return
    if not os.path.exists(filename):
      print("ERROR: Could not open file {}.".format(filename))
      return
    resp = self.response()
    if resp == None:
      print("ERROR: No HL2 found.")
      return
    if resp.type != 2:
      print("ERROR: HL2 must not be running for gateware update. Response type was {}.".format(resp.type))
      return
    if filename_checks and "hl2b{}".format(resp.board_id) not in filename:
      print("ERROR: Running HL2 board ID of {0} does not match filename {1}".format(resp.board_id,filename))
      return
    with open(filename, "rb") as fp:
      if fp.read(36) != bytes(([0xff]*32)+[0x6a,0xf7,0xf7,0xf7]):
        print("ERROR: Unexpected file header. Make sure you are using a valid .rbf file.")
        return
      fp.seek(0)
      size = os.stat(filename).st_size
      ## Based on Quisk code by Jim N2ADR
      blocks = (size + 255) // 256
      print("Erase old program...")
      resp = self._send(bytes([0xef,0xfe,0x03,0x02]+([0x00]*56)),port=1024,timeout=10.0,attempts=1)
      if resp == None:
        print("ERROR: No response from HL2 for erase.")
        return
      if resp.type != 3:
        print("ERROR: Unexpected response type {} for erase".format(resp.type))
        return
      print("Programming.",end="",flush=True)
      cmd = bytes([0xef,0xfe,0x03,0x01,(blocks>>24)&0xff,(blocks>>16)&0xff,(blocks>>8)&0xff,blocks&0xff])
      for block in range(blocks):
        print(".",end="",flush=True)
        prog = fp.read(256)
        if block == blocks - 1: # last block may have an odd number of bytes
          prog = prog + bytearray(b"\xFF" * (256 - len(prog)))
        if len(prog) != 256:
          print ("ERROR: Read wrong number of bytes for block.", block)
          return
        resp = self._send(cmd+prog,port=1024,timeout=10.0,attempts=1)
        if resp == None:
          print("ERROR: No response from HL2 for block {}.".format(block))
          return
        if resp.type != 4:
          print("ERROR: Unspected response type {} for program.".format(resp.type))
    print("")
    print("SUCCESS: Wait for HL2 to restart.")

  def update_gateware_github(self,version='',delete=True):
    """Update the gateware given a version string. Version set to 'stable/20200529_71p3/hl2b5up_main/hl2b5up_main.rbf'
    will update to that stable version."""
    urlroot = "https://github.com/softerhardware/Hermes-Lite2/raw/master/gateware/bitfiles/"
    if version == '':
      try:
        with urllib.request.urlopen(urlroot+'stable/latest') as response:
          version = 'stable/'+str(response.read(),'utf-8','ignore')+'/hl2b5up_main/hl2b5up_main.rbf'
      except urllib.error.HTTPError:
          print("ERROR: Unable to retrieve latest information.")
          return

    u = urlroot+version
    try:
      with urllib.request.urlopen(u) as response:
        with tempfile.NamedTemporaryFile(delete=delete) as tmp_file:
            shutil.copyfileobj(response, tmp_file)
            print("Copied {0} to {1}".format(u,tmp_file.name))
            self.update_gateware(tmp_file.name,filename_checks=False)
    except urllib.error.HTTPError:
      print("ERROR: Bad URL {}.".format(u))

  def reboot(self):
    """Force reset of HL2 if not in run mode, or when exiting run mode"""
    addr = 0x3a
    cmd = bytes([0x00,0x00,0x00,0x01])
    res = self._send(bytes([0xef,0xfe,0x05,0x7f,addr<<1])+cmd+bytes([0x0]*51),attempts=1)
    return res

  def write_ioboard(self,addr,data):
    """Write to N2ADR IO board Pico via i2c."""
    time.sleep(0.002)
    data = data & 0x0ff
    addr = addr & 0x0ff
    cmd = bytes([0x06,0x1d,addr,data])
    res = self.command(0x3d,cmd)
    #print ("0x%08X" % res.response_data)
    if res and res.response_data & 0xFFFFFF == 0x1d << 16 | addr << 8 | data:
      return "Set address %d to %d" % (addr, data)
    return "Failure at address %d in write_ioboard()" % addr

  def read_ioboard(self,addr,fullresponse=False):
    """Read from N2ADR IO board Pico via i2c."""
    time.sleep(0.002)
    addr = addr & 0xff
    cmd = bytes([0x07,0x1d,addr,0x00])
    res = self.command(0x3d,cmd)
    #print ("0x%08X" % res.response_data)
    if fullresponse:
      return res
    elif res:
      r = res.response_data
      return (r >> 24 & 0xFF, r >> 16 & 0xFF, r >> 8 & 0xFF, r & 0xFF)

  def read_ioboard_rom(self,fullresponse=False):
    """Read from N2ADR IO board ROM via i2c."""
    time.sleep(0.002)
    addr = 0x00
    cmd = bytes([0x07,0x41,addr,0x00])
    res = self.command(0x3d,cmd)
    #print ("0x%08X" % res.response_data)
    if fullresponse:
      return res
    elif res:
      return res.response_data & 0xff

  def set_ioboard_freq(self, hertz):
    """Send the frequency in hertz to the IO board"""
    ret = self.write_ioboard(0, hertz >> 32 & 0xFF)
    if ret[0:8] == "Failure ":
      return ret
    ret = self.write_ioboard(1, hertz >> 24 & 0xFF)
    if ret[0:8] == "Failure ":
      return ret
    ret = self.write_ioboard(2, hertz >> 16 & 0xFF)
    if ret[0:8] == "Failure ":
      return ret
    ret = self.write_ioboard(3, hertz >>  8 & 0xFF)
    if ret[0:8] == "Failure ":
      return ret
    ret = self.write_ioboard(4, hertz & 0xFF)
    if ret[0:8] == "Failure ":
      return ret
    return hertz


if __name__ == "__main__":
  hl = discover_first()
  ##hl = HermesLite( ("10.10.0.180",1025) ) # Connect to specific IP
  ##print("Configuring Clk1 and Clk2 for 10Mhz")
  ##hl.enable_cl1_cl2_10mhz()
  ##print("Configuration of clocks completed")
