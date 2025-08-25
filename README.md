# CTF Starter Kit

Contains a stack of apps to help with CTF Games.

Use responsibily blah blah blah...

Created with help from ChatGPT for my own purposes.  Do what you want with it  I really don't care

**To Install from Terminal (Debian / Ubuntu)**

`curl -L https://raw.githubusercontent.com/lbilston/ctfstarterkit/refs/heads/main/ctf_starter_kit_debian.sh | bash` 

**To Install from Terminal (Arch)**

`curl -L https://raw.githubusercontent.com/lbilston/ctfstarterkit/refs/heads/main/ctf_starter_kit_arch.sh | bash` 


## CTF Starter Kit - Installation Summary

> **Installed by:** `curl -L https://raw.githubusercontent.com/lbilston/ctfstarterkit/refs/heads/main/ctf_starter_kit.sh | bash`  
> **Target:** Debian 12+ / Ubuntu 22.04+  
> **Location:** All tools organized under `~/CTF/`

---

## 🧱 System Packages (via `apt`)

**Installed with:** `sudo apt install`:

### Core System Utilities
- `git`, `curl`, `wget`, `unzip`
- `build-essential`, `python3`, `python3-pip`, `python3-venv`, `python3-full`
- `tmux`, `zsh`, `jq`

### Networking & Enumeration
- `nmap`, `net-tools`, `dnsutils`, `whois`, `openvpn`

### Web Recon Tools
- `gobuster`, `ffuf`, `sqlmap`, `hydra`

### Cracking & Forensics
- `john`, `hashcat`
- `binwalk`, `steghide`, `libimage-exiftool-perl`
- `tcpdump`, `ltrace`, `strace`

### Dev Tools
- `default-jdk`, `pipx`

---

## 📦 Python Tools (via `pipx`)

Installed in isolated environments:
- `pwntools` - for pwn challenges and scripting
- `ropper` - ROP gadget finder
- `ROPgadget` - another ROP chain builder
- `AutoRecon` - automated recon tool

> Installed into `~/.local/pipx/venvs/`

---

## 🛠️ Tools Installed from Source (via `git` or `wget`)

### Recon/Enumeration
- **Nikto**  
  `~/CTF/tools/nikto`

- **Seclists**  
  `~/CTF/wordlists/Seclists`

- **rockyou.txt**  
  Copied to `~/CTF/wordlists/rockyou.txt`

### Privilege Escalation
- **PEASS-ng**  
  `~/CTF/tools/privilege-escalation/PEASS-ng`

- **LinEnum**  
  `~/CTF/tools/privilege-escalation/LinEnum`

### Exploitation / Reversing
- **ctftool**  
  `~/CTF/tools/ctftool`  
  Activate with:
  ```bash
  source ~/CTF/tools/ctftool/venv/bin/activate
  ctftool
  ```

- **GEF**  
  Installed to `~/.gdbinit`

- **radare2**  
  `~/CTF/tools/radare2`

- **Cutter**  
  `~/CTF/tools/cutter/cutter.AppImage`

---

## 🧠 Binary Analysis & Debugging

- `gdb` + GEF
- `radare2` + Cutter GUI
- `pwntools`, `ropper`, `ROPgadget`

---

## 🗂️ Directory Structure Created

```
~/CTF/
├── binaries/
├── scripts/
├── tools/
│   ├── nikto/
│   ├── ctftool/
│   ├── radare2/
│   ├── cutter/
│   └── privilege-escalation/
├── targets/
├── web/
├── wordlists/
└── writeups/
```

---

## 🧪 Optional Post-Install Commands

```bash
nmap -v localhost
gobuster dir -u http://localhost -w ~/CTF/wordlists/Seclists/Discovery/Web-Content/common.txt
source ~/CTF/tools/ctftool/venv/bin/activate && ctftool
```
