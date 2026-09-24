# 🚀 Linux_GameMode_Enable
## 🎮 Using script or a single line command, make linux ready for gaming. 

**⚠️ Supported Only: Fedora, Ubuntu, Debian 13 (Trixie), Arch / Arch-based**

---

**⚡ Download the gaming-setup.sh file and run ./gaming-setup.sh in terminal . Boom!**

---

## Or, 

**For fedora linux:**

```text
sudo dnf upgrade --refresh -y && sudo dnf install -y [https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm](https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm) -E %fedora).noarch.rpm [https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm](https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm) -E %fedora).noarch.rpm && sudo dnf upgrade --refresh -y && sudo dnf install -y steam gamemode mangohud gamescope vulkan-tools mesa-dri-drivers mesa-vulkan-drivers mesa-vulkan-drivers.i686 vulkan-loader vulkan-loader.i686 mesa-demos lutris wine winetricks
```

**For arch based linux:**

```text
sudo pacman -Syu --noconfirm --needed steam lutris wine winetricks gamemode lib32-gamemode mangohud lib32-mangohud gamescope vulkan-tools mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
```

or , 

```text
sudo bash -c 'if grep -q "^\[multilib\]" /etc/pacman.conf; then echo "multilib already enabled"; elif grep -q "^#\[multilib\]" /etc/pacman.conf; then sed -i "/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//" /etc/pacman.conf; else printf "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" >> /etc/pacman.conf; fi; pacman -Syu --noconfirm --needed steam lutris wine winetricks gamemode lib32-gamemode mangohud lib32-mangohud gamescope vulkan-tools mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
```

**For ubuntu :**

```text
sudo dpkg --add-architecture i386 && sudo add-apt-repository universe && sudo add-apt-repository multiverse && sudo apt update && sudo apt full-upgrade -y && sudo apt install -y steam-installer lutris wine winetricks gamemode mangohud vulkan-tools mesa-vulkan-drivers mesa-vulkan-drivers:i386 libvulkan1 libvulkan1:i386 gamescope
```

**For Debian 13 :** 

```text
sudo dpkg --add-architecture i386 && sudo apt update && sudo apt full-upgrade -y && sudo apt install -y steam-installer lutris wine winetricks gamemode mangohud vulkan-tools mesa-vulkan-drivers mesa-vulkan-drivers:i386 libvulkan1 libvulkan1:i386 && (apt-cache show gamescope >/dev/null 2>&1 && sudo apt install -y gamescope || echo "gamescope is not available in this Debian release/repository")
```
