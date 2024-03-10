#!/bin/bash

# tweaks.sh - A simple bash prgram to execute tweaks for the user. Mainly Wayland/Wayfire related settings.
# Copyright 2024 Andras Varro https://github.com/andras-varro
# V20240309
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

WAYFIRE_FILE=$HOME/.config/wayfire.ini
blank_timeout_sec=600
screensaver_timeout=120

# $1 setting's name
# $2 setting's value
# $3 setting's group
function set_value_in_wayfire_file (){
  settings_name=$1
  settings_value=$2
  settings_group=$3
  if [ "$GDMSESSION" == "lightdm-xsession" ]; then
    echo "  This is not supported under LightDM."
    retun 0
  fi
  
  if [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
    [ -e $WAYFIRE_FILE ] || ( read -n1 -r -p "Wayfire config file [$WAYFIRE_FILE] cannot be found. Setting is not performed." key && return 1 )
    
    echo "  Setting [$settings_group] $settings_name=$settings_value in [$WAYFIRE_FILE]."  
    if grep -qE "^$settings_name *=" $WAYFIRE_FILE ; then
        sed -i "s/$settings_name *=.*/$settings_name=$settings_value/" $WAYFIRE_FILE
        (($?)) && read -n1 -r -p "sed -i \"s/$settings_name *=.*/$settings_name=$settings_value/\" $WAYFIRE_FILE FAILED!" key
    else
      if grep -q "\[$settings_group\]" $WAYFIRE_FILE ; then
        sed -i "s/\[$settings_group]/[$settings_group]\n$settings_name=$settings_value/" $WAYFIRE_FILE
        (($?)) && read -n1 -r -p "sed -i \"s/\[$settings_group]/[$settings_group]\n$settings_name=$settings_value/\" $WAYFIRE_FILE FAILED!" key
      else
        echo ""  >> $WAYFIRE_FILE
        (($?)) && read -n1 -r -p "echo \"\"  >> $WAYFIRE_FILE FAILED!" key
        echo "[$settings_group]" >> $WAYFIRE_FILE
        (($?)) && read -n1 -r -p "echo \"[$settings_group]\" >> $WAYFIRE_FILE FAILED!" key
        echo "$settings_name=$settings_value" >> $WAYFIRE_FILE
        (($?)) && read -n1 -r -p "echo \"$settings_name=$settings_value\" >> $WAYFIRE_FILE FAILED!" key
      fi
    fi

    echo "  done."
  fi      
}

# Set screen-blanking timeout
set_value_in_wayfire_file "dpms_timeout" $blank_timeout_sec "idle"

# Set screen-saver timeout
set_value_in_wayfire_file "screensaver_timeout" $screensaver_timeout "idle"

# Fix Alt-Tab behavior
set_value_in_wayfire_file "activate_backward" "<alt> <shift> KEY_TAB" "fast-switcher"
set_value_in_wayfire_file "activate" "<alt> KEY_TAB" "fast-switcher"
set_value_in_wayfire_file "prev_view" "<alt> <shift> KEY_ESC" "switcher"
set_value_in_wayfire_file "next_view" "<alt> KEY_ESC" "switcher"
