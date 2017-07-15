#!/bin/sh
. /etc/openwrt_release

PRODUCT_NAME_FULL=$(cat /etc/board.json | jsonfilter -e "@.model.name")
PRODUCT_NAME=${PRODUCT_NAME_FULL#* } # Remove first word to save space
WAN_IFNAME=$(uci get network.wan.ifname)

MAC_ADDR=$(ifconfig $WAN_IFNAME | grep -oE "([0-9A-Z]{2}:){5}[0-9A-Z]{2}")
RUPTIME=$(awk '{print int($1/86400)"days "int($1%86400/3600)"h "int(($1%3600)/60)"m"}' /proc/uptime)
router_uptime=$(uci get k3screenctrl.@general[0].router_uptime)

CPU_TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))"'C"
disp=$(uci get k3screenctrl.@general[0].cputemp)

HW_VERSION=$(cat /etc/os-release | grep -w "PRETTY_NAME" | awk '{print $2}')
temp_arg=$(cat /etc/openwrt_release | grep -w "DISTRIB_CODENAME" | awk -F"'" '{print $2}')
FW_VERSION=$temp_arg" "${DISTRIB_RELEASE:0:9}

echo $PRODUCT_NAME
if [ "$disp" -eq 1 ]; then
	echo $CPU_TEMP
else
	echo $HW_VERSION
fi
echo $FW_VERSION
if [ "$router_uptime" -eq 1 ]; then
	echo $RUPTIME
else
	echo $MAC_ADDR
fi
