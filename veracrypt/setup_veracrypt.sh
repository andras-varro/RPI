#!/bin/bash

# setup.sh - A simple bash installer for veracrypt
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

echo "Starting VeraCrypt setup."
veracrypt_url=https://launchpad.net/veracrypt/trunk/1.26.7/+download/veracrypt-1.26.7-Debian-11-arm64.deb
veracrypt_local=veracrypt-1.26.7-Debian-11-arm64.deb
veracrypt_sha256=110cb6d9ce09dbc3a6b53ac9f5648993849140574d4417fc7a877a2e401c01eb
veracrypt_source_url=https://www.veracrypt.fr/code/VeraCrypt/snapshot/VeraCrypt_1.26.7.tar.gz
veracrypt_source_local=VeraCrypt_1.26.7.tar.gz
veracrypt_source_dir=VeraCrypt_1.26.7
veracrypt_source_sha256=53572117deab4e07b4fa49105c2afff3e3960cae02bc5b2af8c9b9f4e9f9f49f
dependencies="libayatana-appindicator3-1 libfuse2 pcscd"
build_dependencies="libayatana-appindicator3-1 libfuse-dev yasm g++ make pkg-config libpcsclite-dev"

which veracrypt > /dev/null
result=$?
if [ $result -eq 0 ]; then
  echo "  Veracrypt seems to be installed. Checking..."
  veracrypt -t --version > /dev/null 2>&1
  (($?)) || read -n1 -r -p "  $(veracrypt -t --version) is already installed. Press enter to exit." key && exit 0

  echo "  Veracrpt does not work. Trying to re-install."
  sudo apt --fix-broken install -qq -o=Dpkg::Use-Pty=0 -y
  (($?)) && read -n1 -r -p "[sudo apt --fix-broken install -y] FAILED!" key
fi

development_folder_existed_before_script=1
veracrypt_folder_existed_before_script=1
cd_worked=1

if [ ! -d $HOME/development ]; then 
  mkdir $HOME/development
  (($?)) && read -n1 -r -p "[mkdir $HOME/development] FAILED!" key
  development_folder_existed_before_script=0
fi

if [ ! -d $HOME/development/veracrypt ]; then 
  mkdir $HOME/development/veracrypt
  (($?)) && read -n1 -r -p "[mkdir $HOME/development/veracrypt] FAILED!" key
  veracrypt_folder_existed_before_script=0
fi

pushd $PWD
cd $HOME/development/veracrypt
(($?)) && read -n1 -r -p "Cannot create  $HOME/development/rclone. Working in current folder. Press enter to continue..." key && cd_worked=0

build_required=0
sudo apt install -qq -o=Dpkg::Use-Pty=0 -y libwxgtk3.0-gtk3-0v5
RESULT=$?
if [ $RESULT -ne 0 ]; then
  sudo -qq -o=Dpkg::Use-Pty=0 apt install libwxgtk3.2-1
  (($?)) && read -n1 -r -p "Can't install either versions of libwxgtk3. Press enter to exit..." key && exit 1

  echo "  Can't install libwxgtk3.0-gtk3-0v5 but successfully installed libwxgtk3.2-1. There is no pre-built VeraCrypt for ARM64 for libwxgtk3.2-1. VeraCrypt needs to be built from source."
  build_required=1
  veracrypt_url=$veracrypt_source_url
  veracrypt_local=$veracrypt_source_local
  veracrypt_sha256=$veracrypt_source_sha256
  dependencies=$build_dependencies
fi

sudo apt install -qq -o=Dpkg::Use-Pty=0 -y $dependencies
(($?)) && read -n1 -r -p "Can't install dependencies. Press enter to continue..." key && exit 1

if [ ! -e $veracrypt_local ]; then
  wget -L -O $veracrypt_local $veracrypt_url
  (($?)) && read -n1 -r -p "Can't download $veracrypt_url. Press enter to exit..." key && exit 1
fi

echo "$veracrypt_sha256  $veracrypt_local" | sha256sum -c
(($?)) && read -n1 -r -p "Hash mismatch of downloaded file. Press enter to continue..." key

install_failed=0
if [ $build_required -eq 1 ]
  tar xvf $veracrypt_local
  (($?)) && read -n1 -r -p "Untar of source failed. Press enter to exit..." key && exit 1
  
  cd $veracrypt_source_dir/src
  (($?)) && read -n1 -r -p "Change dir to src failed. Press enter to exit..." key && exit 1

  # wxwidget-3.2 size warnings patch
  wget https://raw.githubusercontent.com/archlinux/svntogit-community/packages/veracrypt/trunk/wx-3.2-size-warnings.patch
  (($?)) && read -n1 -r -p "Patch download failed. Press enter to exit..." key && exit 1

  patch -p1 < wx-3.2-size-warnings.patch
  (($?)) && read -n1 -r -p "Apply patch failed. Press enter to exit..." key && exit 1

  make
  (($?)) && read -n1 -r -p "Build failed. Press enter to exit..." key && exit 1

  sudo make install
  (($?)) && install_failed=1
else
  sudo apt install -qq -o=Dpkg::Use-Pty=0 ./$veracrypt_local
  (($?)) && install_failed=1
fi

(($cd_worked)) && popd

(($development_folder_existed_before_script)) && rm -r $HOME/development
(($?)) && read -n1 -r -p "Cleanup has failed. Unable to delete $HOME/development. Press enter to continue..." key

(($install_failed)) || echo "$(veracrypt -t --version) was installed. if the mounting does not work, disable kernel crypto." && exit 0

read -n1 -r -p "Installation FAILED! Press enter to continue..." key
exit 1
