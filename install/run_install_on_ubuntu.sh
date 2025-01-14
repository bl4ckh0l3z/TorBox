#!/bin/bash

# This file is a part of TorBox, an easy to use anonymizing router based on Raspberry Pi.
# Copyright (C) 2021 Patrick Truffer
# Contact: anonym@torbox.ch
# Website: https://www.torbox.ch
# Github:  https://github.com/radio24/TorBox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it is useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# DESCRIPTION
# This script installs the newest version of TorBox on a clean, running
# Ubuntu 20.04 LTS (32/64bit; https://ubuntu.com/download/raspberry-pi).
#
# SYNTAX
# ./run_install_on_ubuntu.sh
#
# IMPORTANT
# Start it as normal user (usually as ubuntu)!
# Dont run it as root (no sudo)!
# If Ubuntu 20.04 is freshly installed, you have to wait one or two minutes
# until you can log in with ubuntu / ubuntu
#
##########################################################

# Table of contents for this script:
#  1. Checking for Internet connection
#  2. Updating the system
#  3. Adding the Tor repository to the source list.
#  4. Installing all necessary packages
#  5. Compile and install the newest version of Tor
#  6. Configuring Tor with the pluggable transports
#  7. Re-checking Internet connectivity
#  8. Downloading and installing the latest version of TorBox
#  9. Installing all configuration files
# 10. Disabling Bluetooth
# 12. Configure the system services
# 13. Installing additional network drivers
# 14. Adding and implementing the user torbox
# 15. Finishing, cleaning and booting

##########################################################

##### SET VARIABLES ######
#
# SIZE OF THE MENU
#
# How many items do you have in the main menu?
NO_ITEMS=9
#
# How many lines are only for decoration and spaces?
NO_SPACER=0
#
#Set the the variables for the menu
MENU_WIDTH=80
MENU_WIDTH_REDUX=60
MENU_HEIGHT_25=25
MENU_HEIGHT_20=20
MENU_HEIGHT_15=15
MENU_HEIGHT=$((8+NO_ITEMS+NO_SPACER))
MENU_LIST_HEIGHT=$((NO_ITEMS+$NO_SPACER))

#Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

#Connectivity check
CHECK_URL1="http://ubuntu.com"
CHECK_URL2="https://google.com"

# Avoid cheap censorship mechanism
RESOLVCONF="\n# Added by TorBox install script\nDNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4\n"

#Other variables
RUNFILE="torbox/run/torbox.run"
CHECK_HD1=$(grep -q --text 'Raspberry Pi' /proc/device-tree/model)
CHECK_HD2=$(grep -q "Raspberry Pi" /proc/cpuinfo)

##############################
######## FUNCTIONS ###########

# This function installs the packages in a controlled way, so that the correct
# installation can be checked.
# Syntax install_network_drivers <packagenames>
check_install_packages()
{
  packagenames=$1
  for packagename in $packagenames; do
    clear
    echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"
    echo ""
    echo -e "${RED}[+]         Installing ${WHITE}$packagename${NOCOLOR}"
    sudo apt-get -y install $packagename
#    echo ""
#    read -n 1 -s -r -p "Press any key to continue"
  done
}


###### DISPLAY THE INTRO ######
clear
# Only Ubuntu - Sets the background of TorBox menu to dark blue
sudo rm /etc/alternatives/newt-palette; sudo ln -s /etc/newt/palette.original /etc/alternatives/newt-palette


if (whiptail --title "TorBox Installation on Ubuntu" --no-button "INSTALL" --yes-button "STOP!" --yesno "            WELCOME TO THE INSTALLATION OF TORBOX ON UBUNTU\n\nPlease make sure that you started this script as \"./run_install_on_ubuntu\" (without sudo !!) in your home directory.\n\nThis installation runs almost without user interaction, IT WILL CHANGE/DELETE THE CURRENT CONFIGURATION.\n\nDuring the installation, we are going to set up the user \"torbox\" with the default password \"CHANGE-IT\". This user name and the password will be used for logging into your TorBox and to administering it. Please, change the default passwords as soon as possible (the associated menu entries are placed in the configuration sub-menu).\n\nIMPORTANT: Internet connectivity is necessary for the installation.\n\nIn case of any problems, contact us on https://www.torbox.ch." $MENU_HEIGHT_25 $MENU_WIDTH); then
	clear
	exit
fi


# 1. Checking for Internet connection
clear
echo -e "${RED}[+] Step 1: Do we have Internet?${NOCOLOR}"
echo -e "${RED}[+]         Nevertheless, first, let's add some open nameservers!${NOCOLOR}"
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
(sudo printf "$RESOLVCONF" | sudo tee /etc/systemd/resolved.conf) 2>&1
sudo systemctl restart systemd-resolved
wget -q --spider $CHECK_URL1
OCHECK=$?
echo ""
if [ $OCHECK -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have Internet! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!]        Hmmm, no we don't have Internet... :-(${NOCOLOR}"
  echo -e "${RED}[+]         We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo ""
  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
  wget -q --spider $CHECK_URL2
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${WHITE}[!]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    (sudo dhclient -r) 2>&1
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo ""
    echo -e "${RED}[+]         Trying again...${NOCOLOR}"
    wget -q --spider $CHECK_URL1
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+]         Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
      exit 1
    fi
  fi
fi

# 2. Updating the system
sleep 10
clear
echo -e "${RED}[+] Step 2a: Remove Ubuntu's unattended update feature (this will take about 30 seconds)...${NOCOLOR}"
(sudo killall unattended-upgr) 2> /dev/null
sleep 15
echo -e "${RED}[+]          Please wait...${NOCOLOR}"
(sudo killall unattended-upgr) 2> /dev/null
sleep 15
sudo apt-get -y purge unattended-upgrades
sudo dpkg --configure -a
echo ""iptables

echo -e "${RED}[+] Step 2b: Remove Ubuntu's cloud-init...${NOCOLOR}"
sudo apt-get -y purge cloud-init
sudo rm -Rf /etc/cloud
echo ""
echo -e "${RED}[+] Step 2c: Updating the system...${NOCOLOR}"
sudo apt-get -y update
sudo apt-get -y dist-upgrade
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove

# 3. Adding the Tor repository to the source list.
sleep 10
clear
echo -e "${RED}[+] Step 3: Adding the Tor repository to the source list....${NOCOLOR}"
echo ""
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

if ! grep "torproject" /etc/apt/sources.list ; then
  sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
  if hostnamectl | grep -q "Ubuntu 20.10" ; then
    sudo printf "\n# Added by TorBox\ndeb-src https://deb.torproject.org/torproject.org groovy main\n" | sudo tee -a /etc/apt/sources.list
  else
    sudo printf "\n# Added by TorBox\ndeb-src https://deb.torproject.org/torproject.org buster main\n" | sudo tee -a /etc/apt/sources.list
  fi
fi
sudo curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | sudo apt-key add -
sudo apt-get -y update

# 4. Installing all necessary packages
sleep 10
clear
echo -e "${RED}[+] Step 4: Installing all necessary packages....${NOCOLOR}"

# For some unknow reasons, the command bellow makes some headaches under Ubuntu 20.10
#sudo apt-get -y install hostapd isc-dhcp-server obfs4proxy usbmuxd dnsmasq dnsutils tcpdump iftop vnstat links2 debian-goodies apt-transport-https dirmngr python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen nyx net-tools ifupdown unzip equivs git openvpn ppp tor-geoipdb

check_install_packages "hostapd isc-dhcp-server obfs4proxy usbmuxd dnsmasq dnsutils tcpdump iftop vnstat links2 debian-goodies apt-transport-https dirmngr python3-pip python3-pil imagemagick tesseract-ocr ntpdate screen nyx net-tools ifupdown unzip equivs git openvpn ppp tor-geoipdb"

#Install wiringpi
cd ~
git clone https://github.com/WiringPi/WiringPi.git
cd WiringPi
sudo ./build
cd ~
sudo rm -r WiringPi

# Additional installations for Python
sudo pip3 install pytesseract
sudo pip3 install mechanize
sudo pip3 install urwid

# Additional installation for GO
cd ~
sudo rm -rf /usr/local/go

printf "\n# Added by TorBox\nexport PATH=$PATH:/usr/local/go/bin\n" |  tee -a .profile
export PATH=$PATH:/usr/local/go/bin

# Have to be tested
if uname -r | grep -q "arm64"; then
  wget https://golang.org/dl/go1.16.3.linux-arm64.tar.gz
  sudo tar -C /usr/local -xzvf go1.16.3.linux-arm64.tar.gz
else
  wget https://golang.org/dl/go1.16.3.linux-armv6l.tar.gz
  sudo tar -C /usr/local -xzvf go1.16.3.linux-armv6l.tar.gz
fi

# 5. Compile and install the newest version of Tor
sleep 10
clear
echo -e "${RED}[+] Step 5: Compile and install the newest version of Tor....${NOCOLOR}"
mkdir ~/debian-packages; cd ~/debian-packages
apt source tor
# IMPORTANT: build-essential is also necessary for the installation of network driver further below
sudo apt-get -y install build-essential fakeroot devscripts
# sudo apt-get -y install tor deb.torproject.org-keyring
# sudo apt-get -y upgrade tor deb.torproject.org-keyring
sudo apt-get -y build-dep tor deb.torproject.org-keyring
cd tor-*
sudo debuild -rfakeroot -uc -us
cd ..
sudo dpkg -i tor_*.deb
cd
sudo rm -r ~/debian-packages

# 6. Configuring Tor with the pluggable transports
sleep 10
clear
echo -e "${RED}[+] Step 6: Configuring Tor with the pluggable transports....${NOCOLOR}"
sudo cp /usr/share/tor/geoip* /usr/bin
sudo chmod a+x /usr/bin/geoip*
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@default.service
sudo sed -i "s/^NoNewPrivileges=yes/NoNewPrivileges=no/g" /lib/systemd/system/tor@.service

# Additional installation for Snowflake
cd ~
git clone https://git.torproject.org/pluggable-transports/snowflake.git
export GO111MODULE="on"
cd ~/snowflake/proxy
go get
go build
sudo cp proxy /usr/bin/snowflake-proxy

cd ~/snowflake/client
go get
go build
sudo cp client /usr/bin/snowflake-client

cd ~
sudo rm -rf snowflake
sudo rm -rf go*

# 7. Again checking connectivity
sleep 10
clear
echo -e "${RED}[+] Step 7: Re-checking Internet connectivity...${NOCOLOR}"
wget -q --spider $CHECK_URL1
if [ $? -eq 0 ]; then
  echo -e "${RED}[+]         Yes, we have still Internet connectivity! :-)${NOCOLOR}"
else
  echo -e "${WHITE}[!]        Hmmm, no we don't have Internet... :-(${NOCOLOR}"
  echo -e "${RED}[+]         We will check again in about 30 seconds...${NOCOLOR}"
  sleep 30
  echo -e "${RED}[+]         Trying again...${NOCOLOR}"
  wget -q --spider $CHECK_URL2
  if [ $? -eq 0 ]; then
    echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
  else
    echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
    echo -e "${RED}[+]         We will try to catch a dynamic IP adress and check again in about 30 seconds...${NOCOLOR}"
    sudo dhclient -r
    sleep 5
    sudo dhclient &>/dev/null &
    sleep 30
    echo -e "${RED}[+]         Trying again...${NOCOLOR}"
    wget -q --spider $CHECK_URL1
    if [ $? -eq 0 ]; then
      echo -e "${RED}[+]         Yes, now, we have an Internet connection! :-)${NOCOLOR}"
    else
      echo -e "${RED}[+]         Hmmm, still no Internet connection... :-(${NOCOLOR}"
      echo -e "${RED}[+]         Let's add some open nameservers and try again...${NOCOLOR}"
      sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
      (sudo printf "$RESOLVCONF" | sudo tee /etc/systemd/resolved.conf) 2>&1
      sudo systemctl restart systemd-resolved
      sleep 15
      echo ""
      echo -e "${RED}[+]          Dumdidum...${NOCOLOR}"
      sleep 15
      echo -e "${RED}[+]          Trying again...${NOCOLOR}"
      wget -q --spider $CHECK_URL1
      if [ $? -eq 0 ]; then
        echo -e "${RED}[+]          Yes, now, we have an Internet connection! :-)${NOCOLOR}"
      else
        echo -e "${RED}[+]          Hmmm, still no Internet connection... :-(${NOCOLOR}"
        echo -e "${RED}[+]          Internet connection is mandatory. We cannot continue - giving up!${NOCOLOR}"
        exit 1
      fi
    fi
  fi
fi

# 8. Downloading and installing the latest version of TorBox
sleep 10
clear
echo -e "${RED}[+] Step 8: Downloading and installing the latest version of TorBox...${NOCOLOR}"
cd
echo -e "${RED}[+]         Downloading TorBox menu from GitHub...${NOCOLOR}"
wget https://github.com/radio24/TorBox/archive/refs/heads/master.zip
if [ -e master.zip ]; then
  echo -e "${RED}[+]       Unpacking TorBox menu...${NOCOLOR}"
  unzip master.zip
  echo ""
  echo -e "${RED}[+]       Removing the old one...${NOCOLOR}"
  (rm -r torbox) 2> /dev/null
  echo -e "${RED}[+]       Moving the new one...${NOCOLOR}"
  mv TorBox-master torbox
  echo -e "${RED}[+]       Cleaning up...${NOCOLOR}"
  (rm -r master.zip) 2> /dev/null
  echo ""
else
  echo -e "${RED} ${NOCOLOR}"
  echo -e "${WHITE}[!]      Downloading TorBox menu from GitHub failed !!${NOCOLOR}"
  echo -e "${WHITE}[!]      I can't update TorBox menu !!${NOCOLOR}"
  echo -e "${WHITE}[!]      You may try it later or manually !!${NOCOLOR}"
  sleep 2
  exit 1
fi

# 9. Installing all configuration files
sleep 10
clear
cd torbox
echo -e "${RED}[+] Step 9: Installing all configuration files....${NOCOLOR}"
echo ""
(sudo cp /etc/default/hostapd /etc/default/hostapd.bak) 2> /dev/null
sudo cp etc/default/hostapd /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/hostapd -- backup done"
(sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak) 2> /dev/null
sudo cp etc/default/isc-dhcp-server /etc/default/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/default/isc-dhcp-server -- backup done"
(sudo cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.bak) 2> /dev/null
sudo cp etc/dhcp/dhclient.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhclient.conf -- backup done"
(sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak) 2> /dev/null
sudo cp etc/dhcp/dhcpd.conf /etc/dhcp/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/dhcp/dhcpd.conf -- backup done"
(sudo cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak) 2> /dev/null
sudo cp etc/hostapd/hostapd.conf /etc/hostapd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/hostapd/hostapd.conf -- backup done"
(sudo cp /etc/iptables.ipv4.nat /etc/iptables.ipv4.nat.bak) 2> /dev/null
sudo cp etc/iptables.ipv4.nat /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/iptables.ipv4.nat -- backup done"
sudo mkdir /etc/update-motd.d/bak
(sudo mv /etc/update-motd.d/* /etc/update-motd.d/bak/) 2> /dev/null
sudo rm /etc/legal
# Comment out with sed
sudo sed -ri "s/^session[[:space:]]+optional[[:space:]]+pam_motd\.so[[:space:]]+motd=\/run\/motd\.dynamic$/#\0/" /etc/pam.d/login
sudo sed -ri "s/^session[[:space:]]+optional[[:space:]]+pam_motd\.so[[:space:]]+motd=\/run\/motd\.dynamic$/#\0/" /etc/pam.d/sshd
echo -e "${RED}[+]${NOCOLOR}         Disabled Ubuntu's update-motd feature -- backup done"
(sudo cp /etc/motd /etc/motd.bak) 2> /dev/null
sudo cp etc/motd /etc/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/motd -- backup done"
(sudo cp /etc/network/interfaces /etc/network/interfaces.bak) 2> /dev/null
sudo cp etc/network/interfaces /etc/network/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/network/interfaces -- backup done"
# See also here: https://www.linuxbabe.com/linux-server/how-to-enable-etcrc-local-with-systemd
sudo cp etc/systemd/system/rc-local.service /etc/systemd/system/
(sudo cp /etc/rc.local /etc/rc.local.bak) 2> /dev/null
sudo cp etc/rc.local.ubuntu /etc/rc.local
sudo chmod u+x /etc/rc.local
# We will enable rc-local further below
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/rc.local -- backup done"
# Unlike the Raspberry Pi OS, Ubuntu uses systemd-resolved to resolve DNS queries (see also further below).
# To work correctly in a captive portal environement, we have to set the following options in /etc/systemd/resolved.conf:
# LLMNR=yes / MulticastDNS=yes / Chache=no
(sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak) 2> /dev/null
sudo cp etc/systemd/resolved.conf /etc/systemd/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/systemd/resolved.conf -- backup done"
if grep -q "#net.ipv4.ip_forward=1" /etc/sysctl.conf ; then
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
  sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  echo -e "${RED}[+]${NOCOLOR}         Changed /etc/sysctl.conf -- backup done"
fi
(sudo cp /etc/tor/torrc /etc/tor/torrc.bak) 2> /dev/null
sudo cp etc/tor/torrc /etc/tor/
echo -e "${RED}[+]${NOCOLOR}         Copied /etc/tor/torrc -- backup done"
echo -e "${RED}[+]${NOCOLOR}         Activating IP forwarding"
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo -e "${RED}[+]${NOCOLOR}         Changing .profile"
cd
sudo printf "\n# Added by TorBox\ncd torbox\n./menu\n" | sudo tee -a .profile

# 10. Disabling Bluetooth
sleep 10
clear
echo -e "${RED}[+] Step 10: Because of security considerations, we disable Bluetooth functionality${NOCOLOR}"
if ! grep "# Added by TorBox" /boot/firmware/config.txt ; then
  sudo printf "\n# Added by TorBox\ndtoverlay=disable-bt\n." | sudo tee -a /boot/firmware/config.txt
fi

# 11. Configure the system services
sleep 10
clear
echo -e "${RED}[+] Step 11: Configure the system services...${NOCOLOR}"
echo ""

# Under Ubuntu systemd-resolved acts as local DNS server. However, clients can not use it, because systemd-resolved is listening
# on 127.0.0.53:53. This is where dnsmasq comes into play which generally responds to all port 53 requests and then resolves
# them over 127.0.0.53:53. This is what we need to get to the login page at captive portals.
# CLIENT --> DNSMASQ --> resolve.conf --> systemd-resolver --> ext DNS address
# However, this approach only works, if the following options are set in /etc/systemd/resolved.conf: LLMNR=yes / MulticastDNS=yes / Chache=no
# and bind-interfaces in /etc/dnsmasq.conf
#
# Important commands for systemd-resolve:
# sudo systemctl restart systemd-resolve
# sudo systemd-resolve --statistic / --status / --flush-cashes

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd
sudo systemctl unmask isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl start isc-dhcp-server
sudo systemctl unmask tor
sudo systemctl enable tor
sudo systemctl start tor
sudo systemctl unmask ssh
sudo systemctl enable ssh
sudo systemctl start ssh
# sudo systemctl disable dhcpcd - not installed on Ubuntu
sudo systemctl restart systemd-resolved
# We can only start dnsmasq together with systemd-resolve, if we activate "bind-interface" in /etc/dnsmasq.conf
# --> https://unix.stackexchange.com/questions/304050/how-to-avoid-conflicts-between-dnsmasq-and-systemd-resolved
# However, we don't want to start dnsmasq automatically after booting the system
sudo sed -i "s/^#bind-interfaces/bind-interfaces/g" /etc/dnsmasq.conf
sudo systemctl disable dnsmasq
sudo systemctl unmask rc-local
sudo systemctl enable rc-local
echo ""
echo -e "${RED}[+]          Stop logging, now..${NOCOLOR}"
sudo systemctl stop rsyslog
sudo systemctl disable rsyslog
sudo systemctl daemon-reload
echo""

# 12. Installing additional network drivers
sleep 10
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "

# Update kernel headers - important: this has to be done every time after upgrading the kernel
echo -e "${RED}[+] Installing additional software... ${NOCOLOR}"
sudo apt-get install -y linux-headers-$(uname -r)
# firmware-realtek is missing on ubuntu, but it should work without it
sudo apt-get install -y dkms libelf-dev build-essential
cd ~
sleep 2

# Installing the RTL8188EU
# Disabled because it should be already supported by the kernel ➔ https://wiki.ubuntuusers.de/WLAN/Karten/Realtek/
# clear
# echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
# echo -e " "
# echo -e "${RED}[+] Installing the Realtek RTL8188EU Wireless Network Driver ${NOCOLOR}"
# cd ~
# git clone https://github.com/lwfinger/rtl8188eu.git
# cd rtl8188eu
# make all
# sudo make install
# cd ~
# sudo rm -r rtl8188eu
# sleep 2

# Installing the RTL8188FU
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8188FU Wireless Network Driver ${NOCOLOR}"
sudo ln -s /lib/modules/$(uname -r)/build/arch/arm /lib/modules/$(uname -r)/build/arch/armv7l
git clone -b arm https://github.com/kelebek333/rtl8188fu rtl8188fu-arm
sudo dkms add ./rtl8188fu-arm
sudo dkms build rtl8188fu/1.0
sudo dkms install rtl8188fu/1.0
sudo cp ./rtl8188fu/firmware/rtl8188fufw.bin /lib/firmware/rtlwifi/
sudo rm -r rtl8188fu
sleep 2

# Installing the RTL8192EU
# Disabled because it should be already supported by the kernel ➔ https://wiki.ubuntuusers.de/WLAN/Karten/Realtek/
# clear
# echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
# echo -e " "
# echo -e "${RED}[+] Installing the Realtek RTL8192EU Wireless Network Driver ${NOCOLOR}"
# git clone https://github.com/clnhub/rtl8192eu-linux.git
# cd rtl8192eu-linux
# sudo dkms add .
# sudo dkms install rtl8192eu/1.0
# cd ~
# sudo rm -r rtl8192eu-linux
# sleep 2

# Installing the RTL8812AU
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8812AU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8812au.git
cd 8812au
cp ~/torbox/install/Network/install-rtl8812au.sh .
sudo chmod a+x install-rtl8812au.sh
if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
sudo ./install-rtl8812au.sh
cd ~
sudo rm -r 8812au
sleep 2

# Installing the RTL8814AU
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8814AU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8814au.git
cd 8814au
cp ~/torbox/install/Network/install-rtl8814au.sh .
sudo chmod a+x install-rtl8814au.sh
if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
sudo ./install-rtl8814au.sh
cd ~
sudo rm -r 8814au
sleep 2

# Installing the RTL8821AU
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8821AU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8821au.git
cd 8821au
cp ~/torbox/install/Network/install-rtl8821au.sh .
sudo chmod a+x install-rtl8821au.sh
if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
sudo ./install-rtl8821au.sh
cd ~
sudo rm -r 8821au
sleep 2

# Installing the RTL8821CU
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL8821CU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/8821cu.git
cd 8821cu
cp ~/torbox/install/Network/install-rtl8821cu.sh .
sudo chmod a+x install-rtl8821cu.sh
if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
sudo ./install-rtl8821cu.sh
cd ~
sudo rm -r 8821cu
sleep 2

# Installing the RTL88x2BU
clear
echo -e "${RED}[+] Step 12: Installing additional network drivers...${NOCOLOR}"
echo -e " "
echo -e "${RED}[+] Installing the Realtek RTL88x2BU Wireless Network Driver ${NOCOLOR}"
git clone https://github.com/morrownr/88x2bu.git
cd 88x2bu
cp ~/torbox/install/Network/install-rtl88x2bu.sh .
sudo chmod a+x install-rtl88x2bu.sh
if [ ! -z "$CHECK_HD1" ] || [ ! -z "$CHECK_HD2" ]; then
	if uname -r | grep -q "arm64"; then
		./raspi64.sh
	else
	 ./raspi32.sh
 fi
fi
sudo ./install-rtl88x2bu.sh
cd ~
sudo rm -r 88x2bu
sleep 2

# 13. Adding the user torbox
sleep 10
clear
echo -e "${RED}[+] Step 13: Set up the torbox user...${NOCOLOR}"
echo -e "${RED}[+]          In this step the user \"torbox\" with the default${NOCOLOR}"
echo -e "${RED}[+]          password \"CHANGE-IT\" is created.  ${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    To use TorBox, you have to log in with \"torbox\"${NOCOLOR}"
echo -e "${WHITE}    and the default password \"CHANGE-IT\"!!${NOCOLOR}"
echo -e "${WHITE}    Please, change the default passwords as soon as possible!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
sudo adduser --disabled-password --gecos "" torbox
echo -e "CHANGE-IT\nCHANGE-IT\n" | sudo passwd torbox
sudo adduser torbox sudo
sudo adduser torbox netdev
sudo mv /home/ubuntu/* /home/torbox/
(sudo mv /home/ubuntu/.profile /home/torbox/) 2> /dev/null
sudo mkdir /home/torbox/openvpn
(sudo rm .bash_history) 2> /dev/null
sudo chown -R torbox.torbox /home/torbox/
if ! sudo grep "# Added by TorBox" /etc/sudoers ; then
  sudo printf "\n# Added by TorBox\ntorbox  ALL=NOPASSWD:ALL\n" | sudo tee -a /etc/sudoers
  # or: sudo printf "\n# Added by TorBox\ntorbox  ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers --- HAST TO BE CHECKED AND COMPARED WITH THE USER "UBUNTU"!!
  (sudo visudo -c) 2> /dev/null
fi
cd /home/torbox/

# 14. Finishing, cleaning and booting
echo ""
echo ""
echo -e "${RED}[+] Step 14: We are finishing and cleaning up now!${NOCOLOR}"
echo -e "${RED}[+]          This will erase all log files and cleaning up the system.${NOCOLOR}"
echo ""
echo -e "${WHITE}[!] IMPORTANT${NOCOLOR}"
echo -e "${WHITE}    After this last step, TorBox has to be rebooted manually.${NOCOLOR}"
echo -e "${WHITE}    In order to do so type \"exit\" and log in with \"torbox\" and the default password \"CHANGE-IT\"!! ${NOCOLOR}"
echo -e "${WHITE}    Then in the TorBox menu, you have to chose entry 14.${NOCOLOR}"
echo -e "${WHITE}    After rebooting, please, change the default passwords immediately!!${NOCOLOR}"
echo -e "${WHITE}    The associated menu entries are placed in the configuration sub-menu.${NOCOLOR}"
echo ""
read -n 1 -s -r -p $'\e[1;31mTo complete the installation, please press any key... \e[0m'
clear
echo -e "${RED}[+] Erasing ALL LOG-files...${NOCOLOR}"
echo " "
for logs in `sudo find /var/log -type f`; do
  echo -e "${RED}[+]${NOCOLOR} Erasing $logs"
  sudo rm $logs
  sleep 1
done
echo -e "${RED}[+]${NOCOLOR} Erasing History..."
#.bash_history is already deleted
history -c
echo ""
echo -e "${RED}[+] Cleaning up...${NOCOLOR}"
(sudo rm -r Downloads) 2> /dev/null
(sudo rm -r get-pip.py) 2> /dev/null
(sudo rm -r python-urwid*) 2> /dev/null
echo ""
echo -e "${RED}[+] Setting up the hostname...${NOCOLOR}"
# This has to be at the end to avoid unnecessary error messages
(sudo cp /etc/hostname /etc/hostname.bak) 2> /dev/null
sudo cp torbox/etc/hostname /etc/
echo -e "${RED}[+] Copied /etc/hostname -- backup done${NOCOLOR}"
(sudo cp /etc/hosts /etc/hosts.bak) 2> /dev/null
sudo cp torbox/etc/hosts /etc/
echo -e "${RED}[+] Copied /etc/hosts -- backup done${NOCOLOR}"
echo -e "${RED}[+] Rebooting...${NOCOLOR}"
sleep 3
sudo reboot
