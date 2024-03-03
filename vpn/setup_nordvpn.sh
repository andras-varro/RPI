#!/bin/bash

# setup_nordvpn.sh - A simple bash installer for nordvpn
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

sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
(($?)) && read -n1 -r -p "[sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)] FAILED!" key

sudo usermod -aG nordvpn $USER
(($?)) && read -n1 -r -p "[sudo usermod -aG nordvpn $USER] FAILED!" key
local_subnets=(`ip -4 -br a s | sed -r 's:([0-9]\.)[0-9]{1,3}/:\10/:g' | awk '{print $3}'`)
(($?)) && read -n1 -r -p "[ip -4 -br a s | sed -r 's:([0-9]\.)[0-9]{1,3}/:\10/:g' | awk '{print $3}'] FAILED!" key
length=${#local_subnets[@]}
if [ $length -eq 0 ]; then
  echo "No local subnets found."
else
  for str in ${local_subnets[@]}; do 
    if [[ $str == 127.0.0.0* ]] ; then continue; fi
    read -n 1 -r -p "Do you want to whitelist local subnet [$str] with nordvpn? [Y/N]" answer
    echo ""
    if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then continue; fi
    
    sudo nordvpn whitelist add subnet $str
    (($?)) && read -n1 -r -p "[nordvpn whitelist add subnet $str] FAILED!" key
  done
fi
