#!/bin/bash
#
# dup-live-disk.sh - duplicate live system partitions on new disk.
#
# (C) Bruno Raoult ("br"), 2007-2021
# Licensed under the Mozilla Public License (MPL) version 2.0.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the Mozilla Public License along with this
# program.  If not, see <https://www.mozilla.org/en-US/MPL>
#
# SPDX-License-Identifier: MPL-2.0 <https://spdx.org/licenses/MPL-2.0.html>
#
# This script will not work for all situations, I strongly suggest you
# don't use it if you don't *fully* understand it.

# dest device (used for grub)
DSTDISK=/dev/sdb

# partitions suffixes, for source and destination partitions.
# For example, if we want to copy XX partition, source partition will be
# /mnt/XX${SRCNUM}, and destination will be /mnt/XX${DSTNUM}
SRCNUM=2
DSTNUM=1

# array of partitions to copy
TO_COPY=(root export EFI)

# An alternative to SRCNUM, DSTNUM, and TO_COPY variables would be to have
# an array containing src and destination partitions:
#   (partsrc1 partdst1 partsrc2 partdst2 etc...)
# example:
# TO_COPY=(root2 root1 export2 export1)
# declare -i i
# for ((i=0; i<${#TO_COPY[@]}; i+=2)); do
#     SRC=${#TO_COPY[$i]}
#     DST=${#TO_COPY[$i + 1]}
# etc...

# where we will configure/install grub: mount point, device
GRUB_ROOT=/mnt/root${DSTNUM}
GRUB_DEV=/dev/$(lsblk -no pkname /dev/disk/by-label/root${DSTNUM})

# we will use ".rsync-disk-copy" files to exclude files/dirs
RSYNCOPTS="-axH --delete --delete-excluded"
FILTER=--filter="dir-merge .rsync-disk-copy"

# stop what could be problematic (databases, etc...)
systemctl stop mysql

# partitions copy
for part in ${TO_COPY[@]}; do
    SRCPART=/mnt/${part}${SRCNUM}/
    DSTPART=/mnt/${part}${DSTNUM}

    echo copy from $SRCPART to $DSTPART
    echo -n "press a key to continue..."
    read -r key
    echo rsync ${RSYNCOPTS} "$FILTER" "$SRCPART" "$DSTPART"
    rsync ${RSYNCOPTS} "$FILTER" "$SRCPART" "$DSTPART"
done

# grub install
# mount virtual devices
mount -o bind  /sys    ${GRUB_ROOT}/sys
mount -o bind  /proc   ${GRUB_ROOT}/proc
mount -o bind  /dev    ${GRUB_ROOT}/dev

chroot ${GRUB_ROOT} update-grub
chroot ${GRUB_ROOT} grub-install ${GRUB_DEV}

# restart stopped process (db, etc...)
systemctl start mysql
