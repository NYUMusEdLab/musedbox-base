#!/bin/bash

# Functions
get_cpuinfo_prop () {
  target_line=$(grep -m1 ^"$1" /proc/cpuinfo)
  echo "${target_line##*: }"
}

# Constants
pi=0
nic=''
ap=''
station=''
pi2types = (a01041 a21041)
pi3types = (a02082 a22082)

# Diferentiate Pi 2 and Pi 3
for type in "${pi2types[@]}"; do
    if [[ $type = "$(get_cpuinfo_prop 'Revision')" ]];
        pi=2
        echo "Raspberry Pi 2 Model B detected"
        break
    fi
done
for type in "${pi3types[@]}"; do
    if [[ $type = "$(get_cpuinfo_prop 'Revision')" ]];
        pi=3
        echo "Raspberry Pi 3 Model B detected"
        break
    fi
done

# NIC
if [[ $pi = 2 ]]; then
  nic=wlan0
  ap=wlan0_ap
  station=wlan0_sta
fi
if [[ $pi = 3 ]]; then
  nic=wlan0
  ap=wlan0_ap
  station=wlan0
fi

# The subnet IP mask.
mask=/24

# The subnet IP range.
subnet_ip=10.10.0.0$mask

# The IP of the subnet NIC on the subnet.
server_ip=10.10.0.1$mask

# The dhcpd configuration, lease and PID files to use.
dhcpd_conf=$APPDIR/config/dhcpd/dhcpd.conf
dhcpd_lease=/tmp/dhcpd.lease
dhcpd_pid=/tmp/dhcpd.pid

# Hostapd config and pid files
hostapd_conf=$APPDIR/config/hostapd/hostapd.conf
hostapd_pid=/tmp/hostapd.pid

# Bind config
named_conf=$APPDIR/config/bind/named.conf
named_pid=/tmp/named.pid

# Stop all applications with stop scripts in stop.d
for SCRIPT in $APPDIR/scripts/stop.d/*
  do
    if [ -f $SCRIPT -a -x $SCRIPT ]
    then
      $SCRIPT
    fi
done

# Kill the DHCP server.
if [[ -f $dhcpd_pid ]]
then
  kill $(cat "$dhcpd_pid") && rm "$dhcpd_pid" && echo "killed dhcp server"
fi

# Kill hostapd
if [[ -f $hostapd_pid ]]
then
  kill $(cat "$hostapd_pid") && rm "$hostapd_pid" && echo "killed hostapd"
fi

# Kill bind
if [[ -f $named_pid ]]
then
  kill $(cat "$named_pid") && rm "$named_pid" && echo "killed named"
fi

#iptables -D OUTPUT -i "$nic" -p icmp --icmp-type echo-reply -j ACCEPT
iptables -D INPUT -i "$nic" -p icmp --icmp-type echo-request -j ACCEPT
iptables -D INPUT -i "$nic" -p udp --dport 67 -j ACCEPT
iptables -D INPUT -i "$nic" -s "$subnet_ip" -p udp --dport 53 -j ACCEPT
iptables -D INPUT -i "$nic" -s "$subnet_ip" -p tcp --dport 53 -j ACCEPT

# Flush ip addresses
ip addr flush dev "$ap"

# Shut down station interface
ip link set $station down

# Remove virtual interfaces
iw dev "$ap" del
if [[ $pi = 2 ]]; then
  iw dev "$station" del
fi

exit 0
