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
MASTER=false
INSTALL_DRIVERS=false
INSTALL_DRIVERS_CHAR="n"
INTERFACE="eth0"
USE_WIRELESS_CHAR="n"
MASTER_IP=""
MASTER_USER=$USER
MASTER_HOME=$HOME
MASTER_PASSWORD=""
LOCAL_USER=$USER
MACHINE_ID="1"
MACHINE_NAME="lg"$MACHINE_ID
TOTAL_MACHINES="3"

LG_FRAMES="lg3 lg1 lg2"
OCTET="42"
SCREEN_ORIENTATION="V"
GIT_FOLDER_NAME="LGxEDU"
GIT_URL="https://github.com/LiquidGalaxyLAB/LGxEDU"
EARTH_DEB="http://dl.google.com/dl/earth/client/current/google-earth-stable_current_i386.deb"
if [ `getconf LONG_BIT` = "64" ]; then
EARTH_DEB="http://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb"
fi
EARTH_FOLDER="/usr/bin/"
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
read -p "Total machines count (i.e. 3): " TOTAL_MACHINES
read -p "Unique number that identifies your Galaxy (octet) (i.e. 42): " OCTET
read -p "Do you want to install extra drivers? (y/n): " INSTALL_DRIVERS_CHAR
read -p "Will you use wireless? (y/n): " USE_WIRELESS_CHAR

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

mid=$((TOTAL_MACHINES / 2))

array=()

for j in `seq $((mid + 2)) $TOTAL_MACHINES`;
do
    array+=("lg"$j)
done

for j in `seq 1 $((mid+1))`;
do
    array+=("lg"$j)
done

printf -v LG_FRAMES "%s " "${array[@]}"

if [ $INSTALL_DRIVERS_CHAR == "y" ] || [$INSTALL_DRIVERS_CHAR == "Y" ]; then
	INSTALL_DRIVERS=true
fi

if [ $USE_WIRELESS_CHAR == "y" ] || [$USE_WIRELESS_CHAR == "Y" ]; then
	INTERFACE="wlan0"
fi

cat << EOM

Liquid Galaxy will be installed with the following configuration:
MASTER: $MASTER
LOCAL_USER: $LOCAL_USER
MACHINE_ID: $MACHINE_ID
MACHINE_NAME: $MACHINE_NAME $PRINT_IF_NOT_MASTER
TOTAL_MACHINES: $TOTAL_MACHINES
OCTET (UNIQUE NUMBER): $OCTET
INSTALL_DRIVERS: $INSTALL_DRIVERS
GIT_URL: $GIT_URL 
GIT_FOLDER: $GIT_FOLDER_NAME
EARTH_DEB: $EARTH_DEB
EARTH_FOLDER: $EARTH_FOLDER
NETWORK_INTERFACE: $INTERFACE
NETWORK_MAC_ADDRESS: $NETWORK_INTERFACE_MAC

Is it correct? Press any key to continue or CTRL-C to exit
EOM
read

if [ "$(cat /etc/os-release | grep NAME=\"Ubuntu\")" == "" ]; then
	echo "Warning!! This script is meant to be run on an Ubuntu OS. It may not work as expected."
	echo -n "Press any key to continue or CTRL-C to exit"
	read
fi

if [[ $EUID -eq 0 ]]; then
   echo "Do not run it as root!" 1>&2
   exit 1
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
sudo apt-get install -yq git chromium-browser nautilus openssh-server sshpass squid3 squid-cgi apache2 xdotool unclutter zip wish network-manager

if [ $INSTALL_DRIVERS == true ] ; then
	echo "Installing extra drivers..."
	sudo apt-get install -yq libfontconfig1:i386 libx11-6:i386 libxrender1:i386 libxext6:i386 libglu1-mesa:i386 libglib2.0-0:i386 libsm6:i386
fi

echo "Installing Google Earth..."
sudo apt install googleearth-package -y
make-googleearth-package --force
sudo apt-get -f install -y
sudo dpkg -i googleearth_6.0.3.2197+1.2.0-1_amd64.deb
sudo apt-get -f install -y


#
# Liquid Galaxy
#

# Setup Liquid Galaxy files
echo "Setting up Liquid Galaxy..."
git clone $GIT_URL

sudo cp -r $GIT_FOLDER_NAME/earth/ $HOME
sudo ln -s $EARTH_FOLDER $HOME/earth/builds/latest
sudo ln -s /usr/lib/googleearth/drivers.ini $HOME/earth/builds/latest/drivers.ini
awk '/LD_LIBRARY_PATH/{print "export LC_NUMERIC=en_US.UTF-8"}1' $HOME/earth/builds/latest/googleearth | sudo tee $HOME/earth/builds/latest/googleearth > /dev/null

# Enable solo screen for slaves
if [ $MASTER != true ]; then
	sudo sed -i -e 's/slave_x/slave_'${MACHINE_ID}'/g' $HOME/earth/kml/slave/myplaces.kml
	sudo sed -i -e 's/sync_nlc_x/sync_nlc_'${MACHINE_ID}'/g' $HOME/earth/kml/slave/myplaces.kml
fi

sudo cp -r $GIT_FOLDER_NAME/gnu_linux/home/lg/. $HOME

cd $HOME"/dotfiles/"
for file in *; do
    sudo mv "$file" ".$file"
done
sudo cp -r . $HOME
cd - > /dev/null

sudo cp -r $GIT_FOLDER_NAME/gnu_linux/etc/ $GIT_FOLDER_NAME/gnu_linux/patches/ $GIT_FOLDER_NAME/gnu_linux/sbin/ / #Estem aqui!!

sudo chmod 0440 /etc/sudoers.d/42-lg
sudo chown -R $LOCAL_USER:$LOCAL_USER $HOME
sudo chown $LOCAL_USER:$LOCAL_USER /home/lg/earth/builds/latest/drivers.ini

# Configure SSH
if [ $MASTER == true ]; then
	echo "Setting up SSH..."
	$HOME/tools/clean-ssh.sh
else
	echo "Starting SSH files sync with master..."
	sshpass -p "$MASTER_PASSWORD" scp -o StrictHostKeyChecking=no $MASTER_IP:$MASTER_HOME/ssh-files.zip $HOME/
	unzip $HOME/ssh-files.zip -d $HOME/ > /dev/null
	sudo cp -r $HOME/ssh-files/etc/ssh /etc/
	sudo cp -r $HOME/ssh-files/root/.ssh /root/ 2> /dev/null
	sudo cp -r $HOME/ssh-files/user/.ssh $HOME/
	sudo rm -r $HOME/ssh-files/
	sudo rm $HOME/ssh-files.zip
fi
sudo chmod 0600 $HOME/.ssh/lg-id_rsa
sudo chmod 0600 /root/.ssh/authorized_keys
sudo chmod 0600 /etc/ssh/ssh_host_dsa_key
sudo chmod 0600 /etc/ssh/ssh_host_ecdsa_key
sudo chmod 0600 /etc/ssh/ssh_host_rsa_key
sudo chown -R $LOCAL_USER:$LOCAL_USER $HOME/.ssh

# prepare SSH files for other nodes (slaves)
if [ $MASTER == true ]; then
	mkdir -p ssh-files/etc
	sudo cp -r /etc/ssh ssh-files/etc/
	mkdir -p ssh-files/root/
	sudo cp -r /root/.ssh ssh-files/root/ 2> /dev/null
	mkdir -p ssh-files/user/
	sudo cp -r $HOME/.ssh ssh-files/user/
	sudo zip -FSr "ssh-files.zip" ssh-files
	if [ $(pwd) != $HOME ]; then
		sudo mv ssh-files.zip $HOME/ssh-files.zip
	fi
	sudo chown -R $LOCAL_USER:$LOCAL_USER $HOME/ssh-files.zip
	sudo rm -r ssh-files/
fi

# Screens configuration
cat > $HOME/personavars.txt << 'EOM'
DHCP_LG_FRAMES="lg3 lg1 lg2"
DHCP_LG_FRAMES_MAX=3

FRAME_NO=$(cat /home/lg/frame 2>/dev/null)
DHCP_LG_SCREEN="$(( ${FRAME_NO} + 1 ))"
DHCP_LG_SCREEN_COUNT=1
DHCP_OCTET=42
DHCP_LG_PHPIFACE="http://lg1:81/"

DHCP_EARTH_PORT=45678
DHCP_EARTH_BUILD="latest"
DHCP_EARTH_QUERY="/tmp/query.txt"

DHCP_MPLAYER_PORT=45680
EOM
sed -i "s/\(DHCP_LG_FRAMES *= *\).*/\1\"$LG_FRAMES\"/" $HOME/personavars.txt
sed -i "s/\(DHCP_LG_FRAMES_MAX *= *\).*/\1$TOTAL_MACHINES/" $HOME/personavars.txt
sed -i "s/\(DHCP_OCTET *= *\).*/\1$OCTET/" $HOME/personavars.txt
sudo $HOME/bin/personality.sh $MACHINE_ID $OCTET > /dev/null

# Network configuration
sudo tee -a "/etc/network/interfaces" > /dev/null 2>&1 << EOM
auto $INTERFACE
iface $INTERFACE inet dhcp

auto $INTERFACE:$MACHINE_ID
iface $INTERFACE:$MACHINE_ID inet static
address 10.42.$OCTET.$MACHINE_ID
gateway 10.42.42.0
netmask 255.255.255.0
EOM

# In-session network configuration
sudo ip addr add 10.42.$OCTET.$MACHINE_ID/24 dev $INTERFACE

sudo sed -i "s/\(managed *= *\).*/\1true/" /etc/NetworkManager/NetworkManager.conf
echo "SUBSYSTEM==\"net\",ACTION==\"add\",ATTR{address}==\"$NETWORK_INTERFACE_MAC\",KERNEL==\"$NETWORK_INTERFACE\",NAME=\"$INTERFACE\"" | sudo tee /etc/udev/rules.d/10-network.rules > /dev/null
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

# Allow iptables to forward and recieve traffic
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -F

# If master, enable ssh daemon on startup
if [ $MASTER == true ]; then
	sudo systemctl enable ssh
fi

# In-session ssh daemon start
sudo service ssh start

# Launch on boot
mkdir -p $HOME/.config/autostart/
echo -e "[Desktop Entry]\nName=LG\nExec=bash "$HOME"/bin/startup-script.sh\nType=Application" > $HOME"/.config/autostart/lg.desktop"

# Web interface
if [ $MASTER == true ]; then
	echo "Installing web interface (master only)..."
	sudo apt-get -yq install php php-cgi libapache2-mod-php
	sudo touch /etc/apache2/httpd.conf
	sudo sed -i '/accept.lock/d' /etc/apache2/apache2.conf
	sudo rm /var/www/html/index.html
	sudo cp -r $GIT_FOLDER_NAME/php-interface/. /var/www/html/
	sudo chown -R $LOCAL_USER:$LOCAL_USER /var/www/html/
fi

# Cleanup
sudo rm -r $GIT_FOLDER_NAME

#
# Global cleanup
#

echo "Cleaning up..."
sudo apt-get -yq autoremove

if [ `getconf LONG_BIT` = "64" ]; then
echo "Installing additional libraries for 64 bit OS"
sudo apt-get install -y libfontconfig1:i386 libx11-6:i386 libxrender1:i386 libxext6:i386 libglu1-mesa:i386 libglib2.0-0:i386 libsm6:i386
fi

echo "Liquid Galaxy installation completed! :-)"
echo "Press ENTER key to exit"
read
exit 0
