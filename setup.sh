#!/bin/bash

# setup.sh - A simple bash installer for my RPI
# Copyright 2024 Andras Varro https://github.com/andras-varro
# V20240301
#
# Tested with Raspberry OS Debian GNU/Linux 12 (bookworm) on RPi 5
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

echo "Please change Pi password (def: raspberry)"
passwd
(($?)) && read -n1 -r -p "[passwd] FAILED!" key

echo "Please change root password (def: empty)"
sudo passwd
(($?)) && read -n1 -r -p "[sudo passwd] FAILED!" key

sudo apt update -qq -o=Dpkg::Use-Pty=0
(($?)) && read -n1 -r -p "[sudo apt update] FAILED!" key
sudo apt-get upgrade -qq -o=Dpkg::Use-Pty=0 -y
(($?)) && read -n1 -r -p "[sudo apt-get upgrade] FAILED!" key
sudo apt-get dist-upgrade -qq -o=Dpkg::Use-Pty=0 -y
(($?)) && read -n1 -r -p "[sudo apt-get dist-upgrade] FAILED!" key
sudo apt-get install -qq -o=Dpkg::Use-Pty=0 -y keepassxc ca-certificates unrar-free transmission aisleriot kdiff3 krename zip p7zip-full breeze-icon-theme gnome-keyring krusader
(($?)) && read -n1 -r -p "[sudo apt-get install keepassxc ca-certificates unrar-free transmission aisleriot kdiff3 krename zip p7zip-full breeze-icon-theme gnome-keyring krusader] FAILED!" key

# install VeraCrypt
chmod +x ./veracrypt/setup_veracrypt.sh
(($?)) && read -n1 -r -p "[chmod +x ./veracrypt/setup_veracrypt.sh] FAILED!" key
./veracrypt/setup_veracrypt.sh
(($?)) && read -n1 -r -p "[./veracrypt/setup_veracrypt.sh] FAILED!" key


# install RClone
chmod +x ./rclone/setup_rclone.sh
(($?)) && read -n1 -r -p "[chmod +x ./rclone/setup_rclone.sh] FAILED!" key
./rclone/setup_rclone.sh
(($?)) && read -n1 -r -p "[./rclone/setup_rclone.sh] FAILED!" key

# install Cryptomator CLI
chmod +x ./cryptomator/cryptomator.sh
(($?)) && read -n1 -r -p "[chmod +x ./cryptomator/cryptomator.sh] FAILED!" key
./cryptomator/cryptomator.sh setup
(($?)) && read -n1 -r -p "[./cryptomator/cryptomator.sh] FAILED!" key

# Setup nord VPN
chmod +x ./vpn/setup_nordvpn.sh
(($?)) && read -n1 -r -p "[chmod +x ./vpn/setup_nordvpn.sh] FAILED!" key
./vpn/setup_nordvpn.sh
(($?)) && read -n1 -r -p "[./vpn/setup_nordvpn.sh] FAILED!" key

# Setup log-in and locking
chmod +x ./hardening/hardening.sh
(($?)) && read -n1 -r -p "[chmod +x ./cryptomator/hardening.sh] FAILED!" key
./hardening/hardening.sh
(($?)) && read -n1 -r -p "[./cryptomator/hardening.sh] FAILED!" key

# update
sudo apt-get update -qq -o=Dpkg::Use-Pty=0 
(($?)) && read -n1 -r -p "[sudo apt-get update] FAILED!" key
sudo apt-get autoremove -qq -o=Dpkg::Use-Pty=0 -y
(($?)) && read -n1 -r -p "[sudo apt-get autoremove -qq -o=Dpkg::Use-Pty=0 -y] FAILED!" key
