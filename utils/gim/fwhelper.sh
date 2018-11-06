#!/bin/bash
set -e
PORT=${1:?Please provide port number}
if command -v "firewall-cmd" >/dev/null 2>&1; then
    firewall-cmd --zone=public --add-port=${PORT}/tcp --permanent
    firewall-cmd --reload
else
    iptables -A INPUT -p tcp -m tcp --dport $PORT -j ACCEPT
    iptables -A OUTPUT -p tcp -m tcp --sport $PORT -j ACCEPT
    service iptables save
fi
