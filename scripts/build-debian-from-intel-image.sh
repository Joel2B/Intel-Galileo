#!/bin/sh

IMAGE=$1

echo "Installing debootstrap"
apt-get install debootstrap
if [ ! -d mnt-loop ]; then
	echo "Creating mnt-loop dir"
	mkdir mnt-loop
fi
if [ ! -d image ]; then
	echo "Creating image dir"
	mkdir image
fi
#FILE=sd/image-full-galileo-clanton.ext3
FILELOOP=loopback.img
VERSION=jessie
#if test -f "$FILE"; then
#	echo "Deleting file image-full-galileo-clanton.ext3"
#	rm -r sd/image-full-galileo-clanton.ext3
#fi

if test -f "$FILE2"; then
	echo "Removing file $FILELOOP"
	rm -r $FILELOOP
fi
echo "Creating $FILELOOP"
	dd if=/dev/zero of=$FILELOOP bs=1G count=1
	mkfs.ext3 $FILELOOP

echo "Mounting $FILELOOP -> mnt-loop"
	mount -o loop $FILELaOOP ./mnt-loop

if [ -d $VERSION ]; then
	echo "Copying $VERSION"
	cp -a $VERSION/. ./mnt-loop
else
	echo "Debootstrap i386 $VERSION -> mnt-loop"
	debootstrap --arch i386 $VERSION ./mnt-loop
	mkdir $VERSION
	cp -a ./mnt-loop/. ./$VERSION
fi
echo "Mounting $IMAGE -> image"
	mount $IMAGE image
echo "Copying image files -> mnt-loop"
	cp -ru image/lib/ mnt-loop/
	cp -ru image/usr/lib/libstdc++.so* mnt-loop/usr/lib
	cp -ru image/lib/libc.so.0 mnt-loop/usr/lib
	cp -ru image/lib/libm.so.0 mnt-loop/usr/lib
	cp image/usr/bin/killall mnt-loop/usr/bin/
	cp image/etc/inittab mnt-loop/etc/inittab
	cp image/etc/modules-load.quark/galileo.conf mnt-loop/etc/modules
	mkdir mnt-loop/etc/modules-load.quark
	cp image/etc/modules-load.quark/galileo.conf mnt-loop/etc/modules-load.quark
	cp -r image/opt/ mnt-loop/
	cp image/etc/init.d/galileod.sh mnt-loop/etc/init.d/
	cp image/etc/init.d/quark-init.sh mnt-loop/etc/init.d/
echo "Mounting proc"
	mount -t proc proc mnt-loop/proc
echo "Mounting sysfs"
	mount -t sysfs sysfs mnt-loop/sys
echo "Adding hostname"	
	chroot mnt-loop/ su -c "echo 'Galileo' > /etc/hostname"
echo "Adding interfaces"	
	echo "auto eth0" >> mnt-loop/etc/network/interfaces
	echo "iface eth0 inet dhcp" >> mnt-loop/etc/network/interfaces
echo "Installing locales"
	chroot mnt-loop/ apt-get install locales
	chroot mnt-loop/ locale-gen en_US.UTF-8
	chroot mnt-loop/ localedef -i en_US -f UTF-8 en_US.UTF-8
echo "Installing ssh"
	chroot mnt-loop/ apt-get install ssh
	chroot mnt-loop/ passwd
	chroot mnt-loop/ sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
	chroot mnt-loop/ service ssh restart
echo "Creating /media/realroot"
	chroot mnt-loop/ mkdir /media/realroot
echo "Creating /sketch"
	chroot mnt-loop/ mkdir /sketch
echo "Patching galileod.sh"
chroot mnt-loop/ sed -i '/#!\/bin\/sh/a### BEGIN INIT INFO\r\
# Provides:          galileo\r\
# Required-Start:    $remote_fs $syslog\r\
# Required-Stop:     $remote_fs $syslog\r\
# Default-Start:     2 3 4 5\r\
# Default-Stop:      0 1 6\r\
# Short-Description: Example initscript\r\
# Description:       This file should be used to construct scripts to be\r\
#                    placed in /etc/init.d.  This example start a\r\
#                    single forking daemon capable of writing a pid\r\
#                    file.  To get other behavoirs, implemend\r\
#                    do_start(), do_stop() or other functions to\r\
#                    override the defaults in /lib/init/init-d-script.\r\
### END INIT INFO' /etc/init.d/galileod.sh
echo "Patching quark-init.sh"
chroot mnt-loop/ sed -i '/#!\/bin\/sh/a### BEGIN INIT INFO\r\
# Provides:          quark-init\r\
# Required-Start:    $remote_fs $syslog\r\
# Required-Stop:     $remote_fs $syslog\r\
# Default-Start:     2 3 4 5\r\
# Default-Stop:      0 1 6\r\
# Short-Description: Example initscript\r\
# Description:       This file should be used to construct scripts to be\r\
#                    placed in /etc/init.d.  This example start a\r\
#                    single forking daemon capable of writing a pid\r\
#                    file.  To get other behavoirs, implemend\r\
#                    do_start(), do_stop() or other functions to\r\
#                    override the defaults in /lib/init/init-d-script.\r\
### END INIT INFO' /etc/init.d/quark-init.sh

chroot mnt-loop/ sed -i 's/$board/Galileo/g' /etc/init.d/galileod.sh
chroot mnt-loop/ sed -i 's/$board/Galileo/g' /etc/init.d/quark-init.sh
echo "Registred galileod.sh"
chroot mnt-loop/ update-rc.d galileod.sh defaults
echo "Registred quark-init.sh"
chroot mnt-loop/ update-rc.d quark-init.sh defaults
echo "Umounting mnt-loop/proc"
umount mnt-loop/proc
echo "Umounting mnt-loop/sys"
umount mnt-loop/sys
echo "Umounting image"
umount image
echo "Umounting mnt-loop"
umount mnt-loop
echo "Copying $FILELOOP"
DATE=$(date +"%m%d%Y")
TIME=$(date +"%H%M%S")
if [ ! -d sd_card ]; then
	mkdir sd_card
fi
cp $FILELOOP sd_card/image-full-galileo-clanton-$VERSION-$DATE-$TIME.ext3
echo "Copying image-full-galileo-clanton.ext3"
cp sd_card/image-full-galileo-clanton* /media/sf_PUBLICO/





