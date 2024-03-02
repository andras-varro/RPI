#!/bin/bash

# setup_rclone.sh - A simple bash demo to install and configure rclone on RPI
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

echo "Starting rclone setup."
rclone_url=https://downloads.rclone.org/rclone-current-linux-arm64.deb
rclone_local=rclone-current-linux-arm64.deb
rclone_working=0
which rclone > /dev/null 2>&1
result=$?
if [ $result -eq 0 ]; then
  echo "  rclone seems to be installed. Checking..."
  # rclone supports rclone version --check to check for new versions. Would worth discovering..
  rclone version > /dev/null 2>&1
  result=$?
  if [ $result -eq 0 ]; then 
    echo "  $(rclone version) rclone is installed."
    rclone_working=1
  else
    echo "  rclone does not work. Trying to re-install."
    sudo apt --fix-broken install -y
  fi
fi

if [ $rclone_working -eq 0 ]; then
  echo "  Installing rclone."
  development_folder_existed_before_script=1
  rclone_folder_existed_before_script=1
  cd_worked=1
  
  if [ ! -d $HOME/development ]; then 
    mkdir $HOME/development
    (($?)) && read -n1 -r -p "[mkdir $HOME/development] FAILED!" key
    development_folder_existed_before_script=0
  fi

  if [ ! -d $HOME/development/rclone ]; then 
    mkdir $HOME/development/rclone
    (($?)) && read -n1 -r -p "[mkdir $HOME/development/rclone] FAILED!" key
    rclone_folder_existed_before_script=0
  fi

  pushd $PWD
  cd $HOME/development/rclone
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    cd_worked=0
    read -n1 -r -p "Cannot create  $HOME/development/rclone. Working in current folder. Press any key to continue..." key
  fi

  if [ ! -e $rclone_local ]; then
    wget -L -O $rclone_local $rclone_url
    (($?)) && read -n1 -r -p "[wget -L -O $rclone_local $rclone_url] FAILED!" key
  fi
  
  sudo apt install -qq -o=Dpkg::Use-Pty=0 ./$rclone_local
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    rclone version > /dev/null 2>&1
    result=$?
    if [ $result -eq 0 ]; then 
      echo "$(rclone version)"
      echo ""
      echo "rclone is installed"
      rclone_working=1
    fi
  fi
fi


if [ $rclone_working -eq 0 ]; then
  read -n1 -r -p "rclone is not availabe, installation has FAILED! Press any key to exit..." key
  exit 1
fi

read -n 1 -r -p "  Do you want to continue with the configuration and service installation? [Y/N]" answer
echo ""
if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
  exit 0
fi

start_config=1
if [ -e $HOME/.config/rclone/rclone.conf ]; then
  oriIFS=$IFS
  IFS=$'\n'
  array=(`grep "\[.*\]" $HOME/.config/rclone/rclone.conf`)
  length=${#array[@]}
  if [ $length -ne 0 ]; then
    echo "    rclone is already configured for the system for the following entries:"
    for str in ${array[@]}; do echo "     $str"; done
    read -n 1 -r -p "  Do you wish to start rclone configuration tool? [Y/N]" answer
    echo ""
    if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
      start_config=0
    fi
  fi
  IFS=$oriIFS
fi

if [ $start_config -eq 1 ]; then
  rclone config
  (($?)) && read -n1 -r -p "[rclone config] FAILED!" key
fi

if [ -e $HOME/.config/rclone/rclone.conf ]; then
  oriIFS=$IFS
  IFS=$'\n'
  array=(`grep "\[.*\]" $HOME/.config/rclone/rclone.conf`)
  length=${#array[@]}
  if [ $length -eq 0 ]; then
    echo "  RClone configuration is empty, skipping RClone service. Exiting."
    exit 0
  fi
  
  for str in ${array[@]}; do 
    create_service=1
    entrylength=${#str}
    # close bracket and newline has to be removed from the end
    let no_close_bracket=$entrylength-2
    rclone_name=${str:1:$no_close_bracket}
    entry_name=${rclone_name//[^a-zA-Z0-9]/_}
    service_name="rclone_$entry_name.service"
    service_file_name=/etc/systemd/system/$service_name
    if [ -e $service_file_name ]; then
      read -n 1 -r -p "  RClone service file for $service_name already exist. Do you want to re-generate? [Y/N]" answer
      echo ""
      if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
        create_service=0
      else
        sudo systemctl stop $service_name
        (($?)) && read -n1 -r -p "[sudo systemctl stop $service_name] FAILED!" key
        sudo systemctl disable $service_name
        (($?)) && read -n1 -r -p "[sudo systemctl disable $service_name] FAILED!" key
        sudo rm $service_file_name
        (($?)) && read -n1 -r -p "[sudo rm $service_file_name] FAILED!" key
      fi
    fi
  
    if [ $create_service -eq 1 ]; then 
      echo "  Configuring RClone service for $entry_name:"
      if [ ! -e "$HOME/$entry_name" ]; then
        mkdir $HOME/$entry_name
        (($?)) && read -n1 -r -p "[mkdir $HOME/$entry_name] FAILED!" key
      fi
    
      sudo touch $service_file_name
      (($?)) && read -n1 -r -p "[sudo touch $service_file_name] FAILED!" key
      sudo tee $service_file_name > /dev/null <<EOL
# $service_file_name
[Unit]
Description=${entry_name} (rclone)
AssertPathIsDirectory=${HOME}/${entry_name}
After=plexdrive.service

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount  '${rclone_name}': ${HOME}/${entry_name} \\
        --config=$HOME/.config/rclone/rclone.conf \\
        --vfs-cache-mode writes \\
        --allow-other
ExecStop=/bin/fusermount -u $HOME/${entry_name}
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOL
      (($?)) && read -n1 -r -p "[sudo tee $service_file_name > /dev/null <<EOL...] FAILED!" key
      sudo systemctl daemon-reload
      (($?)) && read -n1 -r -p "[systemctl daemon-reload] FAILED!" key
      sudo systemctl enable $service_name
      (($?)) && read -n1 -r -p "[sudo systemctl enable $service_name] FAILED!" key
      sudo systemctl start $service_name
      (($?)) && read -n1 -r -p "[sudo systemctl start $service_name] FAILED!" key
      systemctl status $service_name > /dev/null
      result=$?
      if [ $result -ne 0 ]; then 
        echo "[systemctl status $service_name] reported FAILURE!"
        echo "systemctl status $service_name"
        echo "=============================="
        systemctl status $service_name
        echo
        echo "journalctl -b -n 50 -u $service_name --since \"5 minutes ago\""
        echo "==========================================================="
        journalctl -b -n 50 -u $service_name --since "5 minutes ago"
        echo
        echo "cat $service_file_name"
        echo "======================="
        cat $service_file_name
        read -n1 -r -p "Press enter to continue..." key
      fi
    fi
  done
fi

echo "Finished rclone installation"
