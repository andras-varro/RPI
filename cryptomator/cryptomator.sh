#!/bin/bash

# cryptomator.sh - A simple bash installer for Cryptomator AppImage
# Copyright 2024 Andras Varro https://github.com/andras-varro
# V20240619
#
# Tested with Debian GNU/Linux 12 (bookworm)x64 on RPi 5
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

echo "Starting Cryptomator setup."
Cryptomator_url=https://github.com/cryptomator/cryptomator/releases/download/1.12.3/cryptomator-1.12.3-aarch64.AppImage
Cryptomator_local=cryptomator-1.12.3-aarch64.AppImage
Cryptomator_sha256=6aa1283f28f310096a3425bc58fe63f6f847801801269bf2029d60c596e13195
Cryptomator_icon_url=https://avatars.githubusercontent.com/u/11858409
Cryptomator_icon_local=cryptomator.png
Cryptomator_icon_sha256=5006e8be9c1b23cd6003239f160beac4947521e220b763ebd494fa6c9f734bb8
AppImage_Folder=$HOME/appImages/Cryptomator
Desktop_File=$HOME/.local/share/applications/Cryptomator.desktop

# $1 url
# $2 local
# $3 hash
function download_and_check () {
  url=$1
  local=$2
  hash=$3
  
  echo "Downloading [$url] to [$local]"
  if [ ! -e $local ]; then
    wget -L -O $local $url
    (($?)) && read -n1 -r -p "Can't download $url. Press enter to exit..." key && exit 1
  fi

  chmod +x $local
  (($?)) && read -t 10 -n1 -r -p "Can't change "execute" attribube on $local. You will need to do that manually. Press enter to continue or wait 10s..." key

  path="$PWD/$local"
  if [ ! -e $path ]; then
    (($?)) && read -n1 -r -p "Apparently the file at $path does not exist. This expected to be the runnable AppImage. Please try to re-run this script. Press enter to exit..." key && exit 1
  fi

  echo "$hash  $local" | sha256sum -c
  (($?)) && read -n1 -r -p "Hash mismatch of downloaded file [$local]. Press enter to continue..." key
}

function own_it() {
  file=$1
  if [ -n "$SUDO_USER" ]; then
    chown $SUDO_USER $file$
    (($?)) && read -t 10 -n1 -r -p "[chown $SUDO_USER $file] FAILED! Press enter to continue or wait 10s..." key
  fi
}

if [ ! -d $AppImage_Folder ]; then 
  mkdir -p $AppImage_Folder
  (($?)) && read -t 10 -n1 -r -p "[mkdir -p $AppImage_Folder] FAILED! Press enter to continue or wait 10s..." key
fi

pushd $PWD
cd_worked=0
cd $AppImage_Folder
(($?)) && cd_worked=1 && read -t 10 -n1 -r -p "Cannot switch to  $AppImage_Folder. Working in the current [$PWD] folder. Press enter to continue..." key

download_and_check "$Cryptomator_url" "$Cryptomator_local" "$Cryptomator_sha256"
own_it $Cryptomator_local

download_and_check "$Cryptomator_icon_url" "$Cryptomator_icon_local" "$Cryptomator_icon_sha256"
own_it $Cryptomator_icon_local

echo "Creating desktop file [$Desktop_File]"
tee $Desktop_File > /dev/null << EOL
[Desktop Entry]
Type=Application
Icon=$PWD/$Cryptomator_icon_local
Name=Cryptomator cloud encryptor
GenericName=Cryptomator
Comment=With Cryptomator, the key to your data is in your hands. Cryptomator encrypts your data quickly and easily. Afterwards you upload them protected to your favorite cloud service.
Categories=FileTools;FileManager;Utility;Core;
Exec=$PWD/$Cryptomator_local
StartupNotify=true
Terminal=false
EOL

(($?)) && read -t 10 -n1 -r -p "Creating [$Desktop_File] FAILED! Press enter to continue ot wait 10s..." key

own_it $Desktop_File
(($cd_worked)) && popd

echo "Finished Cryptomator Setup"
