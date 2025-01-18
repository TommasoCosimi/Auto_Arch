#!/bin/bash

#################
# Choose the disk
#################
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


####################
# Partition the Disk
####################
# Create a new GPT Partition table and three partitions:
# - ESP - Will be mounted in /boot/efi
# - Boot - Will be mounted in /boot
# - OS - Will be a BTRFS partition with multiple subvolumes
parted $disk_name mklabel gpt
parted $disk_name mkpart primary fat32 1MiB 1025MiB
parted $disk_name set 1 esp on
parted $disk_name mkpart primary ext4 1025MiB 2049MiB
parted $disk_name mkpart primary BTRFS 2049MiB 100%
partprobe $disk_name
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


###########################
# Formatting the partitions
###########################
echo "Formatting the ESP and Boot partitions."
mkfs.fat -F 32 -n ESP $esp_partition
mkfs.btrfs -f -L Boot $boot_partition


############
# Disk Crypt
############
crypt_setup=0
decrypted_os_partition=""
while :
do
    read -p "Do you want to crypt the OS Partition? [Y/N] " crypt_prompt
    if [[ "$crypt_prompt" = "y" ]] || [[ "$crypt_prompt" = "Y" ]]; then
        echo "The OS Partition will be encrypted."
        crypt_setup=1
        break
    elif [[ "$crypt_prompt" = "n" ]] || [[ "$crypt_prompt" = "N" ]]; then
        echo "The OS Partition will not be encrypted."
        break
    else
        echo "Character not supported. Use \"Y\" or \"y\" for an affirmative answer, \"N\" or \"n\" otherwise."
    fi
done
if [ $crypt_setup -eq 1 ]; then
    cryptsetup -v luksFormat $os_partition
    cryptsetup open $os_partition Arch_LUKS
    mkfs.btrfs -f -L Arch_Linux /dev/mapper/Arch_LUKS
    decrypted_os_partition="/dev/mapper/Arch_LUKS"
else
    mkfs.btrfs -f -L Arch_Linux $os_partition
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
    mount $1 /mnt
    cd /mnt
    btrfs subvolume create @
    btrfs subvolume create @snapshots
    btrfs subvolume create @home
    btrfs subvolume create @root
    btrfs subvolume create @var
    btrfs subvolume create @opt
    btrfs subvolume create @srv
    btrfs subvolume create @tmp
    btrfs subvolume create @usrlocal
    btrfs subvolume create @swap
    btrfs subvolume create @media
    cd ..
    umount $1
    mount_btrfs_subvolumes "@" $1 "/mnt"
    mkdir /mnt/boot
    mkdir /mnt/.snapshots
    mkdir /mnt/home
    mkdir /mnt/root
    mkdir /mnt/var
    mkdir /mnt/opt
    mkdir /mnt/srv
    mkdir /mnt/tmp
    mkdir -p /mnt/usr/local
    mkdir /mnt/swap
    mkdir /mnt/media
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
    mkdir /mnt/boot/efi
    mount $esp_partition /mnt/boot/efi
}
# Check if the OS Partition is encrypted or not and mount accordingly
if [ $crypt_setup -eq 1 ]; then
    mount_drives $decrypted_os_partition
else
    mount_drives $os_partition
fi


##########
# Pacstrap
##########
pacstrap -K /mnt base base-devel linux linux-firmware linux-headers nano vim git tar


################################
# Generate the File System Table
################################
genfstab -U /mnt >> /mnt/etc/fstab


###################
# End of first part
###################
cp /root/Auto_Arch/Chroot_Subsection.sh /mnt/Chroot_Subsection.sh
arch-chroot /mnt /Chroot_Subsection.sh $os_partition
rm -r /mnt/Chroot_Subsection.sh
umount -R /mnt
reboot