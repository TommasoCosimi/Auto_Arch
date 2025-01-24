# Auto_Arch

Install and Post-Install scripts to automate my Arch Installation.

Note that this collection of scripts has been studied to automate **my** Arch Linux installation process and may or may not be compatible with what your tastes are, but it can be a starting point for your own script collection in case it isn't.


## Usage

After booting the Arch Live environment, install `git` and clone the repository, then launch the Install Script:

```shell
pacman -Sy git
git clone https://github.com/TommasoCosimi/Auto_Arch
./Auto_Arch/Install.sh
```

After that, follow the on-screen instructions.


## Features

The script collection can:
* Choose a disk **(an entire disk)** to partition and install Arch Linux onto;
* Encrypt the OS Partition using LUKS and configure GRUB and `mkinitcpio` accordingly;
* Use BTRFS subvolumes to manage the OS Partition efficiently;
* Configure automatic Snapshots with `snapper`;
* Enable the possibility to boot from Snapshots directly from GRUB;
* Configure locales, users, and enable hardware support for the desired platform;
* Apply various tweaks and configurations which are common in my installs;
* Install Applications and Development Tools needed for my usage.