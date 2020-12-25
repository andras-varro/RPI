#!/bin/bash

# cryptomator.sh - A simple bash demo wrapper around the cryptomator CLI
# Copyright 2020 Andras Varro https://github.com/andras-varro
# V20201225
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

max_iteration=7
password_file_name=$RANDOM$RANDOM$RANDOM
share_ip_address=127.0.0.1
share_port=8080
mount_location=/home/pi/cryptomator
cryptomator_jar=cryptomator-cli-0.4.0.jar
trace_level=0
davfs_secrets_file=/etc/davfs2/secrets
recents_file=recents
new_vault_prompt='New vault'
quit_prompt='Quit'
curl_params="-f"

function start_cryptomator () {
  user_message "Working on vault [$vault_name]. Please wait." "0"
  echo "$password" > "$password_file_name"
  if [ $trace_level -ge 1 ]; then
    java -jar "$cryptomator_jar" --vault "$vault_name=$vault_path" --passwordfile "$vault_name=$password_file_name" --bind $share_ip_address --port $share_port &
  else
    java -jar "$cryptomator_jar" --vault "$vault_name=$vault_path" --passwordfile "$vault_name=$password_file_name" --bind $share_ip_address --port $share_port  > /dev/null 2>&1 &
  fi
  cryptomator_pid=$!
}

function stop_cryptomator () {
  if [ "$1" = "" ]; then return 1; fi
  kill "$1"
  result=$?
  while [ $result -ne 0 ]; do 
    user_message "Error! Unable to stop cryptomator. PID: [$1], vault: [$vault_name]." "0"
    read -n 1 -s -r -p "Press enter to retry."
    sudo kill "$1"
    result=$?
  done
}

# $1 = message (reason)
# $2 = trace level
# $3 = cryptomator PID
function stop_cryptomator_and_exit () {
  if [ "$1" != "" ]; then user_message "$1" "$2"; fi
  press_enter_to "stop cryptomator" "$2"
  stop_cryptomator "$3"
  press_enter_to_exit "1" "0"
}

# $1 = message
# $2 = trace level
function press_enter_to () {
  if [ "$1" != "" ]; then user_message "Press enter to $1" "$2"; fi
  read -n 1 -s -r
  echo ""
  return 0
}

# $1 = exit code
# $2 = trace level
function press_enter_to_exit () {
  press_enter_to "$quit_prompt" "$2"
  exit "$1"
}

# $1 = message, 
# $2 = trace level
function user_message () {
  if [ "$1" = "" ]; then return 1; fi
  if [ "$2" != "" ] && [ "$2" -gt $trace_level ]; then return 2; fi
  echo "$1"
  return 0
}

function set_verbosity () {
  if [ $trace_level -lt 2 ]; then
    curl_params="-fs"
  fi
}

cd "${0%/*}" || exit 1
set_verbosity
if [ ! -e "$cryptomator_jar" ]; then
  user_message "Cryptomator cli file [$cryptomator_jar] cannot be found." "0"
  user_message "You can download the latest version from: " "0"
  user_message "https://github.com/cryptomator/cli/releases" "0"
  press_enter_to_exit "1" "0"
fi

# Support for recents
if [ "$recents_file" != "" ] && [ -e "$recents_file" ]; then
  mapfile -t recent_array < "$recents_file"
  recent_array+=("$new_vault_prompt")
  recent_array+=("$quit_prompt")
  PS3='Please enter your choice: '
  select option in "${recent_array[@]}"
  do
      case "$option" in
          "$new_vault_prompt")
              read -r -p "Please enter the path to the vault directory: " vault_path
              break;
              ;;
          "$quit_prompt")
              press_enter_to_exit "1" "0"
              ;;
          "")            
              user_message "Invalid selection" "0"
              ;;
          *)
              vault_path="$option"
              break;
              ;;
      esac
  done 
else
  read -r -p "Please enter the path to the vault directory: " vault_path
fi

user_message "Selected vault path: $vault_path" "2"

if [ -e "$vault_path/masterkey.cryptomator" ]; then
    user_message "Masterkey for vault $vault_path found." "2"
    # Support for recent
    if [ "$recents_file" != "" ]; then
      if [ ! -e "$recents_file" ]; then 
        user_message "Recents file [$recents_file] not found, creating new." "2"
        touch "$recents_file" 
      fi
      grep ^"$vault_path" "$recents_file" -q
      result=$?
      if [ $result -ne 0 ]; then
        user_message "Adding vault [$vault_path] to recents file [$recents_file]" "2"
        echo "$vault_path" >> "$recents_file"
      fi
    fi
else
    user_message "No masterkey for vault $vault_path was found." "0"
    press_enter_to_exit "1" "0"
fi

# get the name for the share from directory name
IFS='/' 
read -ra directories <<< "$vault_path"
for i in "${directories[@]}"; do 
    vault_name=$i
done
IFS=' '

read -s -r -p "Please enter the vault password: " password
echo
start_cryptomator
user_message "Cryptomator PID: $cryptomator_pid" "2"
iteration=1
success=0
# wait for share
user_message "curl http://$share_ip_address:$share_port/$vault_name $curl_params" "2"
curl "http://$share_ip_address:$share_port/$vault_name" "$curl_params"
result=$?
while [ $result -ne 0 ]; do 
  if [ $iteration -gt $max_iteration ]; then
	  user_message "Timeout" "0"
	  success=1	  
	  break;
	fi
  iteration=$((iteration+1))
  sleep 1;
  user_message "Waiting for share $iteration/$max_iteration" "1"
  user_message "curl http://$share_ip_address:$share_port/$vault_name $curl_params" "2"
  curl "http://$share_ip_address:$share_port/$vault_name" "$curl_params"
  result=$?
done

rm -f $password_file_name
result=$?
if [ $result -ne 0 ]; then
  user_message "WARNING! Unable to delete password file: $password_file_name." "0"
  user_message "Please remove the file manually." "0"
  press_enter_to "continue." "0"
fi

if [ $success -ne 0 ]; then
  stop_cryptomator_and_exit "ERROR Unable to connect to share." "0" "$cryptomator_pid"
fi

user_message "Vault [$vault_name] decrypted successfully and published at: [$share_ip_address:$share_port]" "1"
mount_point="$mount_location/$vault_name"

if [ ! -d "$mount_point" ]; then
  sudo mkdir "$mount_point"
  result=$?
  if [ $result -ne 0 ]; then
    stop_cryptomator_and_exit "Error! Unable to create mount point: $mount_point" "0" "$cryptomator_pid"
  fi
fi

user_message "Vault [$vault_name] will be mounted at [$mount_point]." "1"

if [ ! -e $davfs_secrets_file ]; then
  user_message "DavFS' secrets file [$davfs_secrets_file] does not exist. Make sure the configuration file exist at this location." "0"
  user_message "Mounting will ask for a user name and a password. Press enter for both questions." "0"
else
  sudo grep ^"http://$share_ip_address:$share_port/$vault_name/" $davfs_secrets_file -q
  result=$?
  if [ $result -ne 0 ]; then
    user_message "http://$share_ip_address:$share_port/$vault_name/ not found in $davfs_secrets_file, adding line with empty password" "2"
    echo "http://$share_ip_address:$share_port/$vault_name/ \" \" \" \"" | sudo tee -a $davfs_secrets_file > /dev/null
  fi
fi

sudo mount -t davfs "http://$share_ip_address:$share_port/$vault_name/" "$mount_point" -o user,rw,uid="$(id -u)",gid="$(id -g)"
result=$?
if [ $result -eq 0 ]; then
  user_message "Vault [$vault_name] decrypted and mounted successfully at [$mount_point]." "0"
  press_enter_to "unmount and close vault." "0"
  sudo umount "$mount_point"
  result=$?
  while [ $result -ne 0 ]; do 
    user_message "Error code: $result" "1"
    if [ $result -eq 32 ]; then
      user_message "Vault is not mounted" "0"
      break;
    fi
  
    user_message "ERROR! Unable to unmount vault [$vault_name]." "0"
    user_message "Please close all terminals and applications that are using files or folders from the vault." "0"
    press_enter_to "retry." "0"
    sudo umount "$mount_point"
    result=$?
  done
else
  user_message "Vault [$vault_name]: mount failed" "0"
  press_enter_to "close vault." "0"
fi

stop_cryptomator $cryptomator_pid

user_message "Vault [$vault_name] was successfully closed" "0"
sleep 2
