#!/bin/bash

# make-it-ap.sh - A simple bash demo to turn RPI (with Raspberry OS/Raspbian) into an access point
# Copyright 2021 Andras Varro https://github.com/andras-varro
# V20210121
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install hostapd dnsmasq -y
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOL
interface wlan0
   static ip_address=192.168.220.1/24
   nohook wpa_supplicant
EOL

sudo systemctl restart dhcpcd
sudo touch /etc/hostapd/hostapd.conf 
sudo tee -a /etc/hostapd/hostapd.conf > /dev/null <<EOL
interface=wlan0
driver=nl80211
ssid=nemet
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=Your_S3cr3t_Pa$$phrase!
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOL

# sudo sed -i 's+#DAEMON_CONF=""+DAEMON_CONF="/etc/hostapd/hostapd.conf"+g' /etc/default/hostapd
sudo sed -i 's+^DAEMON_CONF=.*$+DAEMON_CONF=/etc/hostapd/hostapd.conf+g' /etc/init.d/hostapd
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo tee -a /etc/dnsmasq.conf > /dev/null <<EOL
interface=wlan0       # Use interface wlan0  
#server=8.8.8.8      # Use Cloudflare DNS  
dhcp-range=192.168.220.50,192.168.220.150,12h # IP range and lease time  
EOL

sudo sed -i "/net.ipv4.ip_forward=1/ s/# *//" /etc/sysctl.conf
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
sudo iptables -t nat -X
# W/O VPN:
#sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT

sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
sudo sed -i '/^exit 0/i iptables-restore < /etc/iptables.ipv4.nat' /etc/rc.local
sudo systemctl unmask hostapd
sudo systemctl unmask dnsmasq
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl start hostapd
sudo systemctl start dnsmasq 

echo Finished, rebooting

sudo reboot
