#!/bin/sh
# Copyright (C) 2017 XiaoShan https://www.mivm.cn
[ -z "$(pidof dnsmasq)" ] && /etc/init.d/dnsmasq reload


add_rule() {
	online_list_ip=$1
	temp_file=$temp_dir/device_speed/$online_list_ip
	[ -s  "$temp_file" ] || {
		[ -z "$(iptables --list | grep -w K3_SEREEN_U)" ] && iptables -N K3_SEREEN_U
		[ -z "$(iptables --list | grep -w K3_SEREEN_D)" ] && iptables -N K3_SEREEN_D
		[ -z "$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_U | grep -w $online_list_ip)" ] && iptables -I FORWARD 1 -s $online_list_ip -j K3_SEREEN_U
		[ -z "$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_D | grep -w $online_list_ip)" ] && iptables -I FORWARD 1 -d $online_list_ip -j K3_SEREEN_D
		echo -e "0\n0" > $temp_file
	}
}

get_speed() {
	online_list_ip=$1
	temp_file=$temp_dir/device_speed/$online_list_ip
    curr_speed_u_ipt=$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_U)
    curr_speed_d_ipt=$(iptables -nvx -L FORWARD | grep -w K3_SEREEN_D)

    last_speed_u=$(cat "$temp_file" | head -1)
    last_speed_d=$(cat "$temp_file" | tail -1)

    curr_speed_u=$(echo -e "$curr_speed_u_ipt" | grep -w "$online_list_ip" | awk '{print $2}')
    curr_speed_d=$(echo -e "$curr_speed_d_ipt" | grep -w "$online_list_ip" | awk '{print $2}')
    up=$((($curr_speed_u - $last_speed_u) / $time_s))
    dp=$((($curr_speed_d - $last_speed_d) / $time_s))

}

i=0
data=""
temp_dir=/tmp/k3screenctrl
dhcp_leases=$(uci get dhcp.@dnsmasq[0].leasefile)

oui_data=$(cat /etc/oui/oui.txt)
last_time=$(cat $temp_dir/device_speed/time 2>/dev/null || date +%s)
curr_time=$(date +%s)
time_s=$(($curr_time - $last_time))
[ $? -ne 0 -o $time_s -eq 0 ] && time_s=$(uci -q get k3screenctrl.@general[0].refresh_time || echo 2)

cat $dhcp_leases | while read client
do
	online_list_ip=$(echo "$client" | awk '{print $3}')
	online_list_mac=$(echo "$client" | awk '{print $2}')
	online_list_host=$(echo "$client" | awk '{print $4}')
	
	add_rule $online_list_ip

	online_code_data=$(cat "$temp_dir/device_online")
	device_custom_data=$(cat "$temp_dir/device_custom")

	online_code=$(echo -e "$online_code_data" | grep -w "$online_list_ip" | awk '{print $2}') && [ -z "$online_code" ] && online_code=0
	[ "$online_code" -ne 0 ] && continue
	
	hostmac=$(echo "$online_list_mac" | sed 's/://g')
	device_custom=$(echo -e "$device_custom_data" |grep -w -i "$online_list_mac")

	if [ -n "$device_custom" ]; then
		name=$(echo "$device_custom" | awk '{print $2}')
		if [ -n "$(echo "$device_custom" | awk '{print $3}')" ]; then
			logo=$(echo "$device_custom" | awk '{print $3}')
		else
			logo=$(echo -e "$oui_data" | grep -w -i ${hostmac:0:6} | awk '{print $1}')
		fi
	else
		name=$online_list_host
		logo=$(echo -e "$oui_data" | grep -w -i ${hostmac:0:6} | awk '{print $1}')
	fi

	[ "$name" = "?" -o -z "$name" ] && name=$online_list_host
	[ "$name" = "*" -o -z "$name" ] && name="Unknown"
	
	get_speed $online_list_ip

	temp_data="$name\n$dp\n$up\n${logo:=0}\n"
	data=${data}${temp_data}
	let i+=1
	echo -e "$curr_speed_u\n$curr_speed_d" > $temp_file

	echo $i
	echo -e "$data"
done
echo $curr_time > $temp_dir/device_speed/time