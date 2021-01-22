#!/bin/bash

# setup_rclone.sh - A simple bash demo to install and configure rclone on RPI
# Copyright 2021 Andras Varro https://github.com/andras-varro
# V20210121
#
# Tested with Raspbian GNU/Linux 10 (buster) on RPi 4
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

start_config=1
create_service=1
which rclone > /dev/null 2>&1
result=$?
if [ $result -ne 0 ]; then
  curl -L https://raw.github.com/pageauc/rclone4pi/master/rclone-install.sh | bash
else
  echo "rclone is already installed"
  echo "Do you want to continue with the configuration? [Y/N]"
  read -n 1 -r answer
  echo ""
  if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
    exit 0
  fi
fi

if [ -e /home/pi/.config/rclone/rclone.conf ]; then
  read -r line < /home/pi/.config/rclone/rclone.conf
  length=${#line}
  if [ $length -ne 0 ]; then
    echo "rclone is already configured for the system for $line"
    echo "this script only supports the use of the first entry in the"
    echo "config file. "
    echo "Do you wish to start rclone configuration tool? [Y/N]"
    read -n 1 -r answer
    echo ""
    if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
      start_config=0
    fi
  fi
fi

if [ $start_config -eq 1 ]; then
  rclone config
fi

read -r line < /home/pi/.config/rclone/rclone.conf
length=${#line}
if [ $length -eq 0 ]; then
  echo "RClone configuration is empty, skipping RClone service"
else
  service_file_name=/etc/systemd/system/rclone.service
  if [ -e $service_file_name ]; then
    echo "RClone service file already exist. Do you want to re-generate? [Y/N]"
    read -n 1 -r answer
    echo ""
    if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
      create_service=0
    else
      sudo systemctl stop rclone.service
      sudo rm $service_file_name
    fi
  fi
  
  if [ $create_service -eq 1 ]; then 
    # close bracket and newline has to be removed from the end
    let no_close_bracket=$length-2
    entry_name=${line:1:$no_close_bracket}
    echo "Configuring RClone service for $entry_name:"
    if [ ! -e "/home/pi/$entry_name" ]; then
      mkdir /home/pi/$entry_name
    fi
    
    
    sudo touch $service_file_name
    sudo tee $service_file_name > /dev/null <<EOL
# /etc/systemd/system/rclone.service
[Unit]
Description=${entry_name} (rclone)
AssertPathIsDirectory=/home/pi/${entry_name}
After=plexdrive.service

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount  "${entry_name}:" /home/pi/${entry_name} \\
        --config=/home/pi/.config/rclone/rclone.conf \\
        --vfs-cache-mode writes \\
        --allow-other
ExecStop=/bin/fusermount -u /home/pi/${entry_name}
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable rclone.service
    sudo systemctl start rclone.service
  fi
fi
