# Raspberry Pi Hardening & Remote Access Guide

## 1. System Updates

**What & Why**: Keep the system patched against known vulnerabilities.

```bash
sudo apt update && sudo apt full-upgrade -y
```

**Checkpoint**:

```bash
uname -a
```

Kernel and packages are up to date.

**Pitfall**: Don’t skip reboots when kernel updates require it.

---

## 2. Create an Admin User

**What & Why**: Avoid using `pi` as primary admin (common attack target).

```bash
sudo adduser youradmin
sudo usermod -aG sudo youradmin
```

**Checkpoint**:

```bash
groups youradmin
```

-> Should show `sudo`.

**Pitfall**: Don’t delete `pi` yet; some apps (Calibre, etc.) may rely on it.

---

### 2.1. Remove Auto-Sudo for `pi`

**What & Why**:

* By default, the `pi` user is in the `sudo` group -> can run any command as root without restrictions.
* If the `pi` account gets compromised, an attacker gets root access immediately.

**Remove sudo rights**:

```bash
sudo deluser pi sudo
```

**Checkpoint**:

```bash
getent group sudo
```

Should show only `youradmin` (and any other trusted admins you explicitly added).

```bash
id pi
```

Should not show pi is sudo


**Pitfalls**:

* Don’t remove `pi` entirely if programs run under the pi user.
* Keep at least one **verified working admin account** (`youradmin`) with sudo before removing `pi` from sudo, otherwise you’ll lock yourself out of administrative control.

---

## 3. Lock but Keep the `pi` User. This is optional. Especiall if programs run under the pi user.

**What & Why**: `pi` stays for app data, but no login.

```bash
sudo usermod -s /usr/sbin/nologin pi
sudo passwd -l pi
```

**Checkpoint**:

```bash
ssh pi@<host>
```

-> Connection closes with *“This account is currently not available.”*

**Pitfall**: Some services (like calibre-server) may still run as pi, since nologin only prevents interactive logins.

---

## 4. SSH Security

## 4.1. Set up Key-Based SSH Login (before disabling password login)

**What & Why**: Use public/private key pairs -> stronger than passwords, resistant to brute-force.

On your **local machine** (if you don’t already have a key):

```bash
ssh-keygen -t ed25519 -C "yourname@yourhost"
```

Press Enter to accept default path (`~/.ssh/id_ed25519`), optionally set a passphrase.

Copy the key to the Pi:

```bash
ssh-copy-id youradmin@<pi-host-or-ip>
```

on Windows
```ps
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh youradmin@<pi-host> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

(or manually copy `~/.ssh/id_ed25519.pub` to `/home/youradmin/.ssh/authorized_keys` on the Pi).

**Fix permissions** on Pi (important for SSH to work):

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**Checkpoint**:

```bash
ssh youradmin@<pi-host>
```

Should log you in without asking for a password.

**Pitfall**:

* Don’t disable `PasswordAuthentication` until you’ve **successfully tested a second SSH session** using the key.
* If you mess up, you’ll lock yourself out -> always keep one session open as a safety net.


## 4.2. Further hardening

**What & Why**: Limit attack surface.

```bash
sudo nano /etc/ssh/sshd_config
```

Change/add:

```
PermitRootLogin no
PasswordAuthentication no
Protocol 2
```


Restart:

```bash
sudo systemctl restart ssh
```

**Checkpoint**:

```bash
sshd -T | grep protocol
```

-> Should say `protocol 2`.

**Pitfall**: Always test a second SSH session before logging out, in case config locks you out.

---

## 5. UFW Firewall

**What & Why**: Restrict access to known ports.

```bash
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
# substitute 192.168.1.0 with your subnet. Port 3389 is the RDP port.
sudo ufw allow from 192.168.1.0/24 to any port 3389
# think about your services, this is cloudflared
sudo ufw allow 7844/tcp          
sudo ufw enable
```

**Checkpoint**:

```bash
sudo ufw status verbose
```

**Pitfall**: Always allow SSH before enabling `ufw`.

---

## 6. Fail2Ban

**What & Why**: Block brute-force attempts.

```bash
sudo apt install fail2ban -y
```

Enable SSH jail:

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
# Ban settings
bantime  = 1h
findtime = 10m
maxretry = 5

# Default actions
backend = systemd
banaction = ufw

# Email notifications (optional)
# destemail = your@email.com
# sender = fail2ban@yourhost
# mta = sendmail
# action = %(action_mwl)s

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = systemd

# Uncomment to monitor xrdp
# [xrdp-sesman]
# enabled = true
# port    = 3389
# logpath = /var/log/xrdp-sesman.log
# backend = systemd
```

If you use xrdp, create a filter:

```sh
sudo nano /etc/fail2ban/filter.d/xrdp-sesman.conf
```

Add this content

```ini
[Definition]
failregex = AUTHFAIL: user=.* ip=(::ffff:)?<HOST>
ignoreregex =
```

Test the regex:

```sh
sudo fail2ban-regex /var/log/xrdp-sesman.log /etc/fail2ban/filter.d/xrdp-sesman.conf
```

If you do some failed logins, you will see that the failregex counter increases.

Restart:

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
# Uncomment the next line to check the xrdp monitoring
# sudo fail2ban-client status xrdp-sesman
```

**Checkpoint**: Status shows `File list: /var/log/auth.log`.

**Pitfalls**
1. Without `rsyslog` installed, `auth.log` won’t exist (install if needed).
2. Fail2ban bans new login attempts; existing active sessions are not affected.
3. backend = systemd, which is fine for Ubuntu 25.04. For xrdp-sesman, it might sometimes be safer to explicitly use backend = polling if systemd journal parsing fails.
4. xrdp must be using X11, as fail2ban won’t see anything meaningful if it’s Wayland-only.


### 6.1 Install rsyslog

On **Raspberry Pi OS (Bookworm and newer)**, `rsyslog` is no longer installed by default, so we must add it ourselves. Without it, tools like **fail2ban** can’t read `/var/log/auth.log`.

**What & Why**:

* Provides traditional syslog (`/var/log/auth.log`, `/var/log/syslog`)
* Required for monitoring tools like **fail2ban**
* Without it, only `journalctl` exists, which isn’t always supported by older security tools

**Install**:

```bash
sudo apt update
sudo apt install -y rsyslog
```

**Enable & start service**:

```bash
sudo systemctl enable rsyslog
sudo systemctl start rsyslog
```

**Checkpoint**:

```bash
systemctl status rsyslog
ls -l /var/log/auth.log
```

* `rsyslog` should be **active (running)**
* `/var/log/auth.log` should exist

**Pitfalls**:

* If `/var/log/auth.log` doesn’t show up, reboot once (`sudo reboot`).
* Disk space: logs rotate, but still check `df -h` occasionally.
* By default, logs are world-readable -> consider restricting:

  ```bash
  sudo chmod 640 /var/log/auth.log
  sudo chown root:adm /var/log/auth.log
  ```

  (`adm` group members can read logs; others cannot).


---

## 7. Remote Desktop (xrdp vs VNC)

* **Issue with VNC**: Raspberry Pi’s default VNC runs inside the logged-in X session.

  * Needs a user logged in locally.
  * Less secure (password auth).
  * Poorer Windows/macOS client support.

* **xrdp solution**: Provides an RDP server -> works out-of-box with Windows Remote Desktop, better encryption, separate session handling.

**Install & Configure**:

```bash
sudo apt install xrdp -y
sudo systemctl enable --now xrdp
```

**Checkpoint**:

```bash
sudo systemctl status xrdp
```

-> Should be active.
**Pitfall**: Disable/stop VNC to avoid conflicts:

```bash
sudo systemctl disable --now vncserver-x11-serviced
```

> xrdp sessions are independent, not tied to the physical HDMI console, unlike VNC.

---

## 8. File Sharing Between Users

**What & Why**: Share folders, like calibre's `Bookshelf` with admin, keep `pi` limited.

```bash
sudo groupadd calibre
sudo usermod -aG calibre pi
sudo usermod -aG calibre youradmin
sudo chown -R pi:calibre /home/pi/Bookshelf
sudo chmod -R 770 /home/pi/Bookshelf
sudo find /home/pi/Bookshelf -type d -exec chmod g+s {} \;
```

**Checkpoint**:

```bash
ls -ld /home/pi/Bookshelf
```

-> Group should be `calibre`, perms `drwxrws---`.

**Pitfall**: If you `chmod 777`, everyone on system gets access (bad for security).

> Your user needs to re-login for the group membership to apply.

---

## 9. Rootkit Hunter

**What & Why**: Detect suspicious files & rootkits.

```bash
sudo apt install rkhunter -y
sudo rkhunter --update
sudo rkhunter --propupd   # baseline
```

Run checks:

```bash
sudo rkhunter --check
```

**Checkpoint**: No `Warning` except for known benign files (e.g. hidden config).

**Pitfalls**

1. Don’t panic on every warning—check if it’s a legitimate system file.
2. run sudo rkhunter --update && sudo rkhunter --propupd again after major package upgrades, so the baseline stays accurate.

### 9.0 Configure update

1. Open the rkhunter config

```bash
sudo nano /etc/rkhunter.conf
```

(on some distros it may be `/etc/rkhunter.conf.local` — check which file exists).

2. Configure rkhunter to use wget

Find (or add) this line:

```ini
WEB_CMD=/usr/bin/wget --no-check-certificate
```

### 9.1 Enable emails from rkhunter

see first: [Configure postfix with gmail](./postfix.md) to send mails from rkhunter

1. Open the rkhunter config

```bash
sudo nano /etc/rkhunter.conf
```

(on some distros it may be `/etc/rkhunter.conf.local` — check which file exists).

2. Enable email alerts

Find (or add) this line:

```ini
MAIL-ON-WARNING=you@example.com
```

Replace `you@example.com` with your email address.

**Only warnings** -> you get email if something suspicious is found.
If you also want email on **every run**, use:

```ini
MAIL-ON-ALL=you@example.com
```

3. Make sure mail works

Since you already set up **Postfix with Gmail**, rkhunter will use that for sending.
Quick test:

```bash
echo "test" | mail -s "rkhunter test" you@example.com
```

If you receive it, you’re good.

---

### 9.2 Run rkhunter daily (if not already)

On Debian/Ubuntu, rkhunter installs a cron job under `/etc/cron.daily/rkhunter`.
If you want to trigger a run manually with mail alerts:

```bash
sudo rkhunter --check --cronjob --report-warnings-only
```

### 9.3 Whitelist false positives

1. Script:

SCRIPTWHITELIST=/usr/bin/egrep

2. Large memory:

ALLOWSHM=/usr/bin/veracrypt

3. Hidden files:

ALLOWHIDDENFILE=/etc/.updated

---

# Final Checklist

* [ ] System updated
* [ ] `pi` locked, admin user created
* [ ] SSH hardened (no root, no passwords, SSH-2 only)
* [ ] UFW firewall active with minimal ports
* [ ] Fail2Ban running & banning after failed SSH attempts
* [ ] VNC disabled, xrdp working
* [ ] Folder share between limited user and admin user securely via group 
* [ ] rkhunter baseline created