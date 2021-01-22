# cryptomator_wrap
------------------
As of today, there is no GUI available for the popular cryptomator tool for ARM Linux (like Raspberry OS/Raspbian). The developement team of cryptomator, however, released a command line interface (cli) that can open cryptomator vaults. This script is a `demo` wrapper for this cryptomator cli. 

# Features:
* Download cryptomator CLI and instal java and davfs2 if started with the `setup` parameter
* Input for vault location
* Input for vault passphrase
* Automount with DAVFS2
* Support for "recent vaults" (not for passphrases!)
* "Easily" configurable
* Some error handling
* Unmount and stop cryptomator

# Requires:
* davfs2 (sudo apt install davfs2)
* cryptomator cli (wget https://github.com/cryptomator/cli/releases/download/0.4.0/cryptomator-cli-0.4.0.jar)
* java to run cryptomator
* sudo rights

# How to use:
method A:
1. Make sure the required components are available
2. Copy the script in the same folder where the cryptomator cli jar file is located
3. Make the script executable (chmod +x cryptomator.sh)

method B:
1. Start script with the `setup` switch

Execute the script and follow the on-screen instructions
 * At the first start there is only two options available: open a new vault or exit
 * The new vault has to be specified by it's path, for instance `Please enter the path to the vault directory: /home/pi/vaults/top_secret_vault`. The script checks for the `masterkey.cryptomator` availabilty under this path
 * Next the script asks for the password for the vault
 * If the vault is healthy and the password is correct the script mounts the decrypted vault and displays the information about this. For instance: `Vault [top_secret_vault] decrypted and mounted successfully at [/home/pi/cryptomator/top_secret_vault]`
 * To unmount and close the vault, press enter.

# Configuration:

The script has a configuration section at the top. The most important variables are the following:
* `share_ip_address`: the address that will be used to publish the decrypted vault at (default: 127.0.0.1)
* `share_port`: port for the webdav server (default: 8080)
* `mount_location`: the location where the script mounts the webdav server (default: /home/pi/cryptomator)
* `cryptomator_jar`: name of the cryptomator cli jar file (default: cryptomator-cli-0.4.0.jar)
* `trace_level`: sets the verbosity of the script on the 0..2 scale (default: 0)
* `davfs_secrets_file`: location of the davfs2 secrets file. The script generates an entry in this file for the share with empty password and user, so that the mount does not ask you to press enter two times. If an invalid location is defined, the script does not generate this dummy entry (default: /etc/davfs2/secrets)
* `recents_file`: file name where the recent vault paths are saved. If this is empty, the recents are not saved.

# Troubleshooting:
* Configuring davfs: https://webdav.io/linux-webdav-mount-how-to-mount-webdav-on-linux/
* The script (and the cryptomator CLI AFAIK) does not support the creation of vaults
* The decryption of vaults can take **minutes**. The RPI is not a power PC
* If something doesn't work out, first try to set the trace_level to 2 and read the messages

# Disclaimer:
1. This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
2. I am not affiliated with the creator of cryptomator. Please support their work!
