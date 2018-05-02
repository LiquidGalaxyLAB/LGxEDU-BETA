#!/bin/bash

cat << "EOM"
 _ _             _     _               _                  
| (_) __ _ _   _(_) __| |   __ _  __ _| | __ ___  ___   _ 
| | |/ _` | | | | |/ _` |  / _` |/ _` | |/ _` \ \/ / | | |
| | | (_| | |_| | | (_| | | (_| | (_| | | (_| |>  <| |_| |
|_|_|\__, |\__,_|_|\__,_|  \__, |\__,_|_|\__,_/_/\_\\__, |
        |_|                |___/                    |___/ 
https://github.com/LiquidGalaxy/liquid-galaxy
https://github.com/LiquidGalaxyLAB/liquid-galaxy
-------------------------------------------------------------

EOM

# Parameters

MASTER_IP=""
MASTER_USER=$USER
MASTER_HOME=$HOME
MASTER_PASSWORD=""
LOCAL_USER=$USER
MACHINE_ID="1"
MACHINE_NAME="lg"$MACHINE_ID
OCTET="12"
SCREEN_ORIENTATION="V"
GIT_FOLDER_NAME="liquid-galaxy"
GIT_URL="https://github.com/LiquidGalaxyLAB/liquid-galaxy"
EARTH_DEB="http://dl.google.com/dl/earth/client/current/google-earth-stable_current_i386.deb"
if [ `getconf LONG_BIT` = "64" ]; then
EARTH_DEB="http://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb"
fi
EARTH_FOLDER="/opt/google/earth/pro/"
NETWORK_INTERFACE=$(/sbin/route -n | grep "^0.0.0.0" | rev | cut -d' ' -f1 | rev)
NETWORK_INTERFACE_MAC=$(/sbin/ifconfig | grep $NETWORK_INTERFACE | awk '{print $5}')
SSH_PASSPHRASE=""

read -p "Machine id (i.e. 1 for lg1) (1 == master): " MACHINE_ID
if [ "$(echo $MACHINE_ID | cut -c-2)" == "lg" ]; then
	MACHINE_ID="$(echo $MACHINE_NAME | cut -c3-)"
fi
MACHINE_NAME="lg"$MACHINE_ID
if [ $MACHINE_ID == "1" ]; then
	MASTER=true
else
	echo "Make sure Master machine (lg1) is connected to the network before proceding!"
	read -p "Master machine IP (i.e. 192.168.1.42): " MASTER_IP
	read -p "Master local user password (i.e. lg password): " MASTER_PASSWORD
fi

#
# Pre-start
#

PRINT_IF_NOT_MASTER=""
if [ $MASTER == false ]; then
	PRINT_IF_NOT_MASTER=$(cat <<- EOM

	MASTER_IP: $MASTER_IP
	MASTER_USER: $MASTER_USER
	MASTER_HOME: $MASTER_HOME
	MASTER_PASSWORD: $MASTER_PASSWORD
	EOM
	)
fi

# Initialize sudo access
sudo -v

#
# General
#

export DEBIAN_FRONTEND=noninteractive

# Update OS
echo "Checking for system updates..."
sudo apt-get update

echo "Upgrading system packages ..."
sudo apt-get -yq upgrade

echo "Installing new packages..."
sudo apt-get install -yq git chromium-browser nautilus openssh-server sshpass squid3 squid-cgi apache2 xdotool unclutter network-manager

if [ $INSTALL_DRIVERS == true ] ; then
	echo "Installing extra drivers..."
	sudo apt-get install -yq libfontconfig1:i386 libx11-6:i386 libxrender1:i386 libxext6:i386 libglu1-mesa:i386 libglib2.0-0:i386 libsm6:i386
fi

# OS config tweaks (like disabling idling, hiding launcher bar, ...)
echo "Setting system configuration..."
sudo tee /etc/lightdm/lightdm.conf > /dev/null << EOM
[Seat:*]
autologin-guest=false
autologin-user=$LOCAL_USER
autologin-user-timeout=0
autologin-session=ubuntu
EOM
echo autologin-user=lg >> sudo /etc/lightdm/lightdm.conf
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
echo -e 'Section "ServerFlags"\nOption "blanktime" "0"\nOption "standbytime" "0"\nOption "suspendtime" "0"\nOption "offtime" "0"\nEndSection' | sudo tee -a /etc/X11/xorg.conf > /dev/null
gsettings set org.compiz.unityshell:/org/compiz/profiles/unity/plugins/unityshell/ launcher-hide-mode 1
sudo update-alternatives --set x-www-browser /usr/bin/chromium-browser
sudo update-alternatives --set gnome-www-browser /usr/bin/chromium-browser
sudo apt-get remove --purge -yq update-notifier*

#
# Liquid Galaxy
#

# Network configuration
sudo tee -a "/etc/network/interfaces" > /dev/null << EOM
auto eth0
iface eth0 inet dhcp
EOM
sudo sed -i "s/\(managed *= *\).*/\1true/" /etc/NetworkManager/NetworkManager.conf
echo "SUBSYSTEM==\"net\",ACTION==\"add\",ATTR{address}==\"$NETWORK_INTERFACE_MAC\",KERNEL==\"$NETWORK_INTERFACE\",NAME=\"eth0\"" | sudo tee /etc/udev/rules.d/10-network.rules > /dev/null
sudo sed -i '/lgX.liquid.local/d' /etc/hosts
sudo sed -i '/kh.google.com/d' /etc/hosts
sudo sed -i '/10.42./d' /etc/hosts
sudo tee -a "/etc/hosts" > /dev/null 2>&1 << EOM
10.42.$OCTET.1  lg1
10.42.$OCTET.2  lg2
10.42.$OCTET.3  lg3
10.42.$OCTET.4  lg4
10.42.$OCTET.5  lg5
10.42.$OCTET.6  lg6
10.42.$OCTET.7  lg7
10.42.$OCTET.8  lg8
EOM
sudo sed -i '/10.42./d' /etc/hosts.squid
sudo tee -a "/etc/hosts.squid" > /dev/null 2>&1 << EOM
10.42.$OCTET.1  lg1
10.42.$OCTET.2  lg2
10.42.$OCTET.3  lg3
10.42.$OCTET.4  lg4
10.42.$OCTET.5  lg5
10.42.$OCTET.6  lg6
10.42.$OCTET.7  lg7
10.42.$OCTET.8  lg8
EOM
sudo tee "/etc/iptables.conf" > /dev/null << EOM
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [43616:6594412]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -p tcp -m multiport --dports 22 -j ACCEPT
-A INPUT -s 10.42.0.0/16 -p udp -m udp --dport 161 -j ACCEPT
-A INPUT -s 10.42.0.0/16 -p udp -m udp --dport 3401 -j ACCEPT
-A INPUT -p tcp -m multiport --dports 81,8111 -j ACCEPT
-A INPUT -s 10.42.$OCTET.0/24 -p tcp -m multiport --dports 80,3128,3130 -j ACCEPT
-A INPUT -s 10.42.$OCTET.0/24 -p udp -m multiport --dports 80,3128,3130 -j ACCEPT
-A INPUT -s 10.42.$OCTET.0/24 -p tcp -m multiport --dports 9335 -j ACCEPT
-A INPUT -s 10.42.$OCTET.0/24 -d 10.42.$OCTET.255/32 -p udp -j ACCEPT
-A INPUT -j DROP
-A FORWARD -j DROP
COMMIT
*nat
:PREROUTING ACCEPT [52902:8605309]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [358:22379]
:POSTROUTING ACCEPT [358:22379]
COMMIT
EOM

exit 0
