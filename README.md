# SatTrack

While raspberry-noaa(-v2) was working great for me I wanted to streamline things and take a different approach to configuration (i.e. use the database more) such that I could capture any VHF or UHF satellite transmissions my RTL-SDR dongle and antenna(s) could handle, and decode them as weather images, SSTV, CW, etc.

I also wanted to do my own thing with the web interface.

Standing on the shoulders of giants, this project is highly indebted to the following...

* SQLite3 - [SQLite](https://www.sqlite.org/index.html)
* Kenny Kerr's C++ wrappers for SQLite [Pluralsight course "SQLite with Modern C++"](https://www.pluralsight.com/courses/sqlite-modern-cplusplus)
* C++ HTTP library - [cpp-httplib](https://github.com/yhirose/cpp-httplib)
* Updated project for NOAA & Meteor weather satellite image captures [raspberry-noaa-v2](https://github.com/jekhokie/raspberry-noaa-v2)
* Original project for NOAA & Meteor weather satellite image and ISS SSTV captures - [raspberry-noaa](https://github.com/reynico/raspberry-noaa)
* SSTV Decoder #1 - [pd120_decoder](https://github.com/reynico/pd120_decoder)
* SSTV Decoder #2 - [sstv](https://github.com/colaclanth/sstv)
* Turn Realtek RTL2832 USB dongle into an SDR receiver - [RTL-SDR](https://gitea.osmocom.org/sdr/rtl-sdr)
* Bias Tee via USB - [RTL-SDR-Blog](https://github.com/rtlsdrblog/rtl-sdr-blog)

Installation:
1. start with a clean Raspian BOOKWORM image
2. cd ~
3. sudo apt install git
4. git clone https://github.com/sgarriga/SatTrack.git
5. cd SatTrack/config
6. Update file wxtoimgrc with your latitude and longitude
7. If you want to run on a port other than 8080, replace that value in file SatTrack.service
8. ./set-up.sh
9. If advised to do so, manually update /etc/ImageMagick-6/policy.xml
10. cd ../src
11. make
12. cd ..
13. ./schedule_24h.sh
14. sudo reboot
15. point your browser at http://{your Pi's IP}:{port in SatTrack.service}
16. add some satellites to track
17. ./schedule_24h.sh

