# setup_lockscreen
------------------

Raspberry OS/Raspbian comes with a nice and light user interface and autologin. Locking the UI was also not in scope for the default skin.

# Features:
* Disable auto log-in
* Disable guest log-in
* Defines Ctrl+Alt+L to lock the screen
* Creates a 'Lock' entry in the Main Menu
* Generates a service to lock the screen after 5 minutes of inactivity unless:
  * Full screen application is running
  * Audio is played
  * It is already locked

# Requires:
* lxde (this is the default ui of Raspberry OS)
* sed, grep, awk, killall, xprop, pi-greeter: these are pre-installed with the standard Raspbian
* sudo rights

# How to use:
1. Make sure you have sudo rights
2. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x setup_lockscreen.sh
```
3. Execute the script ./setup_lockscreen.sh

# Configuration:

The script has not much configuration potential. Maybe in future versions.

# Troubleshooting
If something doesn't work out, read the output and ask for help.

# Disclaimer:
This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

# Thank you:
Kudos to Clay Boon https://github.com/clayboone/scripts/blob/master/auto_lock_screen.sh for the great script

