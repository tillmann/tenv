# https://outflux.net/blog/archives/2018/04/19/uefi-booting-and-raid1/

for k in 0 1; 
do
    parted --script /dev/nvme${k}n1 mklabel gpt \
        mkpart "EFI-${k}" fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart "root-${k}" ext4 513MiB 30GiB \
        mkpart "swap-${k}" linux-swap 30GiB 38GiB \
        mkpart "nvme-${k}" btrfs 38GiB 100%
done

for k in EFI root;
do 
    mdadm --create /dev/md/${k} \
          --level=1 \
          --metadata=1.0 \
          --raid-devices=2 \
          /dev/disk/by-partlabel/${k}-0 \
          /dev/disk/by-partlabel/${k}-1
done

mkfs.fat -F32 /dev/md/EFI

echo "grub-pc grub2/update_nvram boolean false" | chroot /target/ debconf-set-selections
echo "grub-pc grub-efi/install_devices multiselect /dev/md/EFI" | chroot /target/ debconf-set-selections && chroot /target dpkg-reconfigure -p low grub-efi-amd64-signed
chroot /target dpkg-reconfigure -p low grub-efi-amd64-signed
chroot /target grub-install  --force-extra-removable --force "dummy"
