#!/usr/bin/env bash
set -e

hash pacstrap &>/dev/null || {
	echo "Could not find pacstrap. Run pacman -S arch-install-scripts"
	exit 1
}

[[ -z "$1" ]] && {
    echo "Usage: $0 REPOSITORY[:TAG]"
    exit 1
}

export LANG="C.UTF-8"

ROOTFS=$(mktemp -d ${TMPDIR:-/var/tmp}/rootfs-archlinux-XXXXXXXXXX)
trap "rm -rf $ROOTFS" EXIT
chmod 755 $ROOTFS

# we want to avoid using the host's pacman.conf or mirrorlist, so we pass a
# saved version of the default pacman configuration
# if you --ignore a package being installed from a group, the default is
# to install it despite the ignore, so we have to manually specify the list of
# desired packages
pacstrap -C ./pacman.conf.default -c -d -G -M $ROOTFS $(comm -23 <(pacman -Sgq base base-devel | sort) <(sort ./ignore) | uniq) haveged

arch-chroot $ROOTFS /bin/sh -c 'rm -r /usr/share/man/*'
arch-chroot $ROOTFS /bin/sh -c 'haveged -w 1024; pacman-key --init; pkill haveged; pacman -Rs --noconfirm haveged; pacman-key --populate archlinux; pkill gpg-agent'
arch-chroot $ROOTFS /bin/sh -c 'ln -s /usr/share/zoneinfo/UTC /etc/localtime'
echo 'en_US.UTF-8 UTF-8' > $ROOTFS/etc/locale.gen
arch-chroot $ROOTFS locale-gen
# -C controls the configuration used by pacstrap, but we still have to add
# configuration for the actual pacman inside the container
arch-chroot $ROOTFS /bin/sh -c "echo Server = 'https://mirrors.kernel.org/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist"

# udev doesn't work in containers, rebuild /dev
DEV=$ROOTFS/dev
rm -rf $DEV
mkdir -p $DEV
mknod -m 666 $DEV/null c 1 3
mknod -m 666 $DEV/zero c 1 5
mknod -m 666 $DEV/random c 1 8
mknod -m 666 $DEV/urandom c 1 9
mkdir -m 755 $DEV/pts
mkdir -m 1777 $DEV/shm
mknod -m 666 $DEV/tty c 5 0
mknod -m 600 $DEV/console c 5 1
mknod -m 666 $DEV/tty0 c 4 0
mknod -m 666 $DEV/full c 1 7
mknod -m 600 $DEV/initctl p
mknod -m 666 $DEV/ptmx c 5 2
ln -sf /proc/self/fd $DEV/fd

tar --numeric-owner --xattrs --acls -C $ROOTFS -c . | docker import - "$1"
docker run -t --rm "$1" echo "$1"
