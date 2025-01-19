#!/bin/bash

################################
# Choose the disk and partitions
################################
$correct_disk=""
while [ "$correct_disk" = "" ]
do
    confirm_disk=""
    lsblk
    read -p "Enter the name of the disk you want to use from the above list: " disk_name
    disk_name="/dev/${disk_name}"
    fdisk -l | grep $disk_name
    if [ $? -eq 0 ]; then
        while :
        do
            read -p "The device you have chosen is $disk_name, above are its specifications and current partitions. Is it correct? [Y/N] " confirm_disk
            if [[ "$confirm_disk" = "y" ]] || [[ "$confirm_disk" = "Y" ]]; then
                correct_disk=$disk_name
                break
            elif [[ "$confirm_disk" = "n" ]] || [[ "$confirm_disk" = "N" ]]; then
                break
            else
                echo "Character not supported. Use \"Y\" or \"y\" for an affirmative answer, \"N\" or \"n\" otherwise."
            fi
        done
    else
        echo $'The Device does not exist. Retry.\n'
    fi
done
echo "Continuing with ${disk_name}"
echo $disk_name | grep nvme
if [ $? -eq 0 ]; then
    esp_partition="${disk_name}p1"
    boot_partition="${disk_name}p2"
    os_partition="${disk_name}p3"
else
    esp_partition="${disk_name}1"
    boot_partition="${disk_name}2"
    os_partition="${disk_name}3"
fi



######################
# Mount the Partitions
######################
# Mounting functions
mount_btrfs_subvolumes() {
    btrfs_mount_options="relatime,compress=zstd,ssd,space_cache=v2,subvol=$1"
    mount -o $btrfs_mount_options $2 $3
}
mount_drives() {
    mount_btrfs_subvolumes "@" $1 "/mnt"
    mount_btrfs_subvolumes "@snapshots" $1 "/mnt/.snapshots"
    mount_btrfs_subvolumes "@home" $1 "/mnt/home"
    mount_btrfs_subvolumes "@root" $1 "/mnt/root"
    mount_btrfs_subvolumes "@var" $1 "/mnt/var"
    mount_btrfs_subvolumes "@opt" $1 "/mnt/opt"
    mount_btrfs_subvolumes "@srv" $1 "/mnt/srv"
    mount_btrfs_subvolumes "@tmp" $1 "/mnt/tmp"
    mount_btrfs_subvolumes "@usrlocal" $1 "/mnt/usr/local"
    mount_btrfs_subvolumes "@swap" $1 "/mnt/swap"
    mount_btrfs_subvolumes "@media" $1 "/mnt/media"
    mount $boot_partition /mnt/boot
    mount $esp_partition /mnt/boot/efi
}
# Check if the OS Partition is encrypted or not and mount accordingly
lsblk | grep LUKS
if [ $? -eq 0 ]; then
    cryptsetup open $os_partition Arch_LUKS
    mount_drives /dev/mapper/Arch_LUKS
else
    mount_drives $os_partition
fi


######
# GRUB
######
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
umount -R /mnt
reboot