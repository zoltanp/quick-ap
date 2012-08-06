#!/bin/sh

set -x

IFACE=wlan0

function usage {
	echo "usage: $1 (start|stop)"
}

function verify_dependencies {
	hostapd -v
	dnsmasq -v
}

function start {
	# hostap config file name
	CONFIGFILE="/tmp/quick-ap-hostapd.conf.$$"

	# note: password of AP readable to anybody on the system

	# write
	echo "interface=$IFACE" > "$CONFIGFILE"
	echo "driver=nl80211" >>  "$CONFIGFILE"
	echo "ssid=yourssid" >> "$CONFIGFILE"
	echo "hw_mode=g" >> "$CONFIGFILE"
	echo "channel=1" >> "$CONFIGFILE"
	echo "wpa=1" >> "$CONFIGFILE"
	echo "wpa_passphrase=1234567890" >> "$CONFIGFILE"
	echo "wpa_key_mgmt=WPA-PSK" >> "$CONFIGFILE"
	echo "wpa_pairwise=TKIP" >> "$CONFIGFILE"
	echo "rsn_pairwise=CCMP" >> "$CONFIGFILE"

	# start AP
	hostapd -dd -t $CONFIGFILE >& "/tmp/quick-ap-hostapd-log" &
	PID_HOSTAPD=$!
	echo "pid of hostapd: $PID_HOSTAPD"

	# save hostapd PID
	echo $PID_HOSTAPD > "/tmp/quick-ap-hostapd-pid"

	# set IP for wlan0
	ifconfig "$IFACE" 10.171.223.1 netmask 255.255.255.0

	# start DHCP + DNS server

	dnsmasq --pid-file="/tmp/quick-ap-dnsmasq-pid" \
		--dhcp-range=10.171.223.2,10.171.223.254,60m \
		--except-interface=lo \
		--interface="$IFACE" \
		--dhcp-option=option:router,10.171.223.1

	# needs "&" option for getting PID
	#PID_DNSMASQ=$!
	#echo "pid of dnsmasq: $PID_DNSMASQ"

		#  --bind-interfaces -- is it needed?

	# set up NAT
	echo 1 > /proc/sys/net/ipv4/ip_forward

	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

	#
	echo "startup done"
	echo "$(ps aux | grep hostapd)"
	echo "$(ps aux | grep dnsmasq)"

}

function stop {
	if [ -e "/tmp/quick-ap-hostapd-pid" ] ; then
		echo "stopping hostapd..."
		HOSTAPD_PID=$( cat "/tmp/quick-ap-hostapd-pid")
		PIDLIST=$( pidof hostapd | grep "$HOSTAPD_PID" )
		if [ "$PIDLIST" != "" ] ; then
			kill "$HOSTAPD_PID" ;
			rm "/tmp/quick-ap-hostapd-pid"
		fi
		echo "hostapd stopped"
	fi

	if [ -e "/tmp/quick-ap-dnsmasq-pid" ] ; then
		echo "stopping dnsmasq"
		DNSMASQ_PID=$( cat "/tmp/quick-ap-dnsmasq-pid")
		PIDLIST=$( pidof dnsmasq | grep "$DNSMASQ_PID" )
		if [ "$PIDLIST" != "" ] ; then
			kill "$DNSMASQ_PID" ;
			rm "/tmp/quick-ap-dnsmasq-pid"
		echo "dnsmasq stopped"
		fi
	fi

	# status
	sleep 0.2
	echo "$(ps aux | grep hostapd)"
	echo "$(ps aux | grep dnsmasq)"
}

# start main, process arguments

if [ $# -ne 1 ] ; then
	usage $0
	exit 1 ;
fi

case "$1" in
	"start")
		echo "start"
		verify_dependencies
		start
		;;
	"stop")
		echo "stop"
		# verify_dependencies
		stop
		;;
	*)
		usage $0
		exit 2
esac

# end of script
