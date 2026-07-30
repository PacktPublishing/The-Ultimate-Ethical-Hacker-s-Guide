#!/bin/bash
domain=$1

echo "[*] WHOIS Lookup"
whois $domain> whois_$domain.txt

echo "[*] Resolving IP..."
ip=$(dig $domain +short | tail -n1)
echo "IP: $ip" | tee -a whois_$domain.txt

echo "[*] IP WHOIS"
whois $ip>> whois_$domain.txt

echo "Output saved to whois_$domain.txt"
