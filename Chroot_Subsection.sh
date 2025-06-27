#!/bin/bash

#####################################
# Disable CoW for var, swap and media
#####################################
sudo chattr -R -f +C /var
sudo chattr -R -f +C /swap
sudo chattr -R -f +C /media


###############
# Time and date
###############
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc


##############
# Localization
##############
sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
sed -i 's/#it_IT.UTF-8/it_IT.UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=it
XKBLAYOUT=it
XKBMODEL=pc105" > /etc/vconsole.conf


###############
# System Config
###############
read -p "Type the desired hostname for this machine: " hostname
echo $hostname > /etc/hostname
echo "Type your root password."
passwd
while [ $? -ne 0 ]
do
    echo "Root Password has not been set. Retry."
    passwd
done
echo "Root password set."
sed -i 's/#Color/Color/g' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf
sed -i ':a;N;$!ba;s/#DisableSandbox/#DisableSandbox\nILoveCandy/g' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Syu


##############
# User Account
##############
read -p "Type your unix username: " username
useradd -m -G wheel -s /bin/bash $username
echo "Type your user's password"
passwd $username
while [ $? -ne 0 ]
do
    echo "Your User's Password has not been set. Retry."
    passwd $username
done
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
chown -R $username:$username /media


######################################
# Install basic utilities and firmware
######################################
pacman -Syu --noconfirm btrfs-progs snapper
# CPU uCode
iommu_module=""
lscpu | grep AMD
if [ $? -eq 0 ]; then
    echo "You have an AMD CPU."
    pacman -Syu --noconfirm amd-ucode
    iommu_module="amd_iommu"
else
    echo "You have an Intel CPU."
    pacman -Syu --noconfirm intel-ucode
    iommu_module="intel_iommu"
fi
# GPU Drivers
# Check if you have an Intel GPU
lspci | grep VGA | grep Intel
if [ $? -eq 0 ]; then
    echo "You have an Intel GPU."
    pacman -Syu --noconfirm mesa lib32-mesa intel-media-driver lib32-intel-media-driver vulkan-intel lib32-vulkan-intel ocl-icd opencl-headers opencl-clhpp opencl-mesa lib32-opencl-mesa intel-compute-runtime intel-gpu-tools
    echo "#GPU Hardware Acceleration
LIBVA_DRIVER_NAME=i965
VDPAU_DRIVER=va_gl" > /etc/environment
fi
# Check if you have an AMD GPU
lspci | grep VGA | grep AMD
if [ $? -eq 0 ]; then
    echo "You have an AMD GPU."
    pacman -Syu --noconfirm mesa lib32-mesa mesa-utils lib32-mesa-utils libvdpau-va-gl vulkan-radeon lib32-vulkan-radeon ocl-icd opencl-headers opencl-clhpp opencl-mesa lib32-opencl-mesa rocm-hip-sdk rocm-hip-runtime rocm-opencl-sdk rocm-opencl-runtime rocm-opencl-sdk radeontop
    echo "#GPU Hardware Acceleration
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi" > /etc/environment
fi
# Check if you have an NVIDIA GPU
lspci | grep VGA | grep NVIDIA
if [ $? -eq 0 ]; then
    echo "You have an NVIDIA GPU."
    pacman -Syu --noconfirm nvidia cuda nvidia-utils lib32-nvidia-utils libva-nvidia-driver ocl-icd opencl-headers opencl-nvidia lib32-opencl-nvidia
    echo "#GPU Hardware Acceleration
LIBVA_DRIVER_NAME=nvidia
VDPAU_DRIVER=nvidia" > /etc/environment
    mkdir /etc/pacman.d/hooks/
    echo "[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
# You can remove package(s) that don't apply to your config, e.g. if you only use nvidia-open you can remove nvidia-lts as a Target
Target=nvidia
Target=nvidia-open
Target=nvidia-lts
# If running a different kernel, modify below to match
Target=linux

[Action]
Description=Updating NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'" > /etc/pacman.d/hooks/nvidia.hook
fi
pacman -Syu --noconfirm libva-utils vdpauinfo vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools clinfo


############
# mkinitcpio
############
# Check if the root partition is encrypted with LUKS and add hooks to the mkinitcpio configuration if needed
lsblk | grep LUKS
if [ $? -eq 0 ]; then
    echo "The OS is on an encrypted partition."
    sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/g' /etc/mkinitcpio.conf
else
    echo "The OS is not on an encrypted partition."
fi
mkinitcpio -P


######
# GRUB
######
# If the OS resides in an encrypted partition, also add the cryptdevice setup
decrypted_os_partition="$1"
pacman -Syu --noconfirm grub efibootmgr os-prober inotify-tools grub-btrfs
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/g' /etc/default/grub
lsblk | grep LUKS
if [ $? -eq 0 ]; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 cryptdevice=${decrypted_os_partition}:Arch_LUKS Arch_LUKS=/dev/mapper/Arch_LUKS ${iommu_module}=on\"|" /etc/default/grub
else
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 ${iommu_module}=on\"|" /etc/default/grub
fi
sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg


##########
# Firewall
##########
pacman -Syu --noconfirm ufw
systemctl enable ufw
ufw enable


#################
# DE Installation
#################
while :
do
    echo "Which Desktop Environment do you want to install?"
    echo "1. GNOME"
    echo "2. Plasma"
    read -p "[1/2] " de
    if [[ "$de" = "1" ]]; then
        echo "Installing GNOME"
        pacman -Syu --noconfirm gnome networkmanager gnome-tweaks cpupower power-profiles-daemon gvfs gvfs-smb cifs-utils sshfs cups gst-plugin-pipewire  adw-gtk-theme
        pacman -R --noconfirm gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-font-viewer gnome-logs gnome-maps gnome-music gnome-text-editor gnome-tour gnome-weather loupe simple-scan snapshot totem epiphany decibels
        systemctl enable gdm

        break
    elif [[ "$de" = "2" ]]; then
        echo "Installing Plasma"
        pacman -Syu --noconfirm plasma dolphin konsole spectacle krfb ark partitionmanager fcitx5-im kcm-fcitx5 kde-gtk-config breeze-gtk print-manager cups system-config-printer kaccounts-providers kio-gdrive kdenetwork-filesharing gvfs gvfs-smb cifs-utils kde-pim kdepim-addons kdeconnect sshfs xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde xdg-user-dirs cpupower power-profiles-daemon
        systemctl enable sddm
        break
    else
        echo "Option not supported. Use 1 to install GNOME or 2 to install Plasma."
    fi
done
systemctl enable cups
systemctl enable cpupower
systemctl enable NetworkManager


##############
# Useful tools
##############
pacman -Syu --noconfirm rclone rsync wget bash-completion stress s-tui github-cli htop btop man less tree patchelf