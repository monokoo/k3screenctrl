#!/bin/sh
. /etc/openwrt_release

PRODUCT_NAME_FULL=$(cat /etc/board.json | jsonfilter -e "@.model.name")
PRODUCT_NAME=${PRODUCT_NAME_FULL#* } # Remove first word to save space
WAN_IFNAME=$(uci get network.wan.ifname)
MAC_ADDR=$(ifconfig $WAN_IFNAME | grep -oE "([0-9A-Z]{2}:){5}[0-9A-Z]{2}")
CPU_TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
disp=$(uci get k3screenctrl.@general[0].cputemp)
HW_VERSION=${DISTRIB_CODENAME:1:5}
FW_VERSION=v$HW_VERSION" "${DISTRIB_RELEASE:0:9}

echo $PRODUCT_NAME
if [ "$disp" -eq 1 ]; then
	echo $CPU_TEMP
else
	echo $HW_VERSION
fi
echo $FW_VERSION
echo $MAC_ADDR