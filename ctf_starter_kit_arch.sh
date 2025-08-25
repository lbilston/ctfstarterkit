#!/usr/bin/env bash
# Arch CTF Toolkit Installer
# Run with: sudo ./setup-ctf.sh

set -euo pipefail

# ---------- helpers ----------
msg() { printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
err() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Determine the "real" non-root user (for group membership / building yay)
REAL_USER="${SUDO_USER:-$(whoami)}"
if [[ "$EUID" -ne 0 ]]; then
  err "Please run as root (e.g., sudo $0)"
  exit 1
fi

# ---------- sanity checks ----------
if ! [[ -f /etc/arch-release ]]; then
  err "This script is intended for Arch Linux (or Arch-based) systems."
  exit 1
fi

# ---------- package lists ----------
PACMAN_PKGS=(
  # networking & scanning
  nmap masscan netcat socat wireshark-qt tcpdump
  # exploitation & pw cracking
  metasploit sqlmap hydra john hashcat
  # web fuzzing and HTTP tooling
  ffuf
  # reversing & binary
  gdb radare2 binwalk
  # forensics & stego
  steghide exiftool
  # proxies & web sec
  burpsuite
  # wordlists & vuln db
  seclists exploitdb
  # quality of life
  git base-devel
)

AUR_PKGS=(
  zaproxy           # OWASP ZAP
  cutter            # GUI for radare2
  ghidra            # NSA Ghidra reverse engineering suite
  stegoveritas      # image forensics suite
  gobuster          # dir/dns brute-forcer
  wfuzz             # web fuzzer
  dirsearch         # web path brute-forcer
)

# ---------- enable parallel downloads (optional) ----------
if grep -qE '^\s*#?\s*ParallelDownloads' /etc/pacman.conf; then
  sudo sed -i 's/^#\?\s*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
fi

# ---------- system update ----------
msg "Updating package databases and the system..."
pacman -Syyu --noconfirm

# ---------- install pacman packages ----------
msg "Installing core CTF packages via pacman..."
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# ---------- install yay (if needed) ----------
install_yay() {
  if have yay; then
    msg "yay already installed."
    return
  fi

  msg "Installing yay (AUR helper)..."
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
  msg "yay installed."
}

install_yay

# ---------- install AUR packages ----------
msg "Installing AUR packages via yay..."
sudo -u "$REAL_USER" yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ---------- wireshark permissions ----------
# Allow non-root capture (requires logout/login to take effect)
if getent group wireshark >/dev/null 2>&1; then
  msg "Adding $REAL_USER to 'wireshark' group for packet capture..."
  gpasswd -a "$REAL_USER" wireshark >/dev/null || true
else
  msg "Group 'wireshark' not found (package may provide). Skipping."
fi

# Ensure dumpcap has capabilities (usually handled by package)
if [[ -x /usr/bin/dumpcap ]]; then
  msg "Ensuring dumpcap has capture capabilities (may already be set)..."
  setcap 'cap_net_raw,cap_net_admin+eip' /usr/bin/dumpcap || true
fi

# ---------- quick verify ----------
msg "Verifying key tools..."
VERIFY_CMDS=(
  "nmap --version"
  "ffuf -version || true"
  "sqlmap --version"
  "hydra -h | head -n1"
  "john --list=build-info | head -n3"
  "hashcat --version"
  "msfconsole --version"
  "radare2 -v"
  "gdb --version | head -n1"
  "binwalk --version"
  "steghide --version || true"
  "exiftool -ver"
  "burpsuite --version || true"
  "zaproxy --version || true"
  "ghidraRun -version || true"
  "gobuster -h | head -n1 || true"
  "wfuzz -h | head -n1 || true"
  "dirsearch -h | head -n1 || true"
  "searchsploit -v"
)

fail_count=0
for cmd in "${VERIFY_CMDS[@]}"; do
  if bash -lc "$cmd" >/dev/null 2>&1; then
    printf "  [ok] %s\n" "$cmd"
  else
    printf "  [warn] %s (not available / failed)\n" "$cmd"
    ((fail_count++)) || true
  fi
done

# ---------- finish ----------
msg "CTF toolkit installation complete."
echo
echo "Notes:"
echo "  • If you plan to capture packets as non-root, log out and back in so 'wireshark' group applies."
echo "  • Wordlists: /usr/share/seclists (try: /usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz)"
echo "  • Exploit DB: 'searchsploit <keyword>'"
echo
if (( fail_count > 0 )); then
  echo "Some tools did not report versions (likely fine for GUI apps/launchers)."
fi
