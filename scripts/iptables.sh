#!/bin/sh

# ALLOW WORLD OF WARCRAFT SERVERS
# Authserver
iptables -A INPUT -p tcp --dport 3724 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 3724 -m state --state ESTABLISHED -j ACCEPT

#  World Server
iptables -A INPUT -p tcp --dport 8085 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 8085 -m state --state ESTABLISHED -j ACCEPT

# World Server - SOAP
iptables -A INPUT -p tcp --dport 7878 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 7878 -m state --state ESTABLISHED -j ACCEPT
