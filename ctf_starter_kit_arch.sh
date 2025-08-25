#!/usr/bin/env bash
# Arch CTF Toolkit Installer (pacman + AUR)
# Run with: sudo ./setup-ctf.sh
set -euo pipefail

msg() { printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
err() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Determine the real (non-root) user for building AUR pkgs & group adds
REAL_USER="${SUDO_USER:-$(whoami)}"
if [[ $EUID -ne 0 ]]; then
  err "Please run as root: sudo $0"
  exit 1
fi
if ! [[ -f /etc/arch-release ]]; then
  err "This script is for Arch/Arch-based systems."
  exit 1
fi

# --- package sets ---
# Use openbsd-netcat to avoid provider prompt
PACMAN_PKGS=(
  # networking & scanning
  nmap masscan openbsd-netcat socat wireshark-qt tcpdump
  # exploitation & cracking
  metasploit sqlmap hydra john hashcat
  # reversing / binary
  gdb radare2 binwalk
  # forensics & misc
  exiftool
  # wordlists & vuln db (exploitdb in repo; seclists via AUR to avoid "not found" on some mirrors)
  exploitdb
  # QoL build deps
  git base-devel
)

# AUR-only or mirror-inconsistent packages
AUR_PKGS=(
  ffuf              # HTTP fuzzer
  steghide          # stego tool
  burpsuite         # web proxy (GUI)
  seclists          # common wordlists
  zaproxy           # OWASP ZAP
  cutter            # radare2 GUI
  ghidra            # reversing suite
  stegoveritas      # image forensics
  gobuster          # dir/dns brute-forcer
  wfuzz             # web fuzzer
  dirsearch         # web path brute-forcer
)

# --- pacman config nicety ---
if grep -qE '^\s*#?\s*ParallelDownloads' /etc/pacman.conf; then
  sed -i 's/^#\?\s*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
fi

# --- system update ---
msg "Updating package databases and upgrading system..."
pacman -Syyu --noconfirm

# --- install official repo packages ---
msg "Installing official repo packages via pacman..."
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# --- install yay if missing ---
install_yay() {
  if have yay; then
    msg "AUR helper 'yay' already installed."
    return
  fi
  msg "Installing 'yay' (AUR helper)..."
  workdir="/tmp/yay-build.$$"
  mkdir -p "$workdir"
  chown "$REAL_USER":"$REAL_USER" "$workdir"
  sudo -u "$REAL_USER" bash -lc "
    set -e
    cd '$workdir'
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
  rm -rf "$workdir"
  msg "'yay' installed."
}
install_yay

# --- install AUR packages ---
msg "Installing AUR packages via yay..."
sudo -u "$REAL_USER" yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# --- wireshark capture without root ---
if getent group wireshark >/dev/null 2>&1; then
  msg "Adding $REAL_USER to group 'wireshark' for packet capture..."
  gpasswd -a "$REAL_USER" wireshark >/dev/null || true
fi
if [[ -x /usr/bin/dumpcap ]]; then
  msg "Ensuring dumpcap capabilities (may already be set)..."
  setcap 'cap_net_raw,cap_net_admin+eip' /usr/bin/dumpcap || true
fi

# --- quick verification ---
msg "Verifying key tools..."
VERIFY_CMDS=(
  "nmap --version"
  "ffuf -version"
  "sqlmap --version"
  "hydra -h | head -n1"
  "john --list=build-info | head -n1"
  "hashcat --version"
  "msfconsole --version"
  "radare2 -v"
  "gdb --version | head -n1"
  "binwalk --version"
  "exiftool -ver"
  "burpsuite --version || true"
  "zaproxy --version || true"
  "ghidraRun -version || true"
  "gobuster -h | head -n1 || true"
  "wfuzz -h | head -n1 || true"
  "dirsearch -h | head -n1 || true"
  "searchsploit -v"
)
fail=0
for c in "${VERIFY_CMDS[@]}"; do
  if bash -lc "$c" >/dev/null 2>&1; then
    printf "  [ok] %s\n" "$c"
  else
    printf "  [warn] %s\n" "$c"
    ((fail++)) || true
  fi
done

msg "CTF toolkit installation complete."
echo "Notes:"
echo " • Log out/in for new 'wireshark' group membership to take effect."
echo " • Wordlists are in /usr/share/seclists"
echo " • Exploit DB via 'searchsploit <keyword>'"
((fail>0)) && echo " • Some GUI tools only report versions when launched interactively; warnings above are usually fine."
