#!/bin/bash

#########################################
# Use the correct Keyboard Layout on SDDM
#########################################
localectl set-keymap it


#######################
# Snapper Configuration
#######################
sudo umount /.snapshots
sudo rm -rf /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo systemctl daemon-reload
sudo mount -a
sudo snapper -c root set-config ALLOW_GROUPS=wheel SYNC_ACL=yes TIMELINE_LIMIT_HOURLY="5" TIMELINE_LIMIT_DAILY="7" TIMELINE_LIMIT_WEEKLY="0" TIMELINE_LIMIT_MONTHLY="0"
sudo snapper -c home create-config /home
sudo snapper -c home set-config ALLOW_GROUPS=wheel SYNC_ACL=yes TIMELINE_LIMIT_HOURLY="5" TIMELINE_LIMIT_DAILY="7" TIMELINE_LIMIT_WEEKLY="0" TIMELINE_LIMIT_MONTHLY="0"
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now grub-btrfsd
sudo snapper --config root create --description "First Root Snapshot" --cleanup-algorithm timeline
sudo snapper --config home create --description "First Home Snapshot" --cleanup-algorithm timeline
yay -Syu --noconfirm snap-pac


####################
# User Configuration
####################
mkdir $HOME/.CustomScripts
cp -r ./CustomScripts/* $HOME/.CustomScripts
echo "
# Add Custom Scripts folder to PATH
export PATH=$PATH:$HOME/.CustomScripts

# Customize Prompt
# Colors
BLACK=\"\e[1;30m\"
RED=\"\e[1;31m\"
GREEN=\"\e[1;32m\"
YELLOW=\"\e[1;33m\"
BLUE=\"\e[1;34m\"
MAGENTA=\"\e[1;35m\"
CYAN=\"\e[1;36m\"
WHITE=\"\e[1;37m\"
RESET=\"\e[0m\"
# Prompt
PS1=\"${GREEN}[\\u@\\h]${RESET} \\w \\$ \"

fastfetch" >> $HOME/.bashrc


############
# Enable AUR
############
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
yay -Syu --noconfirm


###################
# Reduce Swappiness
###################
echo "vm.swappiness=5" | sudo tee /etc/sysctl.d/01-swappiness.conf


####################
# ZRAM Configuration
####################
yay -Syu --noconfirm zram-generator
echo "[zram0]
zram-size = ram
compression-algorithm = zstd" | sudo tee /etc/systemd/zram-generator.conf
sudo systemctl enable systemd-zram-setup@zram0.service


####################
# Swap Configuration
####################
sudo fallocate -l 32G /swap/swapfile0
sudo chmod 600 /swap/swapfile0
sudo mkswap /swap/swapfile0
echo "
# Swapfile
/swap/swapfile0 none swap sw 0 0" | sudo tee -a /etc/fstab


#################################################
# Enable Flatpaks (both stable and beta channels)
#################################################
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
yay -Syu --noconfirm flatpak-builder


###########
# Dev Tools
###########
# C
sudo pacman -Syu --noconfirm gcc make cmake extra-cmake-modules ninja
# Java
sudo pacman -Syu --noconfirm jdk-openjdk
# Python
sudo pacman -Syu --noconfirm python
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# LaTeX
sudo pacman -Syu --noconfirm texlive texlive-lang biber
# IDEs
yay -Syu --noconfirm visual-studio-code-bin jetbrains-toolbox arduino-ide


##################
# Containerization
##################
# Podman
sudo pacman -Syu --noconfirm podman podman-compose
# Docker
yay -Syu --noconfirm docker docker-compose docker-desktop
sudo usermod -aG docker $(whoami)
sudo systemctl enable --now docker.service
# Tools
yay -Syu --noconfirm distrobox


######################
# Virtualization Tools
######################
# VirtualBox
yay -Syu virtualbox virtualbox-host-modules-arch virtualbox-guest-iso virtualbox-ext-oracle
sudo usermod -aG vboxusers $(whoami)
# VMware
yay -Syu --noconfirm fuse2 gtkmm ncurses libcanberra pcsclite gcc make libaio vmware-workstation
sudo systemctl start vmware-networks-configuration.service
sudo systemctl enable --now vmware-networks.service
sudo systemctl enable --now vmware-usbarbitrator.service
echo "mks.gl.allowBlacklistedDrivers = TRUE" >> $HOME/.vmware/preferences
# QEMU/KVM
yay -Syu qemu-full libvirt dnsmasq openbsd-netcat virt-manager virt-viewer vde2 bridge-utils ebtables libguestfs
lscpu | grep AMD
if [ $? -eq 0 ]; then
    sudo modprobe -r kvm_amd
    sudo modprobe kvm_amd nested=1
    echo "options kvm-amd nested=1" | sudo tee /etc/modprobe.d/kvm-amd.conf
else
    sudo modprobe -r kvm_intel
    sudo modprobe kvm_intel nested=1
    echo "options kvm-intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf
fi
sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/g' /etc/libvirt/libvirtd.conf
sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/g' /etc/libvirt/libvirtd.conf
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG qemu $(whoami)
sudo systemctl enable --now libvirtd
sudo virsh net-autostart default
# GNS3
yay -Syu --noconfirm ubridge virtualbox-sdk wireshark-qt vpcs dynamips gns3-server gns3-gui
sudo usermod -aG wireshark $(whoami)
sudo systemctl enable --now gns3-server@$(whoami)


#####################
# Native Applications
#####################
yay -Syu --noconfirm zerotier-one nextcloud-client qpdf inkscape appimagelauncher-bin game-devices-udev oversteer fastfetch
sudo systemctl enable --now zerotier-one


##########################
# Flatpak KDE Applications
##########################
flatpak -y install flathub org.kde.kdevelop
flatpak -y install flathub org.kde.krdc
flatpak -y install flathub org.kde.okular
flatpak -y install flathub io.github.wereturtle.ghostwriter
flatpak -y install flathub org.kde.gwenview
flatpak -y install flathub org.kde.kile
flatpak -y install flathub org.kde.kclock
flatpak -y install flathub org.kde.marknote
flatpak -y install flathub org.kde.kalk
flatpak -y install flathub org.gtk.Gtk3theme.Breeze


###########################
# Flatpak Misc Applications
###########################
flatpak -y install flathub com.github.Eloston.UngoogledChromium
flatpak -y install flathub io.gitlab.librewolf-community
flatpak -y install flathub org.keepassxc.KeePassXC
flatpak -y install flathub com.bitwarden.desktop
flatpak -y install flathub org.telegram.desktop
flatpak -y install flathub-beta com.discordapp.DiscordCanary
flatpak -y install flathub com.github.reds.LogisimEvolution
flatpak -y install flathub com.usebottles.bottles
flatpak -y install flathub org.libreoffice.LibreOffice
flatpak -y install flathub org.onlyoffice.desktopeditors
flatpak -y install flathub com.github.xournalpp.xournalpp
flatpak -y install flathub com.github.flxzt.rnote
flatpak -y install flathub ch.openboard.OpenBoard
flatpak -y install flathub org.qownnotes.QOwnNotes
flatpak -y install flathub org.octave.Octave
flatpak -y install flathub org.texstudio.TeXstudio
flatpak -y install flathub net.xm1math.Texmaker
flatpak -y install flathub org.freecadweb.FreeCAD
flatpak -y install flathub org.librecad.librecad
flatpak -y install flathub com.jgraph.drawio.desktop
flatpak -y install flathub org.qgis.qgis
flatpak -y install flathub io.mpv.Mpv
flatpak -y install flathub org.gimp.GIMP
flatpak -y install flathub com.boxy_svg.BoxySVG
flatpak -y install flathub org.inkscape.Inkscape
flatpak -y install flathub org.kde.krita
flatpak -y install flathub org.blender.Blender
flatpak -y install flathub org.kde.kdenlive
flatpak -y install flathub fr.handbrake.ghb
flatpak -y install flathub org.audacityteam.Audacity
flatpak -y install flathub com.spotify.Client
flatpak -y install flathub com.obsproject.Studio
flatpak -y install flathub com.valvesoftware.Steam
flatpak -y install flathub net.lutris.Lutris
flatpak -y install flathub com.heroicgameslauncher.hgl
flatpak -y install flathub org.libretro.RetroArch
flatpak -y install flathub org.duckstation.DuckStation
flatpak -y install flathub net.pcsx2.PCSX2
flatpak -y install flathub org.ppsspp.PPSSPP
flatpak -y install flathub org.DolphinEmu.dolphin-emu


################################################
# Apply the correct theming for GTK Applications
################################################
flatpak override --user --filesystem=xdg-config/gtk-3.0:ro


###########################
# Set up Ungoogled Chromium
###########################
flatpak run io.github.ungoogled_software.ungoogled_chromium
cp ./CustomConfigs/chromium-flags.conf $HOME/.var/app/io.github.ungoogled_software.ungoogled_chromium/config/
wget https://raw.githubusercontent.com/ungoogled-software/ungoogled-chromium-flatpak/master/widevine-install.sh -P ./CustomConfigs
chmod +x ./CustomConfigs/widevine-install.sh
bash ./CustomConfigs/widevine-install.sh


#######################
# Appimage Applications
#######################
mkdir /media/AppImages
wget https://github.com/olive-editor/olive/releases/download/0.2.0-nightly/Olive-8ac191ce-Linux-x86_64.AppImage -P /media/AppImages
chmod +x /media/AppImages/*.AppImage
/media/AppImages/*.AppImage