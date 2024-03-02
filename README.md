# RPI

This repo contains scripts for configuring the Raspberry PI for everyday computing purposes.

## Contents

* cryptomator: As of today, there is no GUI available for the popular cryptomator tool for ARM Linux (like Raspberry OS/Raspbian). The developement team of cryptomator, however, released a command line interface (cli) that can open cryptomator vaults. This script is a `demo` wrapper for this cryptomator cli. 

* hardening: Raspberry OS/Raspbian comes with a nice and light user interface and autologin. Locking the UI was also not in scope for the default GUI. This script sets up lock-screen functionality, disables auto-login and supports Wayland/Wayfire as-well-as lightdm.

* rclone: Usually there is no ARM64 Linux (like Raspberry OS) client for the major cloud providers. There is, however, one software that bridges over this gap: rclone.

* veracrypt: Although there is a build for ARM64 from VeraCrypt, it does not work on current Raspberry OS, because it requires a component (libwxgtk3.0-gtk3-0v5) which is not available in the package repository. Instead a newer version is available (libwxgtk3.2-1). This scripts tries to instal the old version of the comonent, and if fails, pulls the source of VeraCrypt and builds it.

* vpn: This script installs the Nord VPN client on Raspberry OS and whitelists the local network, so that VNC and ssh works.

* setup.sh: asks for password change, updates the system, installs the following packages: keepassxc, ca-certificates unrar-free, transmission, aisleriot, kdiff3, krename, zip, p7zip-full, breeze-icon-theme, gnome-keyring, krusader, and then executes the scripts in the subfolders.

## Troubleshooting

If something does not work, or if you find a problem or bug, please raise an issue.

## License

All the scripts are licensed under the Apache License. Please see the [LICENSE file](./LICENSE) on details.