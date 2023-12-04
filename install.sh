#!/run/current-system/sw/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or run as root."
    exit 1
fi

# Partitioning the disk using parted
parted /dev/sda -- mklabel msdos
parted /dev/sda -- mkpart primary 1MB -8GB
parted /dev/sda -- set 1 boot on
yes | parted /dev/sda -- mkpart primary linux-swap -8GB 8GB
parted /dev/sda -- mkpart primary ext4 8GB 100%

# Check if partitioning was successful
if [[ $? -ne 0 ]]; then
    echo "Error: Partitioning /dev/sda failed."
    exit 1
fi

# Format the partitions
mkfs.ext4 -L nixos /dev/sda1
mkswap -L swap /dev/sda2
swapon /dev/sda2

# Check if formatting was successful
if [[ $? -ne 0 ]]; then
    echo "Error: Formatting partitions failed."
    exit 1
fi

# Mount the root partition
mount /dev/disk/by-label/nixos /mnt

# Generate NixOS configuration
nixos-generate-config --root /mnt
sed -i 's/# boot.loader.grub.device = "\/dev\/sda"; # or "nodev" for efi only/boot.loader.grub.device = "\/dev\/sda";/' /mnt/etc/nixos/configuration.nix

# Install NixOS
nixos-install

if [ $? -eq 0 ]; then
    echo "nixos-install was successful"
else
    echo "nixos-install failed"
    exit 1
fi

nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
curl https://raw.githubusercontent.com/MossTeK/nixPlex/main/configuration.nix > /mnt/etc/nixos/configuration.nix

#reboot nix instance
nixos-rebuild switch
git clone https://github.com/MossTeK/nixos-config.git

sudo reboot