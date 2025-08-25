#!/usr/bin/env bash
# Arch CTF Toolkit Installer (pacman + AUR + pipx fallbacks)
# Run with: sudo ./setup-ctf.sh
set -euo pipefail

msg() { printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
err() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- Sanity / identity ---
[[ $EUID -eq 0 ]] || { err "Please run as root (e.g., sudo $0)"; exit 1; }
[[ -f /etc/arch-release ]] || { err "This script is intended for Arch/Arch-based systems."; exit 1; }

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
[[ -n "$REAL_USER" ]] || { err "Could not determine the invoking (non-root) user."; exit 1; }
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
USER_SHELL="$(getent passwd "$REAL_USER" | cut -d: -f7)"
USER_LOCAL_BIN="${USER_HOME}/.local/bin"

# --- Package sets ---
PACMAN_PKGS=(
  # networking & scanning
  nmap masscan openbsd-netcat socat wireshark-qt tcpdump
  # exploitation & cracking
  metasploit sqlmap hydra john hashcat
  # reversing / binary
  gdb radare2 binwalk
  # forensics & misc
  exiftool
  # vuln db
  exploitdb
  # build deps / tools
  git base-devel curl gcc python python-pipx python-setuptools python-wheel
)

AUR_PKGS=(
  # GUI / websec / reversing
  burpsuite zaproxy cutter ghidra
  # wordlists
  seclists
  # fuzzers & helpers (we add pipx fallbacks below)
  ffuf gobuster wfuzz dirsearch
  # path brute-forcer
  dirsearch
  # extras
  stegoveritas
)

# --- Pacman nicety: parallel downloads ---
if grep -qE '^\s*#?\s*ParallelDownloads' /etc/pacman.conf; then
  sed -i 's/^#\?\s*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
fi

# --- Update system ---
msg "Updating package databases and upgrading system..."
pacman -Syyu --noconfirm

# --- Install official repo packages ---
msg "Installing official repo packages via pacman..."
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# --- Ensure user's ~/.local/bin exists (pipx puts shims here) ---
mkdir -p "$USER_LOCAL_BIN"
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.local" || true

# --- Install yay if missing ---
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

# --- Try installing AUR packages (best-effort group install) ---
msg "Installing AUR packages via yay (best-effort)..."
if ! sudo -u "$REAL_USER" yay -S --needed --noconfirm "${AUR_PKGS[@]}"; then
  warn "One or more AUR packages failed to build (expected occasionally). Will apply targeted fallbacks."
fi

# --- pipx helpers & PATH handling for the user ---
ensure_pipx() {
  if ! have pipx; then
    msg "Ensuring pipx is installed..."
    pacman -S --needed --noconfirm python python-pipx python-setuptools python-wheel
  fi
  # Ensure user's PATH contains ~/.local/bin for future shells
  sudo -u "$REAL_USER" pipx ensurepath || true

  # For *this script's* verification, augment PATH when we run as the user
  # We'll use: sudo -u "$REAL_USER" bash -lc 'PATH="$HOME/.local/bin:$PATH" <cmd>'
}

# --- wfuzz fallback: prefer AUR; if missing, use pipx with system pycurl ---
ensure_pipx
if ! sudo -u "$REAL_USER" bash -lc 'command -v wfuzz >/dev/null 2>&1'; then
  msg "wfuzz missing after AUR install; installing via pipx with system pycurl…"
  pacman -S --needed --noconfirm python-pycurl
  if ! sudo -u "$REAL_USER" bash -lc 'pipx install --system-site-packages wfuzz'; then
    warn "pipx wfuzz install failed, retrying with binary-only wheels…"
    sudo -u "$REAL_USER" bash -lc 'pipx install --system-site-packages --pip-args="--only-binary :all:" wfuzz' || warn "wfuzz still failed; you can try later manually."
  fi
fi

# --- dirsearch fallback: pure-Python, easy via pipx if AUR failed ---
if ! sudo -u "$REAL_USER" bash -lc 'command -v dirsearch >/dev/null 2>&1'; then
  msg "dirsearch missing after AUR install; installing via pipx…"
  sudo -u "$REAL_USER" bash -lc 'pipx install dirsearch' || warn "dirsearch pipx install failed."
fi

# --- wireshark capture without root ---
if getent group wireshark >/dev/null 2>&1; then
  msg "Adding $REAL_USER to group 'wireshark' for packet capture…"
  gpasswd -a "$REAL_USER" wireshark >/dev/null || true
else
  warn "Group 'wireshark' not found; check wireshark package."
fi
if [[ -x /usr/bin/dumpcap ]]; then
  msg "Ensuring dumpcap capabilities (may already be set)…"
  setcap 'cap_net_raw,cap_net_admin+eip' /usr/bin/dumpcap || true
fi

# --- Verification (run as user with ~/.local/bin in PATH) ---
msg "Verifying key tools…"
USER_PATH_PREFIX='export PATH="$HOME/.local/bin:$PATH";'
verify_as_user() { sudo -u "$REAL_USER" bash -lc "$USER_PATH_PREFIX $*"; }

VERIFY_CMDS=(
  "nmap --version"
  "ffuf -version || true"
  "wfuzz -h | head -n1 || true"
  "dirsearch -h | head -n1 || true"
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
  "searchsploit -v"
)

fail=0
for c in "${VERIFY_CMDS[@]}"; do
  if verify_as_user "$c" >/dev/null 2>&1; then
    printf "  [ok] %s\n" "$c"
  else
    printf "  [warn] %s\n" "$c"
    ((fail++)) || true
  fi
done

msg "CTF toolkit installation complete."
echo "Notes:"
echo " • If packet capture as non-root fails, log out and back in so 'wireshark' group applies."
echo " • Wordlists: /usr/share/seclists"
echo " • Exploit DB search: 'searchsploit <keyword>'"
((fail>0)) && echo " • Some GUI tools only print versions when launched; warnings above are usually harmless."
