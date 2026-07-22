<div align="center">

# Private Matrix Communication Server · One-Command Deploy (tuwunel edition)

**Your server, your data — a self-hosted team messenger built for confidentiality and data sovereignty.**

Powered by **tuwunel** (Rust engine, embedded database, **no PostgreSQL**): lighter, more stable, and able to **send large files / photos / long videos like Telegram**. 2 GB of RAM comfortably runs a mid-sized team. End-to-end encryption, metadata minimisation and invite-only registration are **on by default**. One command to deploy — you don't need to be a sysadmin; every option is explained in plain language.

Recommended client: **Element X**. A dedicated **VeilX** client is in development (cleaner, easier, more features, open-source and auditable; operations team based in the UK, Singapore and Japan). Client files, contracts, internal discussions, voice & video meetings — all of it lives only on your own server. Built on the open [Matrix](https://matrix.org) protocol. Source is public and auditable (free for non-commercial use).

**English** · [简体中文](docs/README.zh-CN.md) · [繁體中文](docs/README.zh-TW.md) · [粵語](docs/README.zh-HK.md) · [日本語](docs/README.ja.md) · [한국어](docs/README.ko.md) · [Русский](docs/README.ru.md) · [Français](docs/README.fr.md) · [Deutsch](docs/README.de.md) · [Italiano](docs/README.it.md) · [Español](docs/README.es.md) · [Bahasa Melayu](docs/README.ms.md) · [فارسی](docs/README.fa.md)· [简体中文](docs/README.zh-CN.md) · [繁體中文](docs/README.zh-TW.md) · [粵語](docs/README.zh-HK.md) 

</div>

---

## ✨ What you get

- 💬 Text chat and group rooms (**end-to-end encrypted — the server and your hosting provider cannot read message content**)
- 📁 **Send large files / photos / long videos** (default per-file limit **4 GB**, configurable higher — this is the headline feature)
- 📞 One-to-one and group voice / video calls (optional)
- 📱 Self-registration from your phone: install **Element X**, enter your domain, register and log in — no need to visit element.io
- 🌐 Your own web client: open `https://your-domain` in a browser to register/log in — no app required
- 🖥️ **Graphical web admin panel** (Ketesa): manage users, issue/revoke invite codes, review rooms and media
- 🔒 **Privacy-hardened by default**: real client IP never stored, redactions are permanent, presence off, logs don't record IPs
- 👥 Invite-only: by default only people with an invite code can register — outsiders can't get in
- ⚡ **Resource-efficient**: single Rust process, no PostgreSQL — 2 GB of RAM serves ~300 people

---

## 📋 Before you start (3 things)

| What | Requirement | Where |
|---|---|---|
| **A cloud server (VPS)** | Ubuntu 22.04 / 24.04 (or Debian 11+), a public IP. **Size the RAM by team size** (see below). **Provision enough disk if you share large files.** | [Hetzner](https://www.hetzner.com/cloud), [OVHcloud](https://www.ovhcloud.com/en/vps/), [Netcup](https://www.netcup.com), [Contabo](https://contabo.com), or any provider you trust |
| **A domain name** | Any TLD (.com / .org / .net…) | [Namecheap](https://www.namecheap.com), [Porkbun](https://porkbun.com), [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) |
| **10 minutes** | Copy-paste all the way; no coding needed | — |

> 💡 **Size the RAM by active-user count** (concurrently active, federation off, chat + files): **1 GB** ≈ a few dozen people (turn calls off) · **2 GB** ≈ 300 people · **4 GB / 2 vCPU** ≈ 500 people. tuwunel is light — CPU is rarely the bottleneck.
> 💡 **Disk is the real variable for large files.** Media is stored on the server's local disk and, being end-to-end encrypted, cannot be deduplicated. Heavy large-file use can add hundreds of GB to TB per month. Use a ≥ 50–100 GB system disk; heavy users should provision a large data volume or object storage, and keep an eye on the "Clean up disk" menu item.
> 💡 **Jurisdiction matters for privacy.** Pick a provider and country you're comfortable with — the host can, in principle, be compelled. End-to-end encryption protects message *content* regardless, but metadata lives on the host.
> 💡 Always choose an **Ubuntu 22.04 / 24.04** image when ordering. If RAM is under 2.5 GB, the script automatically adds swap.

---

## Step 0 — Prepare the OS (skip if you already ordered it right)

Only **Ubuntu 22.04 / 24.04** (or Debian 11+) is supported.

- **New server**: pick **Ubuntu 22.04 x86_64** (or 24.04) in the "OS / Image" field when ordering — done.
- **Wrong OS**: use your provider's "Reinstall / Rebuild" to install Ubuntu 22.04. ⚠️ This **wipes all data** — back up an existing server first.
- Not sure what you're running? After connecting (Step 3), run `cat /etc/os-release`.
- If you install on the wrong OS, the script detects it and tells you clearly — it won't break anything.

---

## Step 1 — Add DNS records (~2 minutes)

In your **domain registrar's** DNS panel, add **A records**.

Assuming your domain is `mychat.org` and your server IP is `1.2.3.4`:

| Type | Host (name) | Value | Purpose |
|---|---|---|---|
| A | `@` (root domain) | `1.2.3.4` | Root domain + web client + delegation |
| A | `matrix` | `1.2.3.4` | The homeserver |
| A | `admin` | `1.2.3.4` | Web admin panel (skip if admin off) |
| A | `livekit` | `1.2.3.4` | Calls (skip if calls off) |
| A | `matrix-rtc` | `1.2.3.4` | Calls (skip if calls off) |

> 📌 The host field takes only the **prefix** (`matrix`), not the full domain.
> 📌 Records propagate in 1–10 minutes; the installer waits automatically if they're not live yet.
> 📌 For chat + files only (calls off), you only need `@` / `matrix` / `admin`.
> ⚠️ **Using Cloudflare?** These records must be **grey-cloud (DNS only)** — **do not enable the orange cloud (proxy)**. The proxy would ① cap large files at 100 MB (Free/Pro) ② prevent certificate issuance ③ block call media. The installer asks whether you use a CDN (answer yes to relax the DNS check), but the `matrix` host must stay grey-cloud.

---

## Step 2 — Open firewall ports (~1 minute)

In your provider's "Security Group / Firewall", allow:

| Port | Protocol | Purpose |
|---|---|---|
| 80 | TCP | HTTPS certificate issuance |
| 443 | TCP + UDP | Web and encrypted traffic |
| 7881 | TCP | Call fallback channel (skip if calls off) |
| **7882** | **UDP** | **Call audio/video (easiest to forget! Missing this = no sound/picture)** |

> 📌 No "security group" layer at your provider? Skip this — the script configures the system firewall automatically.

---

## Step 3 — Connect to your server (~1 minute)

Open a terminal (macOS: "Terminal"; Windows: "PowerShell"), run the following (replace the IP), and enter your server password when prompted (**the screen shows no characters while typing the password — that's normal**):

```bash
ssh root@YOUR_SERVER_IP
```

On the first connection, answer `yes` to the fingerprint prompt.

> 📌 If the default user isn't root (e.g. `ubuntu`), use `ssh ubuntu@IP` — the script elevates automatically.

---

## Step 4 — Run the installer (~5–10 minutes, fully automated)

Once connected, **copy the whole line** and paste it into the terminal:

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

Follow the wizard. It asks **6 options + a CDN question**; each is explained on screen, so if in doubt, just press Enter (defaults are the safest combination):

| Option | Enter (recommended) | Notes |
|---|---|---|
| 1 Who can register | **Invite code required** | Only people with your code can register; the first registrant becomes admin. (Or fully open — not for business use.) |
| 2 Federation | **Off** | Island mode: outsiders can't message your members; smallest attack surface. |
| 3 Voice/video calls | **Off first** | Needs two extra DNS records (`livekit`/`matrix-rtc`) and ports 7881/7882; get chat + files stable first. |
| 4 Web client | **On** | Members open `https://your-domain` to register/log in — no app needed. |
| 5 Web admin panel | **On** | A graphical admin panel (Ketesa) at `admin.your-domain`. |
| 6 Max file size | **4 GB** | Set anything (e.g. 10 GB); larger uses more disk. |
| ＋ Behind Cloudflare/CDN? | **No** | Answer yes only if you use a CDN (relaxes the DNS check); `matrix` must still be grey-cloud. |

> 🔒 **Automatically enabled (not asked — active as soon as it's installed):** ① new rooms are **forced to end-to-end encryption** ② **metadata minimisation** (real IP not stored, redactions permanent, presence off, IP-free logging) ③ **Element X self-registration** (native OIDC; registration still requires an invite code). To disable the metadata hardening: `PRIVACY=0 sudo -E tuwunel config`.
> 🤖 **Fully unattended:** `REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

Then it runs automatically: check DNS → install Docker → tune system → firewall → generate config → start services → obtain HTTPS certificate → **auto-create the admin and print the account/password**.

Success looks like this:

```
========================================================
 🎉 tuwunel deployed!  mychat.org
 (registration[token] · federation[off] · calls[off] · web[on] · admin[on] · phone-signup[on] · big-files[4G] · engine tuwunel/Rust, no Postgres)

 Member sign-up / login
   Web (recommended): open https://mychat.org to register & log in
   Phone app: install Element X → enter server "mychat.org" → register (invite code) or log in

 Admin (auto-created)
   account: admin    password: xxxxxxxxxxxx
   Web admin panel: https://admin.mychat.org  (log in with the admin account above)

 Daily management:  sudo tuwunel   (menu)    sudo tuwunel adduser   (add a member)
========================================================
```

> 🔑 **Write down the admin account/password + invite code!** They're all stored on the server in `/opt/tuwunel/CREDENTIALS.txt` (`cat /opt/tuwunel/CREDENTIALS.txt`).
> ⚠️ "Not ready yet" at the end usually means the cloud firewall isn't allowing 80/443, or DNS hasn't propagated globally. Caddy retries the certificate automatically — no reinstall needed.

---

## Step 5 — Log in from phone / desktop

| Device | Client | Download |
|---|---|---|
| iPhone / iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows / macOS / Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| Browser (no install) | Your **own web client** | Open `https://your-domain` |

**Log in with the server = your domain** (e.g. `mychat.org`, **not** `matrix.mychat.org`); use the account/password shown at the end of the install.

> ⚠️ **Can't connect / Element X says "couldn't connect to this homeserver"? First thing to check: is your phone's date & time correct?**
> A wrong phone clock → the HTTPS certificate fails validation → you simply can't connect (very common, especially on Android).
> Fix: phone **Settings → Date & Time → turn on "Set automatically"**, then retry.

---

## 👥 How members join (pick one)

1. **Admin creates the account (most controlled):** `sudo tuwunel adduser` creates a user and sets a password in one command; send them "domain + username + password". The invite code never leaves your hands.
2. **Give out an invite code, web self-registration:** send the invite code (in `CREDENTIALS.txt`) + `https://your-domain`; members register themselves in a browser.
3. **Give out an invite code, Element X self-registration:** members install Element X → enter your domain → create account → enter the invite code.

---

## 🖥️ Graphical admin panel (Ketesa, recommended)

If enabled (option 5), the installer deploys a **graphical web admin panel** — manage everything with a mouse, no commands.

**How to open:** browse to `https://admin.your-domain` → **log in directly with the admin account `admin` + password** (no separate gate password; the panel is locked to your server).

**What you can do:** manage users (create/deactivate/reset password), **issue and revoke invite codes**, review rooms/media, room directory, scheduled tasks.

> 📌 The "Reports / Reported users" pages may error or show empty — tuwunel doesn't implement that feature; this is **normal** and you'll rarely need it.
> 📌 The panel needs tuwunel v1.8.1+ (the `:latest` image already has it). If panel login errors, run `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`.
> 📌 Add the panel to an existing server later: `sudo tuwunel enable-admin` (add the `admin` DNS record first).

---

## 🔧 Day-to-day management: the menu

After install, **running `sudo tuwunel` opens the Chinese/English management menu** — no commands to memorise:

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  tuwunel management menu   your-domain        │
└──────────────────────────────────────────────┘
  1) Status                    6) Upgrade service images
  2) Add a team member         7) Clean up disk
  3) Change config             8) Restart all services
  4) Enable/disable web admin  9) Update script + apply new features
  5) Back up now              10) Uninstall completely
  p) Privacy hardening / metadata cleanup
  s) Redact plaintext credential file (anti-forensics)
  b) Automatic scheduled encrypted backup
  0) Exit
```

Or use commands directly:

```bash
sudo tuwunel adduser          # add a member
sudo tuwunel config           # change config (Enter = keep; data/accounts untouched)
sudo tuwunel update           # pull the latest script from GitHub & apply new features (data untouched)
sudo tuwunel enable-admin     # add the web admin panel to an existing server
sudo tuwunel enable-elementx  # enable Element X phone self-registration
sudo tuwunel autobackup       # enable weekly automatic encrypted backups
sudo tuwunel privacy          # privacy/metadata: see what can be removed, clear logs
sudo tuwunel forget-secrets   # anti-forensics: redact plaintext password/invite code on disk
sudo tuwunel uninstall        # uninstall
```

> 🔄 **Reconfigure without reinstalling** (menu 3): it re-asks the options, **Enter = keep the current value**, then restarts. Accounts, history and keys are all preserved.

---

## 🔒 Privacy / anti-forensics (this edition's focus)

This system is built to protect confidential communication, and **minimises the traces left on the server by default**:

- ✅ **Message content is end-to-end encrypted** — neither you (the operator) nor the hosting provider can read it. This is the one guarantee that holds regardless of how good or bad the server is.
- ✅ **Metadata minimisation (on by default):** real client IP never stored (`ip_source`), **redactions are truly permanent** (no 60-day retention of the original), presence off, log level too low to record IPs, tightened profile/room-directory exposure.
- ✅ **Anti-forensic tools:** `sudo tuwunel forget-secrets` redacts the plaintext password/invite code on disk; `sudo tuwunel autobackup` produces AES-256-encrypted backups.

**The honest limits (state these to clients — do not over-promise):**

- ❌ **Metadata that cannot be removed:** room membership, event timeline, account existence, room names / file names — the server must keep these to function. E2EE protects *content*, **not metadata** (who talks to whom, when, room names, file names).
- ❌ **If the disk is physically seized / imaged:** on an ordinary VPS the data is written to disk in plaintext and metadata can be extracted by forensics. Defending this layer requires a trusted provider/jurisdiction, or advanced full-disk encryption / a front "shield" proxy (not automatic, needs engineering effort).
- ❌ **Hiding the server IP via Cloudflare doesn't really work** (certificate-transparency logs and grey-cloud subdomains leak it). Truly hiding the IP needs a self-hosted WireGuard front proxy.

> Accurate wording for clients: **"Message content and attachments are end-to-end encrypted; the operator cannot read them. The server retains communication metadata (who is in which room, when, file names, room names), which could be extracted if the server is physically seized."**

---

## 💾 Backups (strongly recommended)

Lose the database or keys and there is **no recovery**. This edition has no PostgreSQL — a backup is simply an archive of `data/tuwunel` (database + media) + `tuwunel.toml` + `.env`.

**Recommended: turn on automatic encrypted backups** (weekly, AES-256, auto-rotated, skipped automatically if the disk is nearly full):

```bash
sudo tuwunel autobackup     # set folder / retention / frequency; it prints the key — save it in a password manager
```

**Or back up now** (menu option 5; you can set an encryption passphrase).

**Download to your computer** (run on your own machine):

```bash
scp root@YOUR_SERVER_IP:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **Save the backup key.** Without it, an encrypted backup can never be opened. The key lives only on the server — if the server is gone and you didn't save the key, the backups are useless.
> 💡 The local `backups/` folder dies with the server. Copy the `.enc` files elsewhere regularly, or point the backup folder at a mounted external volume / object storage.

---

## ❓ FAQ

| Problem | Cause & fix |
|---|---|
| **Phone Element X can't connect / "couldn't connect to this homeserver"** | **First, check the phone's date & time** (Settings → Date & Time → "Set automatically") — a wrong clock fails certificate validation; this is the most common cause (especially on Android). Then: try another network, confirm you can open `https://your-domain/.well-known/matrix/client` in the phone browser, and update Element X. |
| **Element X says "needs to be upgraded to support authentication"** | That refers to registration. Confirm phone sign-up is on (`sudo tuwunel enable-elementx`) and tuwunel is up to date (`docker compose pull tuwunel`). Or register via web / `adduser` and have members **log in with a password** in Element X. |
| **Large files won't upload** | Check the size limit (`MAX_UPLOAD=10G sudo -E tuwunel config`); if using Cloudflare, the **`matrix` host must be grey-cloud** (the orange-cloud 100 MB cap kills large files). |
| **Admin panel `admin.domain` won't open / login errors** | Usually the `admin` DNS record is missing or the certificate isn't ready — add it and wait a few minutes. For login errors, `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`. |
| Forgot the admin password | `cat /opt/tuwunel/CREDENTIALS.txt`; or `sudo tuwunel adduser` to create a new admin. |
| Want to change config (calls, registration, file size, admin) | No reinstall: `sudo tuwunel config` — Enter keeps values, data/accounts untouched. |
| Calls connect but no sound/picture | 99% of the time port **7882/UDP** isn't allowed — add it in the provider's firewall. |
| Disk filling up | Menu option 7 "Clean up disk"; heavy large-file users should provision a large volume or object storage. |
| "Unable to decrypt" old messages in an encrypted room | Normal: a new device has no historical keys. Verify the new session from an old device. |
| Uninstall / reinstall | `sudo tuwunel uninstall` (double confirmation before deleting); reinstall = uninstall, then re-run the install command. |

---

## 📦 Server-side components

Once installed, these run — all orchestrated with Docker, open-source and auditable:

```
Caddy (automatic HTTPS) + tuwunel (Rust, embedded RocksDB, no PostgreSQL)
  + Element Web (your own web client, optional)
  + Ketesa (graphical admin panel, optional)
  + LiveKit + lk-jwt-service (calls, optional)
```

Install directory `/opt/tuwunel`. All logic lives in the single script `matrix-tuwunel-installer.sh`, which you can audit yourself.

---

## 🆚 tuwunel vs Synapse edition

The repository also ships a Synapse edition (`matrix-installer.sh`). In short:

- **tuwunel edition (this document):** Rust, no PostgreSQL, **more efficient, stronger large-file support**, 2 GB serves ~300 people. Best for most teams, especially heavy large-file use.
- **Synapse edition:** Python + PostgreSQL, the most mature ecosystem and admin tooling, but heavier on RAM and weaker on large files.

**New deployments: the tuwunel edition is recommended.**

---

## 📄 Licence (note: non-commercial only)

This project is licensed under [PolyForm Noncommercial 1.0.0](LICENSE):

- ✅ **Free for personal / internal team / research / non-profit use** — modify and redistribute freely (keep the copyright notice)
- ❌ **All commercial use is prohibited** (selling it, bundling it into a commercial product, offering it as a paid service, etc.)
- 🚫 **Reselling on any marketplace, or paid "installation/deployment" services, are prohibited** — this project is free; if you see someone selling it, that's unauthorised resale
- 💼 Want a proper commercial licence? Open an [Issue](../../issues) to contact the author.

Star ⭐ if you find it useful.

---

<div align="center">
Built with ❤️ · so everyone can own their private communication server
</div>
