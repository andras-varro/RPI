#!/bin/bash

# setup_lockscreen.sh - A simple bash demo to disable auto login for RPI and insert screen logginf functions
# Copyright 2021 Andras Varro https://github.com/andras-varro
# Full screen app handling credits go to Clay Boon https://github.com/clayboone/scripts/blob/master/auto_lock_screen.sh
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

# disable autologin https://www.raspberrypi.org/forums/viewtopic.php?p=845309
function disable_autologin () {
  sudo sed -i 's/^greeter-hide-users=true/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf
  sudo sed -i 's/^\#greeter-allow-guest=true/greeter-allow-guest=false/g' /etc/lightdm/lightdm.conf
  sudo sed -i 's/^\#greeter-show-manual-login=false/greeter-show-manual-login=true/g' /etc/lightdm/lightdm.conf
  sudo sed -i 's/^\#allow-guest=true/allow-guest=false/g' /etc/lightdm/lightdm.conf
  sudo sed -i 's/^autologin-user=pi/\#autologin-user=pi/g' /etc/lightdm/lightdm.conf
}

# lock screen: key combo: https://www.raspberrypi.org/forums/viewtopic.php?t=143559
function define_lock_screen_key_combo () {
  config_file=/home/pi/.config/openbox/lxde-pi-rc.xml
  if [ ! -e "$config_file" ]; then
    config_file=/etc/xdg/openbox/lxde-pi-rc.xml
  fi

  if [ ! -e "$config_file" ]; then
    echo "Config file for LXDE [$config_file] cannot be found, lock-screen key combo not inserted."
    return 1
  fi
  
  insert_screen_lock_combo_at "C-A-L" "<keybind key=\"C-A-Left\">"    
}

# $1 shortcut
# $2 text of line to insert shortcut before
function insert_screen_lock_combo_at () {
  new_shortcut="$1"
  line_to_insert_before="$2"
  grep "<keybind key=\"${new_shortcut}\">" $config_file -q
  result=$?
  if [ $result -eq 0 ]; then
    echo "$new_shortcut shortcut is already defined."
    return 0
  fi
  
  echo "Creating new shortcut $new_shortcut"
  line_nr=$(awk "/$line_to_insert_before/ {print FNR-1}" $config_file)
  if [ "$line_nr" = "" ]; then
    echo "Cannot found anchor text [$line_to_insert_before] for lock screen combo, lock-screen combo not created."
    return 1
  fi
  
  if [ $line_nr -lt 1 ]; then 
    line_nr=1
  fi
    
  sed -i "${line_nr}a    <keybind key=\"${new_shortcut}\">\n        <action name=\"Execute\">\n            <command>/usr/bin/dm-tool lock</command>\n      </action>\n    </keybind>" $config_file
  result=$?
  if [ $result -ne 0 ]; then
    echo "Cannot modify key bindings, sed failed, lock-screen combo not created."
    return 1
  fi
  
  openbox --reconfigure
  echo "[$new_shortcut] is defined for locking the screen"
}

# lock screen: entry in main menu: https://thepihut.com/blogs/raspberry-pi-tutorials/how-to-lock-your-raspberry-pi-screen
function add_lock_screen_to_main_menu () {
  config_file=/home/pi/.config/lxpanel/LXDE-pi/panels/panel
  if [ ! -e "$config_file" ]; then
    config_file=/etc/xdg/lxpanel/LXDE-pi/panels/panel
  fi
  
  if [ ! -e "$config_file" ]; then
    echo "Config file for Main Menu [$config_file] cannot be found, lock-screen entry not inserted."
    return 1
  fi
  
  grep "action=/usr/bin/dm-tool lock" $config_file -q
  result=$?
  if [ $result -eq 0 ]; then
    echo "Screen locker already available in Main Menu."
    return 0
  fi
  
  grep "command=logout" $config_file -q 
  result=$?
  if [ $result -ne 0 ]; then
    echo "Cannot found anchor text for lock screen entry in Main Menu, lock-screen entry not inserted."
    return 1
  fi
  
  line_nr=$(awk /'command=logout/ {print FNR+1}' $config_file)
  if [ "$line_nr" = "" ]; then
    echo "Cannot found anchor text for lock screen entry in Main Menu, lock-screen entry not inserted."
    return 1
  fi
  
  if [ $line_nr -lt 1 ]; then 
    line_nr=1
  fi
  
  sudo sed -i "${line_nr}a  item {\n      image=gnome-lockscreen\n      name=Lock\n      action=/usr/bin/dm-tool lock\n    }" $config_file
  result=$?
  if [ $result -ne 0 ]; then
    echo "Cannot modify Main Menu, sed failed, lock-screen entry not inserted."
    return 1
  fi
  
  # lock screen: reload lxpanel (reboot is needed)  https://wiki.lxde.org/en/LXPanel#Fix_empty_menu_in_LXPanel
  killall lxpanel
  find ~/.cache/menus -name '*' -type f -print0 | xargs -0 rm
  lxpanel -p LXDE &
  echo "[Lock] entry was successfully created in Main Menu."
}

# lock screen: autolock script https://www.raspberrypi.org/forums/viewtopic.php?t=206795
# full screen app handling credits go to Clay Boon https://github.com/clayboone/scripts/blob/master/auto_lock_screen.sh
function generate_autolock_script () {
  script_file_name=/home/pi/locker.sh
  if [ -e $script_file_name ]; then
    echo "Deleting file [$script_file_name]"
    sudo rm $script_file_name
  fi

  touch $script_file_name
  cat > $script_file_name <<'EOL'
#!/bin/bash

function get_active_window_id() {
    xprop -root | awk '$1 ~ /_NET_ACTIVE_WINDOW/ { print $5 }'
}

function is_active_window_fullscreen() {
    window_id=$(get_active_window_id)
    if [ "$window_id" = "" ]; then
      echo "Current user: $(whoami) has no active window!"
      return 1
    fi
    
    xprop -id $window_id | awk -F '=' '$1 ~ /_NET_WM_STATE\(ATOM\)/ { for (i=2; i<=3; i++) if ($i ~ /FULLSCREEN/) exit 0; exit 1 }'
    return $?
}

function is_greeter_running () {
  if [ "$(pgrep pi-greeter | wc -l)" -eq 0  ]; then
    # Not running
    return 1
  fi
  
  # Greeter is runing
  return 0
}

function is_audio_played () {
  if [ "$(grep -r "RUNNING" /proc/asound | wc -l)" -eq 0 ]; then
    # Not played
    return 1
  fi
  
  # Audio is being played
  return 0
}

function should_lock () {    
    if is_active_window_fullscreen; then 
      return 1
    fi
    
    if is_greeter_running; then
      return 1
    fi
    
    if is_audio_played; then
      return 1
    fi
    
    return 0  
}

if should_lock; then 
  if [[ -z "$XDG_SEAT_PATH" ]]; then
    export XDG_SEAT_PATH=/org/freedesktop/DisplayManager/Seat0
  fi
	
  /usr/bin/dm-tool lock
fi

EOL

  chmod +x $script_file_name
}


# lock screen: autolock service
function generate_autolock_service () {
  generate_autolock_script
  service_file_name=/etc/systemd/system/autolock.service
  if [ -e $service_file_name ]; then
    echo "Stopping service [$service_file_name]"
    sudo systemctl stop autolock.service
    echo "Deleting file [$service_file_name]"
    sudo rm $service_file_name
  fi

  sudo touch $service_file_name
  sudo tee $service_file_name > /dev/null <<EOL
## /etc/systemd/system/autolock.service
# /lib/systemd/system/

[Unit]
Description=Screen autolock

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/bin/xautolock -noclose -time 5 -locker "/home/pi/locker.sh" -detectsleep
ExecStop=/usr/bin/xautolock -exit
Restart=always
RestartSec=10
User=pi

[Install]
WantedBy=default.target
EOL

  sudo systemctl daemon-reload
  sudo systemctl enable autolock.service
  sudo systemctl start autolock.service
}

disable_autologin
define_lock_screen_key_combo
add_lock_screen_to_main_menu
generate_autolock_service
