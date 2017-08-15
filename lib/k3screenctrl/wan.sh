#!/bin/sh

# Basic vars
TEMP_FILE="/tmp/k3screenctrl/wan_speed"
WAN_STAT="/tmp/k3screenctrl/ifstatus_wan"
WAN6_STAT="/tmp/k3screenctrl/ifstatus_wan6"
LAN_STAT="/tmp/k3screenctrl/ifstatus_lan"
DEV_STAT="/tmp/k3screenctrl/dev_stat"

if [ "$(cat /etc/k3screenctrl-apmode)" -eq 0 ]; then

	##Auto update LanIP when conflicts with wanIP.
	wan_proto=`uci -q get network.wan.proto`
	[ -n "$wan_proto" ] && [ "$wan_proto" = "dhcp" ] && {
		devname=$(uci get network.wan.ifname 2>/dev/null)
		wanip=$(ifconfig $devname 2>/dev/null | grep "inet addr:" | grep -E -o "[0-9]+\.[0-9]+\.[0-9]+\."|head -1)1
		lanip=$(uci get network.lan.ipaddr 2>/dev/null)
		[ -n "$lanip" -a -n "$wanip" ] && {
			if [ "$lanip" = "$wanip" ]; then
					uci set network.lan.ipaddr=192.168.4.1
					uci commit network
					/etc/init.d/network restart
			fi
		}
	}

	[ -f "$WAN_STAT" ] && rm -f $WAN_STAT
	for wanname in `uci show network |grep -w "proto=" |awk -F'.' '{print $2}' |grep -v 'lan\|loopback'`
	do
		[ `uci -q get network.$wanname.proto` == "none" ] && continue
		ifstatus $wanname >> $WAN_STAT
	done
	ifstatus wan6 > $WAN6_STAT

	# Internet connectivity
	IPV4_ADDR=`cat "$WAN_STAT" | grep -w '"address":' | awk -F'"' '{print $4}'`
	IPV6_ADDR=`cat "$WAN6_STAT" | grep -w '"address":' | awk -F'"' '{print $4}'`
	
	if [ -n "$IPV4_ADDR" -o -n "$IPV6_ADDR" ]; then
		CONNECTED=1
	else
		CONNECTED=0
	fi
	
	WAN_IFNAME=`cat "$WAN_STAT" | grep -w '"l3_device":' | awk -F'"' '{print $4}'` # pppoe-wan
	if [ -z "$WAN_IFNAME" ]; then
		WAN_IFNAME=`cat "$WAN_STAT" | grep -w '"device":' | awk -F'"' '{print $4}'` # eth0.2
		if [ -z "$WAN_IFNAME" ]; then
			WAN_IFNAME=`uci get network.wan.ifname` # eth0.2
		fi
	fi
else
	ifstatus lan > $LAN_STAT
	IPV4_ADDR=`cat "$LAN_STAT" | grep -w '"address":' | awk -F'"' '{print $4}'`
	if [ -n "$IPV4_ADDR" ]; then
		CONNECTED=1
	else
		CONNECTED=0
	fi

	WAN_IFNAME="br-lan" #AP Mode
fi
# If there is still no WAN iface found, the script will fail - but that's rare

# Calculate speed by traffic delta / time delta
# NOTE: /proc/net/dev updates every ~1s.
# You must call this script with longer interval!
CURR_DOWNLOAD_BYTES=0
CURR_UPLOAD_BYTES=0

CURR_TIME=$(date +%s)
[ "$CONNECTED" -eq 1 ] && {
	cat /proc/net/dev > $DEV_STAT
	for w_ifname in $WAN_IFNAME
	do
		CURR_STAT=$(cat "$DEV_STAT" | grep -w "${w_ifname}:" | sed -e 's/^ *//' -e 's/  */ /g')
		c_download_bytes=$(echo $CURR_STAT | cut -d " " -f 2)
		c_upload_bytes=$(echo $CURR_STAT | cut -d " " -f 10)
		CURR_DOWNLOAD_BYTES=$(($CURR_DOWNLOAD_BYTES + $c_download_bytes))
		CURR_UPLOAD_BYTES=$(($CURR_UPLOAD_BYTES + $c_upload_bytes))
	done
}

if [ -e "$TEMP_FILE" ]; then
    LINENO=0
    while read line; do
        case "$LINENO" in
            0)
                LAST_TIME=$line
                ;;
            1)
                LAST_UPLOAD_BYTES=$line
                ;;
            2)
                LAST_DOWNLOAD_BYTES=$line
                ;;
            *)
                ;;
        esac
        LINENO=$(($LINENO+1))
    done < $TEMP_FILE
fi

echo $CURR_TIME > $TEMP_FILE
echo $CURR_UPLOAD_BYTES >> $TEMP_FILE
echo $CURR_DOWNLOAD_BYTES >> $TEMP_FILE

if [ -z "$LAST_TIME" -o -z "$LAST_UPLOAD_BYTES" -o -z "$LAST_DOWNLOAD_BYTES" ]; then
    # First time of launch
    UPLOAD_BPS=0
    DOWNLOAD_BPS=0
else
    TIME_DELTA_S=$(($CURR_TIME-$LAST_TIME))
    if [ $TIME_DELTA_S -eq 0 ]; then
        TIME_DELTA_S=1
    fi
    UPLOAD_BPS=$((($CURR_UPLOAD_BYTES-$LAST_UPLOAD_BYTES)/$TIME_DELTA_S))
    DOWNLOAD_BPS=$((($CURR_DOWNLOAD_BYTES-$LAST_DOWNLOAD_BYTES)/$TIME_DELTA_S))
fi

echo $CONNECTED
echo $UPLOAD_BPS
echo $DOWNLOAD_BPS