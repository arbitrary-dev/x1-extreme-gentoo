#!/bin/sh

WI=`iw dev | sed -n 's/.*interface//ip'`
echo "Wireless interface: $WI"
SSID=`iw dev $WI scan | grep SSID | head -1 | sed 's/.*ssid: //i'`
echo "Local SSID: $SSID"

echo -e "\nDisable all network related services..."
systemctl list-unit-files --state=enabled \
| grep enabled \
| cut -d\  -f1 \
| xargs -L1 systemctl disable

echo -e "\nConnecting to SSID=$SSID..."
wpa_passphrase $SSID > wpa.conf
wpa_supplicant -B -i $WI -c wpa.conf
dhclient $WI
ping -c4 google.com
