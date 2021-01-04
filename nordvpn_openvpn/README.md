# nordvpn_openvpn

For noobs like me it is not straightforward how to configure openvpn (Open VPN software) even with readily available configuration scripts. This example/demo scrips sets up and configures openvpn with Nord VPN A-Z. 

Features:
* Setup of openvpn (and unzip as well)
* Download Nord VPN config files (from nordvpn's website)
* Input Nord VPN user name and password
* Patch openvpn definitions with user name and password
* Enable explicit exit notify to make sure client side close of the VPN conection also closes the conection on the server side
* List available countries to select one to connect to and randomly select one config for the selected country
* Support for "recent" countries by ading the recently used countries to the top of the list
* "Easily" configurable
* Some error handling

Requires:
* openvpn and unzip (the script installs these components)
* sudo rights

How to use:
1. Make sure you have sudo rights
2. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x nord_vpn.sh
```
3. To set-up: 
  * Open a terminal window and start script:
```
sudo ./nord_vpn.sh setup
```
  * At the prompt, enter the Nord VPN user and password. These will be saved in the auth.txt (normally: /etc/openvpn/auth.txt)
  * The script then will download the openvpn configurations for Nord VPN (from Nord VPN's website). This is a larger zip (like 25Mb) and takes time to download.
  * Aterwards the script extracts the contents of the downloaded zip an using the **udp** configs, creates a list of the available countries
  * For the next steps please see 'To configure VPN'
4. To configure VPN:
  * Make sure you finished the steps in point 'To set-up'
  * Open a terminal window and start script:
```
sudo ./nord_vpn.sh
```
  * The script shows a list of the possible countries. Select the one you want to conect to.
  * If everything is fine, the script exits. Check your IP Address with your favorite site (like ipleak.net)

Configuration:

The script has a configuration section at the top. The most important variables are the following:
* `openvpn_user_folder`: Sets the folder for user specific settings (default: /home/pi/openvpn)
* `supported_countries_list`: Sets the location of the supported countries list (default: $openvpn_user_folder/countries.lst)
* `openvpn_folder`: Defines the location of the openvpn configuration folder (default: /etc/openvpn)
* `trace_level`: sets the verbosity of the script on the 0..2 scale (default: 0)

Troubleshooting
* If something doesn't work out, first try to set the trace_level to 2 and read the messages

Disclaimer:
1. This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
2. I am not affiliated with openvpn, also not with Nord VPN. Please support their work!
