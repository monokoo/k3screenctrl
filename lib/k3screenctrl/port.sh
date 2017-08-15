#!/bin/sh

usb3_setting=`uci -q get k3screenctrl.@general[0].usb3_disable`
[ -z "$usb3_setting" ] && usb3_setting=0

print_eth_port_status() {
    local port=$1

    # One `swconfig dev switch0 show` wastes more time than 4 `port show`
    if [ -n "`swconfig dev switch0 port $port show | grep \"link:up\"`" ]; then
        echo 1
    else
        echo 0
    fi
}

print_usb_port_status() {
	if [ "$usb3_setting" -eq 0 ]; then
		if [ "`ls -1 /sys/bus/usb/devices | wc -l`" -gt 8 ]; then
			echo 1
		else
			echo 0
		fi
	else
		if [ "`ls -1 /sys/bus/usb/devices | wc -l`" -gt 5 ]; then
			echo 1
		else
			echo 0
		fi
	fi
}

print_eth_port_status 1 # Port 1 is LAN1 on label
print_eth_port_status 0 # Port 0 is LAN2 on label
print_eth_port_status 2 # LAN3
print_eth_port_status 3 # WAN
print_usb_port_status