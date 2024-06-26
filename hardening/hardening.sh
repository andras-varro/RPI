#!/bin/bash

# hardening.sh - A simple bash demo to disable auto login, add auto-screen-lock and disable no-password-sudo for the user.
# Copyright 2024 Andras Varro https://github.com/andras-varro
# Full screen app handling credits go to Clay Boon https://github.com/clayboone/scripts/blob/master/auto_lock_screen.sh
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

use_locker_service_for_wayland=false
script_file_name=$HOME/locker.sh
service_name="autolock.service"
service_file_name=/etc/systemd/system/$service_name

# only needed for wayland
WAYFIRE_FILE=$HOME/.config/wayfire.ini
lock_timeout_sec=130

function install_dependencies () {
  echo "  Installing dependencies."
  sudo apt update -qq -o=Dpkg::Use-Pty=0
  (($?)) && read -n1 -r -p "sudo apt update FAILED!" key
  
  if [ "$GDMSESSION" == "lightdm-xsession" ]; then
    sudo apt install -qq -o=Dpkg::Use-Pty=0 -y xautolock
    (($?)) && read -n1 -r -p "sudo apt install xautolock -y FAILED!" key
  fi
  
  if [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
    echo "    Working with LXDE-pi-wayfire"
    sudo apt install -qq -o=Dpkg::Use-Pty=0 -y  swayidle swaylock
    (($?)) && read -n1 -r -p "sudo apt install swayidle swaylock -y FAILED!" key
  fi    
  
  echo "  Finished installing dependencies."
}

function set_variables () {  
  echo "  Setting variables."
  if [ "$GDMSESSION" == "lightdm-xsession" ]; then
    lock_executable="dm-tool"
    lock_command="/usr/bin/$lock_executable lock"
    lock_service_environment="Environment=DISPLAY=:0"
    lock_command_line="/usr/bin/xautolock -noclose -time 5 -locker \"$script_file_name\" -detectsleep"
    lock_service_exec_start="ExecStart=$lock_command_line"
    lock_service_exec_stop="ExecStop=/usr/bin/xautolock -exit"
  fi
  
  if [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
    lock_executable="swaylock"
    lock_command="/usr/bin/$lock_executable -c 1A0400"
    lock_service_environment="Environment=WAYLAND_DISPLAY=$WAYLAND_DISPLAY
Environment=XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    lock_command_line="/usr/bin/swayidle -w timeout $lock_timeout_sec \"$script_file_name\""
    lock_service_exec_start="ExecStart=$lock_command_line"
    lock_service_exec_stop=""
  fi    

  echo "  Finished setting variables."  
}

function setup_wayfire_autostart_locker () {
  echo "  Setting up screen locker as wayfire autostart program."
  [ -e $WAYFIRE_FILE ] || ( read -n1 -r -p "Wayfire config file [$WAYFIRE_FILE] cannot be found. Screen saver and blanking is not set up" key && return 1 )

  if grep -q locker $WAYFIRE_FILE ; then
      sed -i "s+locker.*+locker=$lock_command_line+" $WAYFIRE_FILE
      (($?)) && read -n1 -r -p "sed -i \"s+locker.*+locker=$lock_command_line+\" $WAYFIRE_FILE FAILED!" key && return 1
  else
    if grep -q "\[autostart\]" $WAYFIRE_FILE ; then
      sed -i "s+\[autostart]+[autostart]\nlocker=$lock_command_line+" $WAYFIRE_FILE
      (($?)) && read -n1 -r -p "sed -i \"s+\[autostart]+[autostart]\nlocker=$lock_command_line+\" $WAYFIRE_FILE FAILED!" key && return 1
    else
      echo ""  >> $WAYFIRE_FILE
      (($?)) && read -n1 -r -p "echo \"\"  >> $WAYFIRE_FILE FAILED!" key && return 1
      echo "[autostart]" >> $WAYFIRE_FILE
      (($?)) && read -n1 -r -p "echo \"[autostart]\" >> $WAYFIRE_FILE FAILED!" key && return 1
      echo "locker=$lock_command_line" >> $WAYFIRE_FILE
      (($?)) && read -n1 -r -p "echo \"locker=$lock_command_line\" >> $WAYFIRE_FILE FAILED!" key && return 1
    fi
  fi

  stop_and_remove_existing_autlock_service_if_any
  echo "  Finished setting up screen locker as wayfire autostart program."
}

# disable autologin https://www.raspberrypi.org/forums/viewtopic.php?p=845309
function disable_autologin () {
  echo "  Disabling autologin."
  sudo sed -i 's/^greeter-hide-users=true/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf
  (($?)) && read -n1 -r -p "greeter-hide-users=false FAILED!" key
  
  sudo sed -i 's/^\#greeter-allow-guest=true/greeter-allow-guest=false/g' /etc/lightdm/lightdm.conf
  (($?)) && read -n1 -r -p "greeter-allow-guest=false FAILED!" key
    
  sudo sed -i 's/^\#greeter-show-manual-login=false/greeter-show-manual-login=true/g' /etc/lightdm/lightdm.conf
  (($?)) && read -n1 -r -p "greeter-show-manual-login=true FAILED!" key
  
  sudo sed -i 's/^\#allow-guest=true/allow-guest=false/g' /etc/lightdm/lightdm.conf
  (($?)) && read -n1 -r -p "allow-guest=false FAILED!" key
  
  sudo sed -i 's/^autologin-user=pi/\#autologin-user=pi/g' /etc/lightdm/lightdm.conf
  (($?)) && read -n1 -r -p "#autologin-user=pi FAILED!" key
  
  sudo rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
  (($?)) && read -n1 -r -p "delete tty autologin FAILED!" key
  
  echo "  Finished disabling autologin."
}

# lock screen: key combo: https://www.raspberrypi.org/forums/viewtopic.php?t=143559
function define_lock_screen_key_combo () {
  echo "  Defineing screen lock combo"
  if [ "$GDMSESSION" == "lightdm-xsession" ]; then
    echo "    Working with lightdm-xsession"
    config_file="$HOME/.config/openbox/lxde-pi-rc.xml"
    if [ ! -e "$config_file" ]; then
      config_file="/etc/xdg/openbox/lxde-pi-rc.xml"
    fi
    
    action="<keybind key=\"C-A-L\">\n        <action name=\"Execute\">\n            <command>$lock_command</command>\n      </action>\n    </keybind>"
    after="<keybind key=\"C-A-Left\">"
  fi
  
  if [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
    echo "    Working with LXDE-pi-wayfire"
    config_file="$HOME/.config/wayfire.ini"
    action="binding_lock = <ctrl> <alt> KEY_L\ncommand_lock = $lock_command"
    after="<ctrl> <alt> KEY_DELETE"
  fi
  
  if [ -z ${config_file+x} ]; then 
    read -n1 -r -p "Config file cannot be determined, lock-screen key combo not inserted." key
    return 1
  fi
  
  insert_text_at "$action" "$after" "$config_file"
  result=$?
  if [ $result -ne 0 ]; then
    read -n1 -r -p "Adding screen-lock combo FAILED!" key
    return 1
  fi
  
  echo "  Successfully added screen-lock combo: Ctrl+Alt+L"
  return 0
}

# $1 text to insert
# $2 text of line to insert before
# $3 target file
function insert_text_at () {
  text_to_insert="$1"
  line_to_insert_before="$2"
  target_file="$3"  
  echo "  Inserting text in file [$target_file]: text=[$text_to_insert] location=[$line_to_insert_before]"
  if [ ! -e $target_file ]; then
    read -n1 -r -p "Target file [$target_file] does not exist. [$text_to_insert] NOT inserted!" key
    return 1
  fi
  
  grep -Pzo "$text_to_insert" "$target_file" -q
  result=$?
  if [ $result -eq 0 ]; then
    echo "    [$text_to_insert] is already defined."
    return 0
  fi
  
  line_nr=$(awk "/$line_to_insert_before/ {print FNR-1}" $target_file)
  if [ "$line_nr" = "" ]; then
    read -n1 -r -p "Cannot find anchor text [$line_to_insert_before]. [$text_to_insert] NOT inserted!" key
    return 1
  fi
  
  if [ $line_nr -lt 1 ]; then 
    line_nr=1
  fi
    
  sed -i "${line_nr}a $text_to_insert" "$target_file"
  (($?)) && read -n1 -r -p "Cannot insert text, [sed -i \"${line_nr}a $text_to_insert\" $target_file] failed. [$text_to_insert] NOT inserted!" key
  
  echo "  Finished insterting [$text_to_insert] in [$target_file]."
}

# lock screen: entry in main menu: https://thepihut.com/blogs/raspberry-pi-tutorials/how-to-lock-your-raspberry-pi-screen
function add_lock_screen_to_main_menu () {
  echo "  Inserting lock screen entry in main menu"
  if [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
    read -t 10 -n1 -r -p "Inserting lock screen on Wayfire is not supported. Lock screen entry NOT inserted! Press enter or wait 10s to continue..." key
    return 1
  fi

  if [ "$GDMSESSION" == "lightdm-xsession" ]; then
    config_file=$HOME/.config/lxpanel/LXDE-pi/panels/panel
    if [ ! -e "$config_file" ]; then
      config_file=/etc/xdg/lxpanel/LXDE-pi/panels/panel
    fi

    if [ -z ${config_file+x} ]; then 
      read -n1 -r -p "Config file cannot be determined. Lock screen entry NOT inserted!" key
      return 1
    fi

    action="item {\n      image=gnome-lockscreen\n      name=Lock\n      action=/usr/bin/dm-tool lock\n    }"
    after="command=logout"

    insert_text_at $action $after $config_file
    result=$?
    if [ $result -ne 0 ]; then
      read -n1 -r -p "Inserting screen-locker entry in Main Menu FAILED!" key
      return 1
    fi

    # lock screen: reload lxpanel (reboot is needed)  https://wiki.lxde.org/en/LXPanel#Fix_empty_menu_in_LXPanel
    killall lxpanel
    (($?)) && read -n1 -r -p "killall lxpanel FAILED!" key

    find ~/.cache/menus -name '*' -type f -print0 | xargs -0 rm
    (($?)) && read -n1 -r -p "find ~/.cache/menus ... FAILED!" key

    lxpanel -p LXDE &
    (($?)) && read -n1 -r -p "lxpanel -p LXDE FAILED!" key
  fi

  echo "  Finished insering Lock screen entry in Main Menu."
}

# lock screen: autolock script https://www.raspberrypi.org/forums/viewtopic.php?t=206795
# full screen app handling credits go to Clay Boon https://github.com/clayboone/scripts/blob/master/auto_lock_screen.sh
function generate_autolock_script () {
  echo "  Generating autolock script in [$script_file_name]."
  if [ -e $script_file_name ]; then
    echo "    Deleting existing file [$script_file_name]."
    sudo rm $script_file_name
    (($?)) && read -n1 -r -p "[sudo rm $script_file_name] FAILED!" key
  
  fi
  
  touch $script_file_name
  (($?)) && read -n1 -r -p "[touch $script_file_name] FAILED!" key

  cat > $script_file_name <<'EOL'
#!/bin/bash

function get_active_window_id() {
    xprop -root | awk '$1 ~ /_NET_ACTIVE_WINDOW/ { print $5 }'
}

function is_active_window_fullscreen() {
    if [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
      # wayland does not support getting top level windows
      return 1
    fi
    
    window_id=$(get_active_window_id)
    if [ "$window_id" = "" ]; then
      echo "Current user: $(whoami) has no active window!"
      return 1
    fi
    
    xprop -id $window_id | awk -F '=' '$1 ~ /_NET_WM_STATE\(ATOM\)/ { for (i=2; i<=3; i++) if ($i ~ /FULLSCREEN/) exit 0; exit 1 }'
    return $?
}

function is_greeter_running () {
  if [ "$(pgrep LOCK_EXECUTABLE_PLACEHOLDER | wc -l)" -eq 0  ]; then
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
    export XDG_SEAT_PATH=XDG_SEAT_PATH_PLACEHOLDER
  fi
  
  if [[ -z "$WAYLAND_DISPLAY" ]]; then
	  export WAYLAND_DISPLAY=WAYLAND_DISPLAY_PLACEHOLDER
  fi

  if [[ -z "XDG_RUNTIME_DIR" ]]; then
    export XDG_RUNTIME_DIR=XDG_RUNTIME_DIR_PLACEHOLDER
  fi
	
  LOCK_COMMAND_PLACEHOLDER
fi

EOL
  (($?)) && read -n1 -r -p "[cat > $script_file_name <<'EOL'] FAILED!" key

  sed -i -e "s=LOCK_EXECUTABLE_PLACEHOLDER=$lock_executable=g" "$script_file_name"
  (($?)) && read -n1 -r -p "[sed -i -e \"s=LOCK_EXECUTABLE_PLACEHOLDER=$lock_executable=g\" \"$script_file_name\"] FAILED!" key
  
  sed -i -e "s=LOCK_COMMAND_PLACEHOLDER=$lock_command=g" "$script_file_name"
  (($?)) && read -n1 -r -p "[sed -i -e \"s=LOCK_COMMAND_PLACEHOLDER=$lock_command=g\" \"$script_file_name\"] FAILED!" key

  sed -i -e "s=XDG_SEAT_PATH_PLACEHOLDER=$XDG_SEAT_PATH=g" "$script_file_name"
  (($?)) && read -n1 -r -p "[sed -i -e \"s=XDG_SEAT_PATH_PLACEHOLDER=$XDG_SEAT_PATH=g\" \"$script_file_name\"] FAILED!" key

  sed -i -e "s=WAYLAND_DISPLAY_PLACEHOLDER=$WAYLAND_DISPLAY=g" "$script_file_name"
  (($?)) && read -n1 -r -p "[sed -i -e \"s=WAYLAND_DISPLAY_PLACEHOLDER=$WAYLAND_DISPLAY=g\" \"$script_file_name\"] FAILED!" key

  sed -i -e "s=XDG_RUNTIME_DIR_PLACEHOLDER=$XDG_RUNTIME_DIR=g" "$script_file_name"
  (($?)) && read -n1 -r -p "[sed -i -e \"s=XDG_RUNTIME_DIR_PLACEHOLDER=$XDG_RUNTIME_DIR=g\" \"$script_file_name\"] FAILED!" key
    
  chmod +x $script_file_name
  (($?)) && read -n1 -r -p "[chmod +x $script_file_name] FAILED!" key
  
  echo "  Finished generating autolock script."
}

function stop_and_remove_existing_autlock_service_if_any (){
  systemctl status $service_name > /dev/null
  result=$?
  if [ $result -eq 0 ]; then
    echo "    Stopping service [$service_name]"
    sudo systemctl stop $service_name
    (($?)) && read -n1 -r -p "[sudo systemctl stop $service_name] FAILED!" key
  fi
  
  if [ -e $service_file_name ]; then
    echo "    Deleting file [$service_file_name]"
    sudo rm $service_file_name
    (($?)) && read -n1 -r -p "[sudo rm $service_file_name] FAILED!" key
  fi
}

# lock screen: autolock service
function setup_autolock () {
  generate_autolock_script
  if ( ! $use_locker_service_for_wayland ) && [ "$GDMSESSION" == "LXDE-pi-wayfire" ]; then
    setup_wayfire_autostart_locker
    (($?)) || return 0
    read -n1 -r -p "Setting up auto lock as wayfire service FAILED! Press ENTER to setup autolock service." key
  fi

  echo "  Generating autolock service in [$service_file_name]."
  stop_and_remove_existing_autlock_service_if_any

  sudo touch $service_file_name
  (($?)) && read -n1 -r -p "[sudo touch $service_file_name] FAILED!" key

  sudo tee $service_file_name > /dev/null <<EOL
## $service_file_name
# /lib/systemd/system/

[Unit]
Description=Screen autolock

[Service]
Type=simple
$lock_service_environment
$lock_service_exec_start
$lock_service_exec_stop
Restart=always
RestartSec=10
User=pi

[Install]
WantedBy=graphical.target
EOL
  (($?)) && read -n1 -r -p "[sudo tee $service_file_name > /dev/null <<EOL] FAILED!" key

  echo "    Starting service [$service_name]"
  sudo systemctl daemon-reload
  (($?)) && read -n1 -r -p "[sudo systemctl daemon-reload] FAILED!" key

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

  echo "  Finished generating autolock service [$service_name]."
}

function disable_no_password_sudo() {
  # remove the entry like this: pi ALL=(ALL) NOPASSWD: ALL
  echo "$USER ALL=(ALL:ALL) ALL" | sudo EDITOR='tee' visudo /etc/sudoers.d/010_$USER-nopasswd
}

echo "Starting to setup locking features."
install_dependencies
set_variables
setup_screen_saver
setup_screen_blanking
disable_autologin
define_lock_screen_key_combo
add_lock_screen_to_main_menu
setup_autolock
disable_no_password_sudo
echo "Finished to setup locking features."
