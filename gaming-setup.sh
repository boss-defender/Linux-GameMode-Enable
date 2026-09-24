#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=${0##*/}

fail() {
  printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

[[ -r /etc/os-release ]] || fail 'cannot identify this Linux distribution (/etc/os-release is missing).'
# shellcheck disable=SC1091
. /etc/os-release

OS_ID=${ID,,}
OS_LIKE=${ID_LIKE:-}
OS_LIKE=${OS_LIKE,,}
OS_VERSION=${VERSION_ID:-}
OS_PRETTY_NAME=${PRETTY_NAME:-$OS_ID}

case "$OS_ID" in
  fedora)
    DISTRO=fedora
    ;;
  ubuntu)
    DISTRO=ubuntu
    ;;
  debian)
    case "$OS_VERSION" in
      13|13.*) DISTRO=debian13 ;;
      *) fail "Debian $OS_VERSION detected; this script supports Debian 13 only." ;;
    esac
    ;;
  arch)
    DISTRO=arch
    ;;
  *)
    if [[ " $OS_LIKE " == *" arch "* ]]; then
      DISTRO=arch
    else
      fail "unsupported distribution: $OS_PRETTY_NAME. Supported: Fedora, Ubuntu, Debian 13, and Arch-based distributions."
    fi
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail "this package set requires 64-bit x86 (x86_64); detected $(uname -m)." ;;
esac

if (( EUID == 0 )); then
  SUDO=()
else
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required; run this script as root or install sudo.'
  sudo -v || fail 'could not obtain sudo privileges.'
  SUDO=(sudo)
fi

root_run() {
  "${SUDO[@]}" "$@"
}

has_apt_candidate() {
  apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ { if ($2 != "(none)") found=1 } END { exit !found }'
}

install_optional_gamescope_apt() {
  if has_apt_candidate gamescope; then
    root_run apt-get install -y gamescope
  else
    note 'gamescope is not available from the currently enabled APT repositories; skipping it.'
  fi
}

backup_once() {
  local file=$1
  if [[ ! -e "$file.gaming-setup.bak" ]]; then
    root_run cp -a -- "$file" "$file.gaming-setup.bak"
  fi
}

enable_debian_components() {
  local file temp
  local -a list_files=() source_files=()

  [[ ! -f /etc/apt/sources.list ]] || list_files+=(/etc/apt/sources.list)
  shopt -s nullglob
  list_files+=(/etc/apt/sources.list.d/*.list)
  source_files+=(/etc/apt/sources.list.d/*.sources)
  shopt -u nullglob

  # Debian packages Steam in contrib. Add the standard gaming-related archive
  # components to official Debian entries without changing unrelated sources.
  for file in "${list_files[@]}"; do
    [[ -f "$file" ]] || continue
    temp=$(mktemp)
    awk '
      /^[[:space:]]*deb(-src)?[[:space:]]/ && /(deb\.debian\.org|security\.debian\.org)/ {
        if ($0 !~ /(^|[[:space:]])contrib([[:space:]]|$)/) $0 = $0 " contrib"
        if ($0 !~ /(^|[[:space:]])non-free([[:space:]]|$)/) $0 = $0 " non-free"
        if ($0 !~ /(^|[[:space:]])non-free-firmware([[:space:]]|$)/) $0 = $0 " non-free-firmware"
      }
      { print }
    ' "$file" > "$temp"
    if ! cmp -s "$temp" "$file"; then
      backup_once "$file"
      root_run install -o root -g root -m 0644 -- "$temp" "$file"
    fi
    rm -f -- "$temp"
  done

  for file in "${source_files[@]}"; do
    [[ -f "$file" ]] || continue
    temp=$(mktemp)
    awk '
      function emit(    i, j, wanted) {
        if (stanza_n == 0) return
        if (debian_uri && trixie_suite) {
          for (i = 1; i <= stanza_n; i++) {
            if (stanza[i] ~ /^Components:[[:space:]]*/) {
              for (j = 1; j <= 3; j++) {
                wanted = (j == 1 ? "contrib" : (j == 2 ? "non-free" : "non-free-firmware"))
                if (stanza[i] !~ ("(^|[[:space:]])" wanted "([[:space:]]|$)")) stanza[i] = stanza[i] " " wanted
              }
            }
          }
        }
        for (i = 1; i <= stanza_n; i++) print stanza[i]
        print ""
        for (i in stanza) delete stanza[i]
        stanza_n = 0
        debian_uri = 0
        trixie_suite = 0
      }
      /^$/ { emit(); next }
      {
        stanza[++stanza_n] = $0
        if ($0 ~ /^URIs:[[:space:]]/ && $0 ~ /(deb\.debian\.org|security\.debian\.org)/) debian_uri = 1
        if ($0 ~ /^Suites:[[:space:]]/ && $0 ~ /(^|[[:space:]])trixie([[:space:]-]|$)/) trixie_suite = 1
      }
      END { emit() }
    ' "$file" > "$temp"
    if ! cmp -s "$temp" "$file"; then
      backup_once "$file"
      root_run install -o root -g root -m 0644 -- "$temp" "$file"
    fi
    rm -f -- "$temp"
  done
}

note "Detected: $OS_PRETTY_NAME"
note 'This will update the system and install gaming packages.'

case "$DISTRO" in
  fedora)
    [[ ! -e /run/ostree-booted ]] || fail 'rpm-ostree based Fedora editions need a different installation method; this script targets traditional DNF Fedora.'
    command -v dnf >/dev/null 2>&1 || fail 'dnf is not installed; this script targets traditional Fedora installations, not rpm-ostree editions.'
    note 'Updating Fedora and enabling RPM Fusion Free and Nonfree repositories...'
    root_run dnf upgrade --refresh -y
    fedora_version=$(rpm -E '%fedora')
    [[ "$fedora_version" =~ ^[0-9]+$ ]] || fail 'could not determine the Fedora release number.'
    root_run dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
    root_run dnf upgrade --refresh -y
    root_run dnf install -y fedora-workstation-repositories
    note 'Installing Fedora gaming packages...'
    root_run dnf --enablerepo=rpmfusion-nonfree-steam install -y \
      steam steam-devices lutris wine winetricks gamemode mangohud gamescope \
      vulkan-tools mesa-dri-drivers mesa-dri-drivers.i686 \
      mesa-vulkan-drivers mesa-vulkan-drivers.i686 \
      vulkan-loader vulkan-loader.i686 mesa-demos
    ;;
  arch)
    command -v pacman >/dev/null 2>&1 || fail 'pacman was not found on this Arch-based system.'
    pacman_conf=/etc/pacman.conf
    [[ -f "$pacman_conf" ]] || fail "$pacman_conf was not found."

    multilib_ready() {
      awk '
        /^[[:space:]]*\[/ {
          in_multilib = ($0 ~ /^[[:space:]]*\[multilib\][[:space:]]*$/)
          next
        }
        in_multilib && /^[[:space:]]*Include[[:space:]]*=[[:space:]]*\/etc\/pacman\.d\/mirrorlist[[:space:]]*$/ { found=1 }
        END { exit !found }
      ' "$pacman_conf"
    }

    enable_multilib() {
      local temp
      temp=$(mktemp)
      awk '
        function finish_multilib() {
          if (in_multilib && !include_seen) print "Include = /etc/pacman.d/mirrorlist"
        }
        /^[[:space:]]*#?[[:space:]]*\[multilib\][[:space:]]*$/ {
          finish_multilib()
          in_multilib = 1
          include_seen = 0
          section_seen = 1
          sub(/^[[:space:]]*#/, "")
          print
          next
        }
        /^[[:space:]]*\[/ {
          finish_multilib()
          in_multilib = 0
        }
        in_multilib && /^[[:space:]]*#?[[:space:]]*Include[[:space:]]*=[[:space:]]*\/etc\/pacman\.d\/mirrorlist[[:space:]]*$/ {
          sub(/^[[:space:]]*#/, "")
          include_seen = 1
        }
        { print }
        END {
          finish_multilib()
          if (!section_seen) {
            print ""
            print "[multilib]"
            print "Include = /etc/pacman.d/mirrorlist"
          }
        }
      ' "$pacman_conf" > "$temp"
      root_run install -o root -g root -m 0644 -- "$temp" "$pacman_conf"
      rm -f -- "$temp"
    }

    if ! multilib_ready; then
      backup_once "$pacman_conf"
      enable_multilib
    fi
    multilib_ready || fail 'could not enable the multilib repository in /etc/pacman.conf.'

    note 'Updating Arch-based system and installing gaming packages...'
    root_run pacman -Syu --noconfirm --needed \
      steam lutris wine winetricks gamemode lib32-gamemode \
      mangohud lib32-mangohud gamescope vulkan-tools mesa lib32-mesa \
      vulkan-icd-loader lib32-vulkan-icd-loader
    ;;
  ubuntu)
    command -v apt-get >/dev/null 2>&1 || fail 'apt-get was not found.'
    note 'Enabling i386 packages and Ubuntu Universe/Multiverse repositories...'
    root_run dpkg --add-architecture i386
    root_run apt-get update
    root_run apt-get install -y software-properties-common
    root_run add-apt-repository -y universe
    root_run add-apt-repository -y multiverse
    root_run apt-get update
    root_run apt-get full-upgrade -y
    note 'Installing Ubuntu gaming packages...'
    root_run apt-get install -y \
      steam-installer lutris wine winetricks gamemode mangohud vulkan-tools \
      mesa-vulkan-drivers mesa-vulkan-drivers:i386 libvulkan1 libvulkan1:i386 \
      libgl1-mesa-dri:i386
    install_optional_gamescope_apt
    ;;
  debian13)
    command -v apt-get >/dev/null 2>&1 || fail 'apt-get was not found.'
    note 'Enabling i386 packages and Debian contrib/non-free components for Steam...'
    root_run dpkg --add-architecture i386
    enable_debian_components
    root_run apt-get update
    has_apt_candidate steam-installer || fail 'steam-installer is unavailable. Check that your Debian 13 APT sources include contrib and support amd64/i386.'
    root_run apt-get full-upgrade -y
    note 'Installing Debian 13 gaming packages...'
    root_run apt-get install -y \
      steam-installer lutris wine winetricks gamemode mangohud vulkan-tools \
      mesa-vulkan-drivers mesa-vulkan-drivers:i386 libvulkan1 libvulkan1:i386 \
      libgl1-mesa-dri:i386
    install_optional_gamescope_apt
    ;;
esac

note 'Gaming package setup completed.'
note 'If you use NVIDIA graphics, install the NVIDIA driver and its 32-bit libraries for your distribution; the Mesa packages here are for Mesa-supported graphics.'
