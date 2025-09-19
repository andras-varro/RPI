# Step-by-step guide to configure Postfix with Gmail, including common pitfalls and troubleshooting steps

## Step 1: Remove conflicts & prepare environment

1. Remove sSMTP: Postfix and sSMTP conflict with each other. Remove sSMTP cleanly before proceeding.

```bash
sudo apt-get remove --auto-remove ssmtp
```

2. Generate a Gmail App Password: Post-May 2025, regular passwords no longer work. You need to create a 16-character App Password for Postfix to use for authentication.
    - First, ensure 2-Step Verification is enabled on your Google Account.
    - Access the App Passwords page directly: https://myaccount.google.com/apppasswords.
    - Choose "Other (Custom Name)", name it "Postfix", and click Generate.
    - Crucial: Copy the generated password, as you will not be able to see it again.

> Pitfall: If the "App passwords" option is missing, it may be hidden by enhanced security settings or for Google Workspace accounts. Use the direct link or search for "App passwords" in the Google Account settings search bar.



---

### Step 2: Install Postfix & dependencies

```bash
sudo apt-get install postfix mailutils libsasl2-modules
```

When prompted for “mail configuration,” choose **Internet Site** (you can adjust later).

---

### Step 3: Configure Postfix

Edit `/etc/postfix/main.cf`:

```bash
sudo nano /etc/postfix/main.cf
```

Add/modify:

```ini
# Relay host through Gmail
relayhost = [smtp.gmail.com]:587

# Enable SASL authentication
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous

# TLS settings
smtp_use_tls = yes
smtp_tls_security_level = encrypt # This needs testing!
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

# Optional: Increase logging for debugging
debug_peer_list = smtp.gmail.com
```

Save the file: Press Ctrl+X, then Y, and then Enter.

---

### Step 4: Store credentials securely

```bash
sudo nano /etc/postfix/sasl_passwd
```

Content:

```
[smtp.gmail.com]:587 your_email@gmail.com:your_app_password
```

> Pitfall: Ensure there are no spaces within the 16-character password string.

Secure & hash:

```bash
sudo chmod 600 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
```

---

### Step 5: Restart & test

```bash
sudo systemctl restart postfix
sudo systemctl enable postfix
```

Test mail:

```bash
echo "This is a Postfix test email" | mail -s "Postfix Test" recipient@example.com
```

---

### Step 6: Logs & troubleshooting

* Monitor logs:

  ```bash
  tail -f /var/log/mail.log
  # or
  journalctl -u postfix -f
  ```

Success: Look for a line similar to status=sent (250 2.0.0 OK ...).

> Pitfall: If the email does not arrive in the inbox, check the spam/junk folder. If Postfix reports success but the email is missing, check your DNS records (like SPF) or consult the mail administrator on the receiving end.


* Check queue:

  ```bash
  postqueue -p
  ```

* Clear stuck mail (after fixing issues):

  ```bash
  postsuper -d ALL
  ```

* Verify config syntax:

  ```bash
  postfix check
  ```

---

### Step 7: Common pitfalls

* **Authentication failed** -> wrong App Password or un-hashed `sasl_passwd`. Run `postmap` again.
* **STARTTLS issues** -> firewall blocking port 587 or missing CA file.
* **Mail sent but not delivered** → check spam folder, SPF/DKIM/DMARC records of your sending domain.
* **Two accounts / aliases** -> Postfix always authenticates with the account in `sasl_passwd`. Use “sender\_canonical\_maps” if you need to rewrite the From address.
