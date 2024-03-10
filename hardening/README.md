# hardening

Raspberry OS/Raspbian comes with a nice and light user interface and autologin. Typing login password, locking the UI and requiring sudo password form the user is not required by default.

## Features:

* Supports both wayland and lightdm
* Disable auto log-in
* Disable guest log-in
* Defines Ctrl+Alt+L to lock the screen
* Creates a 'Lock' entry in the Main Menu (not yet supported under Wayland/Wayfire)
* Generates a service (or an autostart entry in wayfire) to lock the screen after 2 minutes of inactivity unless:
  * Full screen application is running (not yet supported under Wayland/Wayfire)
  * Audio is played
  * It is already locked

## Requires:

* lightdm or Wayland/Wayfire (this is the default ui of Raspberry OS)
* sed, grep, awk, killall, xprop, pi-greeter: these are pre-installed with the standard Raspbian
* sudo rights

## How to use:

1. Make sure you have sudo rights
2. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x hardening.sh
```
3. Execute the script ./hardening.sh

## Configuration:

The script has a configuration section at the beginning.

## Troubleshooting

If something doesn't work out, read the output and please raise an issue.

## Disclaimer:
This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

## Thank you:
Kudos to Clay Boon https://github.com/clayboone/scripts/blob/master/auto_lock_screen.sh for the great script

