CREATE TABLE IF NOT EXISTS satellites(
  name TEXT NOT NULL,
  freq_Mhz REAL NOT NULL,
  gain INT NOT NULL,
  signal_type TEXT,
  device INT DEFAULT 0,
  bias_tee TEXT DEFAULT "OFF",
  sat_min_elev INT NOT NULL);
CREATE TABLE IF NOT EXISTS transits(
  sat_name TEXT NOT NULL, 
  pass_start INT NOT NULL, 
  pass_end INT NOT NULL, 
  max_elev INT NOT NULL, 
  pass_start_azimuth, 
  direction TEXT NOT NULL, 
  azimuth_at_max INT NOT NULL,
  device INT DEFAULT 0,
  signal_type TEXT,
  status TEXT DEFAULT "initial" NOT NULL);
.exit
