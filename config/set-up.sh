#!/bin/bash
#
# Purpose: Determine [and fix] missing prerequisites
#   Input parametera:
#     none
#
# Example:
# . ./set-up.sh

#set -e
CONFIG=$PWD

### Install required packages
echo "Installing required APT packages..."

sudo apt update -yq
sudo apt install -yq python3-setuptools \
                     ntp \
                     cmake \
                     git \
                     git-core \
                     build-essential \
                     libusb-1.0-0-dev \
                     sox libasound2 libasound2-dev \
                     at \
                     bc \
                     libncurses5-dev libncursesw5-dev \
                     libatlas-base-dev \
                     python3-pip python3-scipy \
                     imagemagick \
                     fonts-freefont-otf \
                     libxft-dev \
                     libxft2 \
                     libfftw3-dev \
                     libjpeg62-turbo-dev \
                     socat \
                     sqlite3 \
                     libsqlite3-dev

echo "APT packages installed"

### Blacklist DVB modules
if [ -e /etc/modprobe.d/rtlsdr.conf ]; then
    echo "DVB modules were already blacklisted"
else
    echo "blacklist dvb_usb_rtl28xxu" | sudo tee -a /etc/modprobe.d/rtlsdr.conf
    echo "blacklist rtl2832" | sudo tee -a /etc/modprobe.d/rtlsdr.conf
    echo "blacklist rtl2830" | sudo tee -a /etc/modprobe.d/rtlsdr.conf
    echo "DVB modules are blacklisted now"
fi

if [ -e /usr/lib/libasound.so ]; then
    echo "libasound link is present"
else
    sudo ln -s /usr/lib/aarch64-linux-gnu/libasound.so.2 /usr/lib/libasound.so
    echo "created libasound link"
fi

if [ -e /usr/local/bin/predict ]; then
    echo "Predict already installed"
else
    cd $HOME
    wget https://www.qsl.net/kd2bd/predict-2.3.1.tar.gz
    gunzip predict-2.3.1.tar.gz
    tar xvf predict-2.3.1.tar
    cd predict-2.3.1
    sudo ./configure
    rm -f predict-2.3.1.tar.gz  predict-2.3.1.tar
fi

### Install RTL-SDR with USB Bias Tee support
if [ -e /usr/local/bin/rtl_biast ]; then
    echo 
else
    sudo apt purge ^librtlsdr
    sudo rm -rvf /usr/lib/librtlsdr* /usr/include/rtl-sdr* /usr/local/lib/librtlsdr* /usr/local/include/rtl-sdr* /usr/local/include/rtl_* /usr/local/bin/rtl_*
    cd $HOME
    git clone  https://github.com/rtlsdrblog/rtl-sdr-blog.git
    cd rtl-sdr-blog/
    if [ ! -d build ]; then
      mkdir build
    fi
    cd build
    cmake ../ -DINSTALL_UDEV_RULES=ON
    make
    sudo make install
    sudo cp ../rtl-sdr.rules /etc/udev/rules.d/
    sudo ldconfig
    echo "rtl-sdr install done"
fi

### Install WxToIMG
if [ -e /usr/local/bin/xwxtoimg ]; then
    echo "WxToIMG was already installed"
else
    echo "Installing WxToIMG..."
    cd $HOME
    mkdir wxtoimg
    cd wxtoimg
    wget https://wxtoimgrestored.xyz/beta/wxtoimg-armhf-2.11.2-beta.deb
    sudo dpkg -i wxtoimg-armhf-2.11.2-beta.deb
    echo "WxToIMG installed"
fi

### Install meteor_demod
if [ -e /usr/local/bin/meteor_demod ]; then
    echo "meteor_demod was already installed"
else
    echo "Installing meteor_demod..."
    cd $HOME
    git clone https://github.com/dbdexter-dev/meteor_demod.git
    cd meteor_demod
    if [ ! -d build ]; then
      mkdir build
    fi
    cd build
    cmake ..
    make
    sudo make install
    echo "meteor_demod installed"
fi

### Install medet_arm
if [ -e /usr/local/bin/medet_arm ]; then
    echo "medet_arm was already installed"
else
    echo "Installing medet_arm..."
    cd $HOME
    mkdir metdet_arm
    cd metdet_arm
    wget https://orbides.org/etc/medet/medet_190825_arm.tar.gz
    gunzip medet_190825_arm.tar.gz
    tar xvf medet_190825_arm.tar
    sudo cp medet_arm /usr/local/bin/
    sudo chmod a+x /usr/local/bin/medet_arm
    echo "medet_arm installed"
fi

if [ -d "$HOME/cpp-httplib" ]; then
    echo "cpp-httplib already installed"
else
    echo "Installing cpp-httplib..."
    cd $HOME
    git clone https://github.com/yhirose/cpp-httplib.git
    echo "cpp-httplib installed"
fi

if [ -e  "/usr/local/bin/slowrx-cli" ]; then
    echo "SSTV decoder already installed"
else
    echo "Installing SSTV decoder..."
    cd $HOME
    git clone https://github.com/sgarriga/slowrx-cli
    cd slowrx-cli
    make
    sudo cp slowrx-cli /usr/local/bin/
    echo "SSTV decoder (slowrx-cli() installed"
fi

echo "Installs done!"

# make sure we are where we should be
cd $CONFIG

if [ -e ../sat-track.db ]; then
    echo DB exists
else
    echo Creating DB
    sqlite3 ../sat-track.db < create_tables.sql
fi

if [ -e ~/.wxtoimglic ]; then
    echo WxToImg configured
else
    cp ./wxtoimglic ~/.wxtoimglic 
    cp ./wxtoimgrc  ~/.wxtoimgrc
fi

# set up our schedule
crontab -l > crontab.backup
if grep -q "SatTrack" crontab.backup; then
    echo SatNav entries exist in crontab
else
    echo Adding SatNav entries to crontab
    cat crontab crontab.backup | crontab -
fi

# Create systemd service for HTTP server
if [ -e /lib/systemd/system/SatTrack.service ]; then
    echo SatTrack.service already present
else
    echo Installing SatTrack.service
    sudo cp SatTrack.service /lib/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable SatTrack.service
fi

## Check for <policy domain="path" rights="none" pattern="@*" />
## in file /etc/ImageMagick-6/policy.xml
#
policy=$( cat /etc/ImageMagick-6/policy.xml | sed 's/<!--/\x0<!--/g;s/-->/-->\x0/g' | grep -zv '^<!--' | tr -d '\0' | grep 'rights="none"' | grep 'pattern="@\*"' )
if [ -z "${policy}" ]; then
    echo /etc/ImageMagick-6/policy.xml appears OK
else
    echo "/etc/ImageMagick-6/policy.xml needs the 'pattern=\"@\*\" line commenting out"
fi

