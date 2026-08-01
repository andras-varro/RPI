#!/bin/bash
#
# setup_onedriver.sh - Interactive wizard to install onedriver and configure
#                       one or more OneDrive account mounts with persistent,
#                       on-demand caching, auto-started via systemd user services.
#
# Tested on: Kubuntu / Ubuntu 26.04 (should work on other recent Ubuntu/Debian
# derivatives too, as long as an onedriver .deb is available for the release).
#
# What this script does:
#   1. Installs onedriver if it isn't already installed.
#   2. Loops asking you for a local folder name for each OneDrive account
#      you want to mount.
#   3. Creates the mountpoint, walks you through Microsoft authentication,
#      and sets up a systemd --user service so the mount comes back
#      automatically at login.
#   4. Repeats for as many accounts as you want, then prints a summary.
#
# Safe to re-run: it detects an existing install and skips re-installing,
# and it will not overwrite a mountpoint that's already configured without
# asking first.

set -uo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}!!${NC} $1"; }
error()   { echo -e "${RED}xx${NC} $1"; }
heading() { echo -e "\n${BOLD}$1${NC}"; }

# ---------------------------------------------------------------------------
# Step 1: Install onedriver (if needed)
# ---------------------------------------------------------------------------
install_onedriver() {
    heading "Step 1: Checking onedriver installation"

    if command -v onedriver &> /dev/null; then
        info "onedriver is already installed ($(onedriver --version 2>&1 | tail -n1))."
        return 0
    fi

    info "onedriver not found. Attempting install..."
    echo "    First trying your distro's own repositories (fastest path)."

    if sudo apt-get install -y onedriver &> /tmp/onedriver_apt_direct.log; then
        if command -v onedriver &> /dev/null; then
            info "Installed onedriver directly from your distro's repositories."
            return 0
        fi
    fi

    warn "Not available directly. Falling back to the upstream OBS repository."
    echo "    This adds a third-party apt source maintained by the onedriver author."

    # --- Detect distro family + version -----------------------------------
    # The OBS repo uses different path prefixes per distro family:
    #   Ubuntu             -> xUbuntu_<version>      (e.g. xUbuntu_26.04)
    #   Debian              -> Debian_<version>        (e.g. Debian_12)
    #   Raspberry Pi OS     -> Raspbian_<version>       (e.g. Raspbian_12)
    # lsb_release alone isn't enough to tell these apart reliably, so read
    # /etc/os-release and also check for the Raspberry Pi device tree.
    local distro_id version_id is_raspi=0
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro_id="${ID:-}"
        version_id="${VERSION_ID:-}"
    fi

    if [ -f /proc/device-tree/model ] && grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
        is_raspi=1
    fi
    if [ "${distro_id}" = "raspbian" ]; then
        is_raspi=1
    fi

    local family version repo_prefix
    if [ "$is_raspi" -eq 1 ]; then
        family="Raspberry Pi OS"
        repo_prefix="Raspbian"
        # Raspberry Pi OS's VERSION_ID is a plain Debian release number (12, 13, ...).
        version="${version_id:-12}"
    elif [ "${distro_id}" = "ubuntu" ]; then
        family="Ubuntu"
        repo_prefix="xUbuntu"
        version="${version_id:-$(lsb_release -rs 2>/dev/null)}"
    elif [ "${distro_id}" = "debian" ]; then
        family="Debian"
        repo_prefix="Debian"
        version="${version_id:-12}"
    else
        warn "Could not confidently detect distro family from /etc/os-release."
        warn "Falling back to Ubuntu-style detection via lsb_release."
        family="Ubuntu"
        repo_prefix="xUbuntu"
        version="$(lsb_release -rs 2>/dev/null)"
    fi

    if [ -z "$version" ]; then
        error "Could not detect your distro version. Please install onedriver manually:"
        error "https://github.com/jstaf/onedriver"
        return 1
    fi

    echo "    Detected: ${family}, version ${version} ($(dpkg --print-architecture))"

    local repo_url="https://download.opensuse.org/repositories/home:/jstaf/${repo_prefix}_${version}/"
    local key_url="${repo_url}Release.key"

    # Verify the exact-version repo actually exists; otherwise fall back to
    # nearby versions within the SAME family, which are usually compatible.
    if ! curl -fsI "${key_url}" &> /dev/null; then
        warn "No OBS build for ${repo_prefix}_${version} yet. Trying nearby versions as a fallback."
        local fallback_list=()
        case "$repo_prefix" in
            xUbuntu)   fallback_list=(25.10 25.04 24.04) ;;
            Raspbian)  fallback_list=(13 12) ;;
            Debian)    fallback_list=(13 12) ;;
        esac
        for fallback in "${fallback_list[@]}"; do
            if curl -fsI "https://download.opensuse.org/repositories/home:/jstaf/${repo_prefix}_${fallback}/Release.key" &> /dev/null; then
                version="$fallback"
                repo_url="https://download.opensuse.org/repositories/home:/jstaf/${repo_prefix}_${version}/"
                key_url="${repo_url}Release.key"
                warn "Using ${repo_prefix}_${version} build instead."
                break
            fi
        done
    fi

    echo "deb ${repo_url} /" | sudo tee /etc/apt/sources.list.d/home_jstaf.list > /dev/null
    if ! curl -fsSL "${key_url}" | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_jstaf.gpg > /dev/null; then
        error "Failed to fetch the OBS signing key. Aborting install."
        return 1
    fi

    sudo apt-get update
    if sudo apt-get install -y onedriver; then
        info "Installed onedriver from the OBS repository (xUbuntu_${version})."
    else
        error "Install failed. Please check the output above and install manually."
        return 1
    fi

    # Some onedriver .deb builds auto-enable a stray systemd symlink; remove it,
    # since we manage per-mount services ourselves below.
    if [ -e "/etc/systemd/user/default.target.wants/onedriver.service" ]; then
        warn "Removing an unwanted default onedriver.service symlink."
        sudo rm -f "/etc/systemd/user/default.target.wants/onedriver.service"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Step 2: Configure one OneDrive account mount
# ---------------------------------------------------------------------------
configure_one_account() {
    heading "Configure a OneDrive account mount"

    echo "This will be a local folder under your home directory that shows your"
    echo "entire OneDrive account. Nothing is downloaded up front - files are"
    echo "fetched the first time you open them, and kept locally after that."
    echo ""

    local name mountpoint
    while true; do
        read -rp "Local folder name for this account (e.g. OD-MyDrive): " name
        if [ -z "$name" ]; then
            warn "Name can't be empty."
            continue
        fi
        if [[ "$name" == */* ]]; then
            warn "Please enter a plain folder name, not a path."
            continue
        fi
        mountpoint="${HOME}/${name}"
        if [ -d "$mountpoint" ] && [ "$(ls -A "$mountpoint" 2>/dev/null)" ]; then
            warn "${mountpoint} already exists and is not empty."
            read -rp "Use it anyway? This should only be done if it's an existing onedriver mount. (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                continue
            fi
        fi
        break
    done

    mkdir -p "$mountpoint"
    info "Mountpoint ready: ${mountpoint}"

    heading "Authenticating to Microsoft"
    echo "A login window should open. Sign in with the Microsoft account that"
    echo "owns THIS particular OneDrive (double check if you have several"
    echo "family/work accounts - it's easy to accidentally reuse a cached"
    echo "browser session for the wrong one)."
    echo ""
    echo "(If this machine has no desktop/browser available, re-run this step"
    echo " manually with: onedriver --auth-only --no-browser \"$mountpoint\""
    echo " which prints a device-login URL/code to use from another device.)"
    echo ""
    read -rp "Press Enter to open the login window..."

    if ! onedriver --auth-only "$mountpoint"; then
        error "Authentication failed or was cancelled. Skipping systemd setup for ${name}."
        return 1
    fi
    info "Authentication complete for ${name}."

    heading "Setting up auto-mount at login (systemd)"
    local service_name
    service_name=$(systemd-escape --template onedriver@.service --path "$mountpoint")
    echo "    Service unit: ${service_name}"

    systemctl --user enable "$service_name"
    systemctl --user start "$service_name"

    sleep 2
    if systemctl --user is-active --quiet "$service_name"; then
        info "${name} is mounted and the service is active."
    else
        error "${name}'s service does not appear active. Check with:"
        echo "      systemctl --user status ${service_name}"
        return 1
    fi

    echo ""
    echo "What to expect from here:"
    echo "  - Browsing a folder for the FIRST time will take a moment (it's"
    echo "    fetching the listing/contents from OneDrive over the network)."
    echo "  - Reopening the same folder or file afterwards will be fast, since"
    echo "    it's served from the local cache at:"
    echo "      ~/.cache/onedriver/$(systemd-escape --path "$mountpoint")"
    echo "  - This cache has no built-in size limit in onedriver. It will grow"
    echo "    as you use more files. Check its size any time with:"
    echo "      du -sh ~/.cache/onedriver/*"
    echo "    and reset a specific mount's cache with 'onedriver -w <mountpoint>'"
    echo "    (after stopping its systemd service first)."

    CONFIGURED_MOUNTS+=("${name} -> ${mountpoint}")
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
CONFIGURED_MOUNTS=()

heading "onedriver setup wizard"
echo "This script installs onedriver and walks you through mounting one or"
echo "more OneDrive accounts as on-demand, cached local folders."

if ! install_onedriver; then
    error "Could not install onedriver. Exiting."
    exit 1
fi

while true; do
    configure_one_account

    echo ""
    read -rp "Add (next) OneDrive account? (yes/no): " answer
    case "$answer" in
        yes|y|Y|Yes) continue ;;
        *) break ;;
    esac
done

heading "Done"
if [ ${#CONFIGURED_MOUNTS[@]} -eq 0 ]; then
    warn "No accounts were successfully configured."
else
    echo "Configured mounts:"
    for m in "${CONFIGURED_MOUNTS[@]}"; do
        echo "  - $m"
    done
    echo ""
    echo "Check status of all onedriver services at any time with:"
    echo "  systemctl --user status 'onedriver@*.service'"
    echo "  mount | grep onedriver"
fi
