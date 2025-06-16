#!/bin/bash

set -e

echo "[+] Updating system..."
sudo apt update && sudo apt upgrade -y

echo "[+] Installing core packages..."
sudo apt install -y \
  git curl wget unzip build-essential python3 python3-pip python3-venv \
  net-tools nmap gobuster ffuf sqlmap hydra john hashcat \
  binwalk steghide libimage-exiftool-perl tcpdump gdb ltrace strace \
  openvpn tmux zsh jq dnsutils whois \
  default-jdk python3-full pipx

echo "[+] Ensuring pipx is ready..."
pipx ensurepath --force

echo "[+] Creating CTF workspace structure..."
mkdir -p ~/CTF/{tools,scripts,writeups,targets,wordlists,binaries,web}

echo "[+] Installing Nikto..."
if [ ! -d ~/CTF/tools/nikto ]; then
    git clone https://github.com/sullo/nikto.git ~/CTF/tools/nikto
else
    echo "[*] Nikto already exists. Skipping."
fi

echo "[+] Installing Seclists..."
if [ ! -d ~/CTF/wordlists/Seclists ]; then
    git clone https://github.com/danielmiessler/SecLists.git ~/CTF/wordlists/Seclists
else
    echo "[*] Seclists already exists. Skipping."
fi

echo "[+] Handling rockyou.txt wordlist..."
if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    gunzip -kf /usr/share/wordlists/rockyou.txt.gz
    cp /usr/share/wordlists/rockyou.txt ~/CTF/wordlists/
else
    echo "[!] rockyou.txt not found at /usr/share/wordlists/. You may need to manually obtain it."
fi

echo "[+] Installing Rust and RustScan..."
if ! command -v rustscan &>/dev/null; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env
    cargo install rustscan
else
    echo "[*] RustScan already installed. Skipping."
fi

echo "[+] Installing AutoRecon via pipx..."
if ! pipx list | grep -q "autorecon"; then
    pipx install git+https://github.com/Tib3rius/AutoRecon.git
else
    echo "[*] AutoRecon already installed. Skipping."
fi

echo "[+] Installing Python-based tools with pipx..."
for tool in pwntools ropper ROPgadget; do
    if ! pipx list | grep -q "$tool"; then
        pipx install "$tool"
    else
        echo "[*] $tool already installed. Skipping."
    fi
done

echo "[+] Downloading and installing ctftool using ZIP fallback..."
if [ ! -d ~/CTF/tools/ctftool ]; then
    mkdir -p ~/CTF/tools/ctftool
    cd ~/CTF/tools/ctftool
    wget https://github.com/zardus/ctftool/archive/refs/heads/master.zip -O ctftool.zip
    unzip ctftool.zip && mv ctftool-main/* . && rm -r ctftool-main ctftool.zip
    python3 -m venv venv
    source venv/bin/activate
    pip install .
    deactivate
    echo "[*] ctftool installed. To run it:"
    echo "    source ~/CTF/tools/ctftool/venv/bin/activate && ctftool"
else
    echo "[*] ctftool already installed. Skipping."
fi

echo "[+] Installing privilege escalation tools..."
mkdir -p ~/CTF/tools/privilege-escalation
cd ~/CTF/tools/privilege-escalation

if [ ! -d "PEASS-ng" ]; then
    git clone https://github.com/carlospolop/PEASS-ng.git
else
    echo "[*] PEASS-ng already exists. Skipping."
fi

if [ ! -d "LinEnum" ]; then
    git clone https://github.com/rebootuser/LinEnum.git
else
    echo "[*] LinEnum already exists. Skipping."
fi

echo "[+] Installing GEF for GDB..."
if [ ! -f ~/.gdbinit ]; then
    bash -c "$(curl -fsSL https://gef.blah.cat/sh)"
else
    echo "[*] GEF already installed. Skipping."
fi

echo "[+] Installing Ghidra via Snap..."
if ! snap list | grep -q ghidra; then
    sudo snap install ghidra
else
    echo "[*] Ghidra already installed. Skipping."
fi

echo "[+] Installing Cutter manually..."
CUTTER_DIR=~/CTF/tools/cutter
mkdir -p "$CUTTER_DIR"
cd "$CUTTER_DIR"

if [ ! -f cutter.AppImage ]; then
    CUTTER_URL=$(curl -s https://api.github.com/repos/radareorg/cutter/releases/latest | grep "browser_download_url" | grep "x64.Linux.AppImage" | cut -d '"' -f 4)

    if [ -z "$CUTTER_URL" ]; then
        echo "[!] Failed to retrieve Cutter AppImage URL. Skipping Cutter installation."
    else
        echo "[+] Downloading from $CUTTER_URL"
        wget "$CUTTER_URL" -O cutter.AppImage
        chmod +x cutter.AppImage
    fi
else
    echo "[*] Cutter AppImage already exists. Skipping."
fi

echo "[+] Installing radare2..."
if [ ! -d ~/CTF/tools/radare2 ]; then
    cd ~/CTF/tools
    git clone https://github.com/radareorg/radare2.git
    cd radare2 && ./sys/install.sh
else
    echo "[*] radare2 already installed. Skipping."
fi

echo "[✓] CTF toolkit installation complete!"
echo "📂 All tools are ready under ~/CTF"
echo "🔁 You may want to reboot or run 'source ~/.bashrc' or 'source ~/.zshrc' to activate pipx and Rust paths."
