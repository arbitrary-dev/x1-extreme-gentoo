#!/bin/sh

sync
umount -lv /mnt/gentoo/home
umount -lv /mnt/gentoo/dev{/shm,/pts,}
umount -Rv /mnt/gentoo
vgchange --available n
cryptsetup luksClose gentoo
