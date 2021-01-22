# make-it-ap
------------------

Raspberry PI (with Raspbian) as an access point? 

# Features:
* Installs needed software
* Configures the system to work as an AP
* Sets up routing from TUN ('VPN') to the WLAN interface (see commented line to use w/o TUN)

# Requires:
* sed, iptables: these are pre-installed with the standard Raspbian
* hostapd, dnsmasq: the script install these
* sudo rights

# How to use:
1. Make sure you have sudo rights
2. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x make-it-ap.sh
```
3. Execute the script ./make-it-ap.sh

# Configuration:

The script has not much configuration potential. Maybe in future versions.

# Troubleshooting
If something doesn't work out, read the output and ask for help.

# Disclaimer:
This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
