# setup_veracrypt
------------------

Although there is a build for ARM64 from VeraCrypt, it does not work on current Raspberry OS, because it requires a component (libwxgtk3.0-gtk3-0v5) which is not available in the package repository. Instead a newer version is available (libwxgtk3.2-1). This scripts tries to instal the old version of the component, and if fails, pulls the source of VeraCrypt and builds it.

# Features:
* Download an install VeraCrypt or builds it from source.

# Requires:
* which, apt, sha256sum, wget: these are pre-installed with the standard Raspbian/Raspberry OS
* sudo rights

# How to use:
1. Make sure you have sudo rights
2. Make the script executable. Open a terminal window to the script location and execute:
```
chmod +x setup_veracrypt.sh
```
3. Execute the script ./setup_veracrypt.sh

# Configuration:
The script has a configuration section at the top.

# Troubleshooting
If something doesn't work out, read the output and create an issue.

# Disclaimer:
This software is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
