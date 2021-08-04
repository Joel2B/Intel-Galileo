#!/bin/sh

KERNEL=$1

if [ -z $KERNEL ]; then
    echo "No kernel supplied"
	echo "to build the kernel run the script build-kernel.sh"
    exit 0
fi

IFS='_'
read -r kernel_name p2 p3 << EOF
$KERNEL
EOF

id_kernel=$( echo $kernel_name | sed -e "s/linux-image-//g")
linux_headers=$( echo ${kernel_name}_${p2}_${p3} | sed -e "s/image/headers/g")

VERSION=jessie
echo "========================================="
echo "Version: $VERSION"
echo "========================================="
echo "Creating loopback.img"
echo "========================================="
dd of=loopback.img bs=1 count=0 seek=1G
echo "========================================="
echo "Mounting loopback.img -> loop0"
echo "========================================="
#sudo kpartx -v -a loopback.img
echo "Creating partitions"

sudo losetup /dev/loop0 loopback.img
sudo parted /dev/loop0 mktable msdos
sudo parted /dev/loop0 mkpart primary fat32 1 100MB
#sudo parted /dev/loop0 mkpart primary linux-swap 101MB 613MB
#sudo parted /dev/loop0 mkpart primary ext3 614MB 3000MB
sudo parted /dev/loop0 mkpart primary ext3 101MB 1000MB

#sudo parted /dev/loop0 set 1 boot onlos	
#sudo parted /dev/loop0 set 3 msftdata on

sudo partx -a /dev/loop0
sudo mkfs.vfat -I /dev/loop0p1
#sudo mkfs.ext3 /dev/loop0p3
sudo mkfs.ext3 /dev/loop0p2

if [ ! -d sd_root ]; then
	echo "Creating sd_root dir"
	mkdir sd_root
fi

if [ ! -d sd_boot ]; then
	echo "Creating sd_boot dir"
	mkdir sd_boot
fi

#sudo mount /dev/loop0p3 sd_root
sudo mount /dev/loop0p2 sd_root

echo "========================================="
if [ -d $VERSION ]; then
	echo "Copying temporary dir $VERSION -> sd_root"
	cp -a $VERSION/. ./sd_root
else
	echo "Downloading $VERSION system"
	sudo debootstrap --arch i386 $VERSION $VERSION http://http.debian.net/debian
	echo "Copying temporary dir $VERSION -> sd_root"
	cp -a ./$VERSION/. ./sd_root
fi
echo "========================================="

echo "Mounting downloaded system"
sudo mount --bind /dev sd_root/dev/
#sudo mount --bind /dev/pts sd_root/dev/shm
sudo mount --bind /dev/pts sd_root/dev/pts
sudo mount --bind /proc sd_root/proc
#sudo mount -t sysfs /sys sd_root/sys

echo "Copying libgmp"
sudo cp lib/libgmp.so.10.4.0 sd_root/opt

echo "Copying $KERNEL"
sudo cp $KERNEL sd_root/opt

echo "Copying $linux_headers"
sudo cp $linux_headers sd_root/opt

echo "Updating sources.list"
sudo echo "
deb http://deb.debian.org/debian jessie main contrib non-free
deb-src http://deb.debian.org/debian jessie main contrib non-free

deb http://deb.debian.org/debian-security/ jessie/updates main contrib non-free
deb-src http://deb.debian.org/debian-security/ jessie/updates main contrib non-free

deb http://deb.debian.org/debian jessie-updates main contrib non-free
deb-src http://deb.debian.org/debian jessie-updates main contrib non-free
" > sd_root/etc/apt/sources.list

chroot sd_root/ apt-get update

chroot sd_root/ apt-get upgrade -y

echo "========================================="
echo "Installing applications"
echo "========================================="
chroot sd_root/ apt-get install -y sudo locales ntp openssh-server initramfs-tools net-tools bash-completion connman parted gdb
#make build-essential libssl-dev zlib1g-dev libbz2-dev \
#libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
#xz-utils tk-dev libffi-dev liblzma-dev git autoconf libtool zip cmake python3-dev python3 python3-pip python3-setuptools python-openssl 

echo "========================================="

echo "Configuring system language"
chroot sd_root/ locale-gen en_US.UTF-8
chroot sd_root/ localedef -i en_US -f UTF-8 en_US.UTF-8
chroot sd_root/ su -c "echo 'LC_ALL=en_US.UTF-8' >> /etc/default/locale"
chroot sd_root/ su -c "echo 'LANG=en_US.UTF-8' >> /etc/default/locale"

echo "Configuring ssh"
chroot sd_root/ sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

echo "Configuring modules"
chroot sd_root/ su -c "echo 'pch_udc' >> /etc/modules"
chroot sd_root/ su -c "echo 'g_serial' >> /etc/modules"

echo "Configuring serial console"
chroot sd_root/ su -c "echo 'GS0:23:respawn:/sbin/getty -L 115200 ttyGS0 vt100' >> /etc/inittab"
chroot sd_root/ su -c "echo 'T1:23:respawn:/sbin/getty -L 115200 ttyS1 vt100' >> /etc/inittab"

#echo "Configuring swap"
#chroot sd_root/ su -c "echo '/dev/mmcblk0p2 none swap sw 0 0' >> /etc/fstab"
#chroot sd_root/ su -c "mkswap /dev/mmcblk0p2"
#chroot sd_root/ su -c "swapon -a"

echo "========================================="

echo "add password for the root"
chroot sd_root/ passwd

echo "Adding a new user"
chroot sd_root/ adduser user
echo "Adding the new user to group sudo"
chroot sd_root/ addgroup user sudo

echo "Configuring visudo"
chroot sd_root/ su -c "echo '#!/bin/sh' > /tmp/tmp.sh"
chroot sd_root/ su -c "echo \"sed -i 's/%sudo\tALL=(ALL:ALL) ALL/%sudo ALL=(ALL) NOPASSWD:ALL/g' /etc/sudoers\" >> /tmp/tmp.sh"
chroot sd_root/ su -c "chmod +x /tmp/tmp.sh"
chroot sd_root/ su -c "EDITOR=/tmp/tmp.sh visudo"

echo "Configuring hostname, hosts, interfaces"
chroot sd_root/ su -c "echo 'Galileo' > /etc/hostname"
chroot sd_root/ sed -i 's/.1\tlocalhost/.1\tlocalhost Galileo/g' /etc/hosts
chroot sd_root/ sed -i 's/loopback/loopback Galileo/g' /etc/hosts
chroot sd_root/ su -c "echo 'auto eth0' >> /etc/network/interfaces"
chroot sd_root/ su -c "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces"

echo "========================================="

echo "Installing $KERNEL"
chroot sd_root/ su -c "dpkg -i /opt/$KERNEL"

echo "========================================="

echo "Installing $linux_headers"
chroot sd_root/ su -c "dpkg -i /opt/$linux_headers"

echo "========================================="

echo "Linking libgmp"
chroot sd_root/ su -c "unlink /usr/lib/i386-linux-gnu/libgmp.so.10"
chroot sd_root/ su -c "rm /usr/lib/i386-linux-gnu/libgmp.so.10.2.0"
chroot sd_root/ su -c "cp /opt/libgmp.so.10.4.0 /usr/lib/i386-linux-gnu"
chroot sd_root/ su -c "ln -s /usr/lib/i386-linux-gnu/libgmp.so.10.4.0 /usr/lib/i386-linux-gnu/libgmp.so.10"

echo "Patching libpthread"
chroot sd_root/ su -c '
for i in `/usr/bin/find /lib -type f -name \*pthread\*so`
do
	cp ${i} ${i}.bak
	sed -i "s/\xf0\x0f\xb1\x8b/\x90\x0f\xb1\x8b/g" ${i}
done
'

echo "Mounting boot"
sudo mount /dev/loop0p1 sd_boot
echo "Creating dir sd_boot/boot/grub"
sudo mkdir -p sd_boot/boot/grub
echo "Configuring boot"
echo "kernel: vmlinuz-$id_kernel"
echo "initrd: initrd.img-$id_kernel"

sudo echo "
default 1
timeout 10

color white/blue white/cyan

title Clanton SVP kernel-SPI initrd-SPI IMR-On IO-APIC/HPET NoEMU
    kernel --spi root=/dev/ram0 console=ttyS1,115200n8 earlycon=uart8250,mmio32,\$EARLY_CON_ADDR_REPLACE,115200n8 vmalloc=384M reboot=efi,warm apic=debug rw
    initrd --spi

title Custom Quark Kernel with Debian $VERSION
    root (hd0,1)
    kernel /boot/vmlinuz-$id_kernel root=/dev/mmcblk0p2 2 console=ttyS1,115200n8 earlycon=uart8250,mmio32,\$EARLY_CON_ADDR_REPLACE,115200n8 vmalloc=3844M reboot=efi,warm apic=debug rw LABEL=boot debugshell=5
    initrd /boot/initrd.img-$id_kernel
	
" > sd_boot/boot/grub/grub.conf

echo "Umounting system"
sudo killall ntpd
sudo umount -l sd_root/dev/pts sd_root/dev sd_root/proc sd_root sd_boot
losetup -a
sudo losetup -d /dev/loop0
losetup -a
sudo kpartx -d loopback.img
sudo kpartx -d /dev/loop0

DATE=$(date +"%m%d%Y")
TIME=$(date +"%H%M%S")
# if [ ! -d sd_card ]; then
	# mkdir sd_card
# fi
#mv loopback.img galileo-$VERSION-$DATE-$TIME.img
cp loopback.img /media/sf_PUBLICO/galileo-$VERSION-$DATE-$TIME.img
rm loopback.img


