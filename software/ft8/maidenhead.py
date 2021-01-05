import numpy as np

## Latitude, Longitude precomputed as radians
## Set for your QTH
HOME=(np.radians(45.31316),np.radians(-122.79877))


## Borrowed and modified from https://github.com/space-physics/maidenhead
def maiden2latlog(m):
  m = m.strip().upper()
  N = len(m)
  if not 8 >= N >= 2 and N % 2 == 0:
    raise ValueError("Maidenhead locator requires 2-8 characters, even number of characters")

  Oa = ord("A")
  lon = -180.0
  lat = -90.0
  lon += (ord(m[0]) - Oa) * 20
  lat += (ord(m[1]) - Oa) * 10
  if N >= 4:
    lon += int(m[2]) * 2
    lat += int(m[3]) * 1
  if N >= 6:
    lon += (ord(m[4]) - Oa) * 5.0 / 60
    lat += (ord(m[5]) - Oa) * 2.5 / 60
  if N >= 8:
    lon += int(m[6]) * 5.0 / 600
    lat += int(m[7]) * 2.5 / 600

  ## Center in grid
  if N == 4:
    lon += 1
    lat += 0.5
  elif N == 6:
    lon += 5.0/120
    lat += 2.5/120
  elif N == 8:
    lon += 5.0/1200
    lat += 2.5/1200

  return lat,lon


## Borrowed and modified from https://github.com/9V1KG/maidenhead
## tuple of lat,lon
def distanceheading(target,home=HOME):

  lat2 = np.radians(target[0])
  lon2 = np.radians(target[1])
  dlon = lon2-home[1]

  if home[0] == lat2 and home[1] == lon2:
    return 0.,0

  dist = np.sin(home[0]) * np.sin(lat2) + np.cos(home[0]) * np.cos(lat2) * np.cos(dlon)
  dist = round(np.degrees(np.arccos(dist)) * 60 * 1.853)
  x_1 = np.sin(dlon) * np.cos(lat2)
  x_2 = np.cos(home[0]) * np.sin(lat2) - (np.sin(home[0]) * np.cos(lat2) * np.cos(dlon))
  azimuth = np.arctan2(x_1, x_2)
  azimuth = np.degrees(azimuth)
  azimuth = round((azimuth + 360) % 360)
  return dist, azimuth ## dist is in km

def maiden2distanceheading(target,home=HOME):
  ll = maiden2latlog(target)
  return distanceheading(ll,home)