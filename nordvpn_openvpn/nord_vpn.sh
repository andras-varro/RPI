#!/bin/bash

# nord_vpn.sh - A simple bash demo setup and configurator for openvpn with Nord VPN
# Copyright 2020 Andras Varro https://github.com/andras-varro
# V20210103
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

openvpn_user_folder=/home/pi/openvpn
supported_countries_list=$openvpn_user_folder/countries.lst
openvpn_folder=/etc/openvpn
trace_level=0

# $1 = message, 
# $2 = trace level
function user_message () {
  if [ "$1" = "" ]; then return 1; fi
  if [ "$2" != "" ] && [ "$2" -gt $trace_level ]; then return 2; fi
  echo "$1"
  return 0
}

# $1 = exit code
# $2 = do not wait for keypress
function exit_script () {
  if [ "$2" != "1" ]; then
    read -n 1 -s -r
    echo ""
  fi
  
  exit $1
} 

# No parameters
function get_credentials () {
  touch "$openvpn_folder"/auth.txt
  read -r -p "Please specify the VPN user name: " username
  echo "$username" | sudo tee -a "$openvpn_folder"/auth.txt > /dev/null
  read -r -sp "Please specify the VPN password: " password
  echo "$password" | sudo tee -a "$openvpn_folder"/auth.txt > /dev/null
}


# No parameters
function get_nord_vpn_definitions () {
  cd "$openvpn_folder"
  user_message "Current directory: [$PWD]" "2"
  wget https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip
  unzip ovpn.zip
  rm ovpn.zip
}


# No parameters
function select_a_vpn_country () {
	if [ ! -e "$supported_countries_list" ]; then
	  user_message "No supported countries list is available" "0"
	  return 1
	fi
	
	user_message "Reading $supported_countries_list" "2"
	mapfile -t countries_array < "$supported_countries_list"
	PS3='Please select a VPN country: '
	select option in "${countries_array[@]}"
	do
		case "$option" in        
			"")
				user_message "Invalid selection" "0"
				;;
			*)
				selected_country="$option"
				break;
				;;
		esac
	done
	
	user_message "Selected country: $selected_country" "1"
	return 0 
}


# No parameters
function create_openvpn_user_folder () {
  if [ ! -e "$openvpn_user_folder" ]; then 
    mkdir "$openvpn_user_folder"
  fi
  
  return 0
}


# $1 "1"="reuse existing"
function create_list_of_supported_countries () {
  create_openvpn_user_folder
  if [ -e "$supported_countries_list" ]; then
    if [ "$1" != "1" ]; then
      rm "$supported_countries_list"
    else
      return 0
    fi
  fi
  
  touch "$supported_countries_list"
  if [ ! -e "$openvpn_folder/ovpn_udp/" ]; then
    user_message "Folder [$openvpn_folder/ovpn_udp/] does not exist. Exiting." "0"
    exit_script 1
  fi
  
  cd "$openvpn_folder/ovpn_udp/" || exit 1
  user_message "Current directory: [$PWD]" "2"
  for file in *.ovpn; do
    if [ "$last_country" != ${file:0:2} ]; then 
      last_country=${file:0:2};
      echo "$last_country" >> "$supported_countries_list";
    fi;
  done
  
  return 0
}


# $1 country abbreviation
function add_to_favorites () {
  if [ "$1" = "" ]; then
    user_message "No country is specified to add to favorites." "0"
    return 1
  fi
  
  user_message "Adding [$1] to favorites [$supported_countries_list]" "2"
  create_openvpn_user_folder
  if [ ! -e "$supported_countries_list" ]; then
    user_message "[$supported_countries_list] does not exist adding [$1] to the file" "1"
    echo "$1" > "$supported_countries_list"
    return 0
  fi
  
  user_message "Reading [$supported_countries_list]" "2"
  mapfile -t countries_array < "$supported_countries_list"
  user_message "Re-writing [$supported_countries_list] with [$1] at the top" "2"
  echo "$1" > "$supported_countries_list"
  for country in ${countries_array[@]}; do
    if [ "$country" == "$1" ]; then
      continue
    fi
     
    echo "$country" >> "$supported_countries_list"
  done
  
  return 0
}


# $1 country abbreviation
function select_random_ovpn_config_for_country () {
  if [ "$1" = "" ]; then
    user_message "Error: No country is specified to select random ovpn config for. Exiting." "0"
    exit_script 1
  fi
  
  if [ ! -e "$openvpn_folder/ovpn_udp/" ]; then
    user_message "Folder [$openvpn_folder/ovpn_udp/] does not exist. Exiting." "0"
    exit_script 1
  fi
  
  cd "$openvpn_folder/ovpn_udp/" || exit 1
  user_message "Current directory: [$PWD]" "2"
  user_message "Selecting a random config file for [$1]" "1"
  selected_country_array=($1*.ovpn)
  selected_country_array_length=${#selected_country_array[@]}
  user_message "Found [$selected_country_array_length] different openvpn configurations for code [$1]" "1"
  random_array_element=$(( $RANDOM % $selected_country_array_length ))
  user_message "Using the [$random_array_element]. configuration" "2"
  selected_default_file=${selected_country_array[random_array_element]}
  if [ "$selected_default_file" == "" ]; then
    user_message "Error: No file is selected for country [$1]. Exiting." "0"
    exit_script 1
  fi
  
  if [ ! -e "$selected_default_file" ]; then
    user_message "Selected random config file [$selected_default_file] does not exist. Exiting." "0"
    exit_script 1
  fi
  
  user_message "Selected random config file is [$selected_default_file]" "1"
  return 0
}


# $1 country to use
function configure_openvpn_autostart_and_restart_openvpn_service () {
  if [ "$1" = "" ]; then
    user_message "No country is specified to configure openvpn for. Exiting." "0"
    exit_script 1
  fi

  user_message "Patching openvpn configuration" "1"
  grep '#AUTOSTART="all"' /etc/default/openvpn -q
  result=$?
  if [ $result -eq 0 ];then
    user_message "Performing first patch of /etc/default/openvpn" "2"
    sed -i "s/#AUTOSTART=\"all\"/AUTOSTART=\"$1\"/g" /etc/default/openvpn
  else
    user_message "Performing delta patch of /etc/default/openvpn" "2"
    sed -i "s/^AUTOSTART=\"..\"/AUTOSTART=\"$1\"/g" /etc/default/openvpn
  fi
  
  user_message "Reloading openvpn service and restarting openvpn service" "1" 
  stop_openvpn
  systemctl daemon-reload
  systemctl start openvpn
}

# $1 source file
# $2 target file
function patch_and_copy_ovpn_config () {
  if [ "$1" = "" ] || [ ! -e "$1" ]; then
    user_message "File: [$1] not found." "0"
    return 1
  fi
  
  cd "$openvpn_folder/ovpn_udp/"
  user_message "Current directory: [$PWD]" "2"
  user_message "Patching [$1]" "1"
  grep "auth-user-pass $openvpn_folder/auth.txt" "$1" -q
  result=$?
  if [ $result -eq 0 ]; then
    user_message "[%1] already patched for auth.txt" "2"
  else
    sed -i "s+auth-user-pass+auth-user-pass $openvpn_folder/auth.txt+g" "$1"
  fi
  
  grep "explicit-exit-notify 3" "$1" -q
  result=$?
  if [ $result -eq 0 ]; then
    user_message "[%1] already patched for explicit-exit-notify" "2"
  else
    sh -c "echo explicit-exit-notify 3 >> $1"
  fi 

  cp "$1" "$2"
  result=$?
  if [ $result -ne 0 ]; then 
    user_message "cp [$1] [$2] failed" "1"
    return 2
  fi
  
  user_message "cp [$1] [$2] succeded" "2"
  return 0
}


# No parameters
function configure_dhcp () {
  user_message "Patching etc/dhcpcd.conf for domain_name_servers=8.8.8.8" "1"
  grep "domain_name_servers=8.8.8.8" "etc/dhcpcd.conf" -q
  result=$?
  if [ $result -eq 0 ]; then
    user_message "etc/dhcpcd.conf already patched for domain_name_servers=8.8.8.8" "2"
  else
    sh -c "echo static domain_name_servers=8.8.8.8 >> /etc/dhcpcd.conf"
    user_message "Restarting dhcpcd service" "1"
    systemctl restart dhcpcd
  fi 
}


# No parameters
function setup_vpn () {
  user_message "This will setup Nord VPN with OpenVPN. Please press enter to continue. Ctrl+C anytime breaks the script." "0"
  read -n 1 -s -r
  echo ""
  apt-get install openvpn unzip -y
  get_credentials
  get_nord_vpn_definitions
  create_list_of_supported_countries
  return 0
}

# No parameters
function stop_openvpn () {
  openvpn_processes=($(pgrep openvpn))
  for pid in ${openvpn_processes[@]}; do 
    user_message "Killing openvpn process: $pid" "2"
    kill -SIGTERM "$pid"
  done

  return 0
}


# No parameters
function start_or_change_vpn () {
  select_a_vpn_country
  add_to_favorites "$selected_country"
  select_random_ovpn_config_for_country "$selected_country" 
  patch_and_copy_ovpn_config "$selected_default_file" "../$selected_country.conf"
  configure_openvpn_autostart_and_restart_openvpn_service "$selected_country"
  return 0
}

cd "${0%/*}" || exit 1
if [ "$EUID" -ne "0" ]; then
  user_message "Please start script with sudo." "0"
  exit 1
fi

if [ "$1" == "setup" ]; then
  setup_vpn
fi

start_or_change_vpn
user_message "Switched to $selected_country" "0"
exit_script 0 1
