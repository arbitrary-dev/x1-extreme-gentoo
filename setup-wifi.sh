#!/bin/bash

[[ $_ == $0 ]] && echo -e "This script should be sourced:\nsource $0" && exit 1

export WI
export SSID
export IP

if [ ! $WI ]; then
  WI=`iw dev | sed -n 's/.*interface //ip'`
fi
echo "Wireless interface WI=$WI"

_check_ssid() { grep -q "ssid=\"$1\"" wpa.conf; }

if [ ! $SSID ]; then
  ssids_found=(`iw dev $WI scan | grep SSID | sed 's/.*ssid: //i'`)
  idx=0
  if (( ${#ssids_found} > 1 )); then
    if [ -f wpa.conf ]; then
      for s in ${ssids_found[@]}; do
        if _check_ssid $s; then
          SSID=$s
          break
        fi
      done
    fi
    if [ ! $SSID ]; then
      ssids_found=(${ssids_found[@]:0:10})
      echo -e "\nSeveral SSID's found:"
      for i in ${!ssids_found[@]}; do
        echo "$i - ${ssids_found[$i]}"
      done
      read -n1 -p "Which to use? " idx
      echo -e "\n"
      SSID=${ssids_found[$idx]}
    fi
  elif (( ${#ssids_found} == 1 )); then
    SSID=${ssids_found[0]}
  else
    echo "No SSID's available"
    return 1
  fi
fi
echo "Local Wi-Fi SSID=$SSID"

# See: https://bbs.archlinux.org/viewtopic.php?pid=1749577#p1749577
echo -e "\nDisable all network related services..."
systemctl list-unit-files --state=enabled \
| grep -iE "net|dhcp|wpa|conn|wicd" \
| cut -d\  -f1 \
| xargs -rL1 systemctl disable
killall wpa_supplicant
echo -e "Done!\n"

if [ ! -f wpa.conf ] || ! _check_ssid $SSID; then
  printf "Enter passphrase for $SSID: "
  if ! wpa_passphrase $SSID > .wpa.conf; then
    tail -1 .wpa.conf
    rm .wpa.conf
    return 1
  fi
  [ ! -f wpa.conf ] \
    && echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel" \
    > wpa.conf
  cat .wpa.conf >> wpa.conf
  rm .wpa.conf
fi
wpa_supplicant -B -i $WI -c wpa.conf | sed '/\bP2P\b/Id' || return 1

echo -e "\nAcquiring IP address..."
dhclient -v $WI || return 1
echo

ping -c4 gentoo.org || return 1

echo -e "\nSync clock..."
timedatectl set-ntp true
date

IP=`ifconfig | grep -EA1 "^$WI:" | sed -En 's/.*inet ([^ ]+).*/\1/p'`
echo -e "\nYour IP=$IP\n"

# vim:et sw=2 ts=2 sts=2
