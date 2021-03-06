# How to setup Gentoo on Lenovo ThinkPad X1 Extreme

![Done](https://img.shields.io/badge/-Done-green)

*Think different, Think… Pad*

## Specs

- Windows 10 Pro (x64)
- Intel Core i7-8850H (6 cores, up to 4.3 GHz, 9 Mb cache)
- NVIDIA GeForce GTX 1050Ti (4 Gb, GDDR5)
- 32 Gb (16 + 16) DDR4 2666 MHz SoDIMM)
- 512 Gb SSD, M.2 2280, NVMe, Opal
- Intel 9560 2x2AC + Bluetooth
- 15.6 FHD (1920x1080), IPS, 300 nits, anti-glare
- HD 720p camera with microphone
- 4 cell Li-cyllinder (80 Wh)

## Cons

- [Coil whine](https://www.youtube.com/watch?v=lJQCRAKWe-k)
- FHD screen has [backlight bleeding](https://www.hackint0sh.org/wp-content/uploads/2019/02/what-is-Backlight-Bleed.jpg) on top corners
- Touchpad surface attracts small debris
- CPU's operating temperature:
  - 50°C in powersave
  - 60°C in performance
  - 80°C under load

## Kernel config

This one is for 4.19.97: [.config](gentoo/usr/src/linux/.config)

## Setup BIOS

1. Grant your user local admin rights
1. Setup [Lenovo System Update](https://support.lenovo.com/lv/en/downloads/ds012808)
1. Update BIOS:  
   `Win` → "System Update" → Get new updates → ThinkPad BIOS Update
1. (optional) Config → Keyboard/Mouse → F1-F12 as Primary Function → "Enabled"
1. `F10` Save and Exit

## rEFInd

1. TODO

## Create bootable USB stick

1. Download [Rufus](https://rufus.ie)
1. Boot selection → Disc or ISO image → SELECT → [SystemRescueCd](
   http://www.system-rescue-cd.org/Download)
   ('cause [Minimal Installation CD](https://www.gentoo.org/downloads)
   never worked for me)
1. Partition scheme → MBR
1. Target system → B♂IS or UEFI
1. START
1. Copy this repo & [Stage 3](https://www.gentoo.org/downloads) to the USB stick

## Shrink Windows 10

1. Backup your data
1. `Win` → "restore point" → Windows (C:) → Configure → Disable system
   protection
1. `Win` → "adjust appear" → Advanced → Change… → C: → No paging file → Set
1. Disable hibernation:  
   `Win + R` → "cmd" → `Ctrl + Shift + Enter` → "powercfg /H off"
1. Reboot
1. `Win` → "defrag" → Windows (C:) → Optimize
1. Reboot
1. `Win` → "partit" → Windows (C:) → Shrink Volume…

## RTC for Windows 10

1. `Win` → "date & time" → Set appropriate values for your locale, and close
1. Instruct Windows to use UTC:
   1. `Win` → "regedit" → `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation`
   1. Add new QWORD (64-bit) Value: `RealTimeIsUniversal=1`
   1. File → Exit
1. Disable the Windows Time Service:  
   `Win + R` → "cmd" → `Ctrl + Shift + Enter` → "sc config w32time start= disabled"
1. Force Windows to update the time:  
   `Win` → "date & time" → Set time automatically → Off → On → Close window

## Boot with USB stick

1. Restart and enter BIOS:  
   `Enter` → `F1`
1. Enable booting from custom images:  
   Security → Secure Boot → "Disabled"
1. `F10` Save and Exit
1. In rEFInd menu choose to boot from USB

```
# Verify we're in UEFI mode
ls /sys/firmware/efi/efivars

# Set password for root user
passwd
```

## Setup Wi-Fi

```
USB=/run/archiso/bootmnt
source $USB/setup-wifi.sh
```

## Connect from other PC (optional)

```
ssh root@<IP_from_previous_step>

# Resume or create new session
# `C-a ?` for commands list
# `C-a d` to detach
# `C-a [` to enter copy mode (hjkl - move, Enter/Space - copy, Esc - abort)
# `C-a ]` to paste
# `C-a H` to start/stop logging into screenlog.0
screen -R
```

## Prepare the drive

### Partition

```
parted -a optimal /dev/nvme0n1

(parted) unit s
(parted) print free
Number  Start       End          Size        File system  Name
...
        STARTs      ENDs         SIZEs       Free Space
...

(parted) mkpart primary STARTs ENDs
(parted) print
Number  Start       End          Size        File system  Name
...
NUM     STARTs      ENDs         SIZEs
...
(parted) quit

# Remember newly created partition
PART=nvme0n1p<NUM>

# Verify that it's the right one
lsblk | grep $PART
```

### Encryption

```
# Create LUKS key-file
export GPG_TTY=`tty`
dd if=/dev/urandom bs=8388607 count=1 \
| gpg --symmetric --cipher-algo AES256 --output luks-key.gpg

# LUKS format partition
gpg --decrypt luks-key.gpg \
| cryptsetup --cipher serpent-xts-plain64 --key-size 512 --hash whirlpool \
--key-file - luksFormat /dev/$PART

# Backup LUKS header
cryptsetup luksHeaderBackup /dev/$PART --header-backup-file luks-header.img

# (optional) Add a fallback passphrase
mkfifo /tmp/gpgpipe
echo RELOADAGENT | gpg-connect-agent
gpg --decrypt luks-key.gpg | cat - >/tmp/gpgpipe
cryptsetup --key-file /tmp/gpgpipe luksAddKey /dev/$PART
# Verify that keyslot 1 was added
cryptsetup luksDump /dev/$PART
rm -vf /tmp/gpgpipe

# Open LUKS partition with fallback passphrase
cryptsetup luksOpen /dev/$PART gentoo
# Verify 'gentoo' device is there
ls /dev/mapper
```

### LVM

```
# Create LVM logical volumes
pvcreate /dev/mapper/gentoo
vgcreate vg1 /dev/mapper/gentoo
lvcreate --size 32G --name root vg1
lvcreate --extents 95%FREE --name home vg1
# Verify
(pvdisplay; vgdisplay; lvdisplay) | less
# Apply
vgchange --available y
ls /dev/mapper
# Format
mkfs.ext4 -L root /dev/mapper/vg1-root
mkfs.ext4 -m0 -L home /dev/mapper/vg1-home
# Mount
mkdir /mnt/gentoo
mount /dev/mapper/vg1-root /mnt/gentoo
mkdir /mnt/gentoo/home
mount /dev/mapper/vg1-home /mnt/gentoo/home
```

## Stage 3

### Prepare

```
USB=/run/archiso/bootmnt
cd /mnt/gentoo
tar xvJpf $USB/stage3-amd64-*.tar.xz --xattrs-include='*.*' --numeric-owner
cp --dereference /etc/resolv.conf /mnt/gentoo/etc
cp -r $USB/gentoo/* /mnt/gentoo/

mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Copy Wi-Fi settings
mkdir /mnt/gentoo/etc/wpa_supplicant \
&& cp wpa.conf /mnt/gentoo/etc/wpa_supplicant/wpa_supplicant.conf
```

### Chroot

```
$USB/chroot.sh
source /etc/profile
```

### Proceed

```
# Not available in SystemRescueCd
# mirrorselect -i -o >> /etc/portage/make.conf

emerge-webrsync

# Set timezone
ls /usr/share/zoneinfo
echo 'Europe/Isle_of_Man' > /etc/timezone
emerge --config sys-libs/timezone-data

# Set locale
nano -w /etc/locale.gen
locale-gen
eselect locale set "en_US.utf8"

source /etc/profile

# Setup Portage
cp /etc/skel/.bash_profile /root
# Verify CPU_FLAGS_X86 in make.conf
emerge -1 app-portage/cpuid2cpuflags
cpuid2cpuflags

# Verify
emerge -pvuDN @world
# Update
emerge -quDN @world

# /tmp with tmpfs on 3g
mount /tmp

mkdir /boot/efi
buildkernel

cp /usr/share/dhcpcd/hooks/10-wpa_supplicant /lib/dhcpcd/dhcpcd-hooks/
rc-update add dhcpcd default

passwd
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
rc-update add sshd default

# Leave chroot
exit
# Leave screen
exit

$USB/uchroot.sh
reboot
```
