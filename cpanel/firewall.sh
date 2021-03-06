#!/bin/sh
# IPTables Script
# Adjust those values right otherwise you will get locked out!
EXTERNAL=enp0s3
INTERNAL=enp0s8
EXTERNALNET=10.110.0.0/16
INTERNALIP=10.222.0.1
GATEWAYIP=10.110.0.1/16
SSHIP=10.110.0.10/32
PAYMENTGATEWAY=sis-t.redsys.es
# Adjust those values for DNS Forwarding
DNSFORWARDER1=208.67.222.123
DNSFORWARDER2=208.67.220.123

# Default Policy
iptables -X
iptables -Z
iptables -F
iptables -t nat -X
iptables -t nat -Z
iptables -t nat -F
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Allow Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT


# Server Rules
# Anti-Port-Flood for ACCEPTED RULES
iptables -A INPUT -p tcp -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset
iptables -A INPUT -p tcp -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset
# Enable NTP to specific address
iptables -A INPUT -i $EXTERNAL -p udp --dport 123 -j ACCEPT
iptables -A OUTPUT -o $EXTERNAL -p udp --sport 123 -j ACCEPT

# Enable Ping through all networks (only for testing purposes)
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT
# Enable SSH to specific address
iptables -A INPUT -s $SSHIP -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -d $SSHIP -p tcp --sport 22 -j ACCEPT

# Enable Server to query the specific DNS
iptables -A INPUT -p udp -i $EXTERNAL --sport 53 -s $DNSFORWARDER1 -j ACCEPT
iptables -A INPUT -p udp -i $EXTERNAL --sport 53 -s $DNSFORWARDER2 -j ACCEPT
iptables -A INPUT -p tcp -i $EXTERNAL --sport 53 -s $DNSFORWARDER1 -j ACCEPT
iptables -A INPUT -p tcp -i $EXTERNAL --sport 53 -s $DNSFORWARDER2 -j ACCEPT
iptables -A OUTPUT -p udp -o $EXTERNAL --dport 53 -d $DNSFORWARDER1 -j ACCEPT
iptables -A OUTPUT -p udp -o $EXTERNAL --dport 53 -d $DNSFORWARDER2 -j ACCEPT
iptables -A OUTPUT -p tcp -o $EXTERNAL --dport 53 -d $DNSFORWARDER1 -j ACCEPT
iptables -A OUTPUT -p tcp -o $EXTERNAL --dport 53 -d $DNSFORWARDER2 -j ACCEPT

# Enable DNS Serving to LAN
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 53 -j ACCEPT
# Enable DHCP Serving to Clients
iptables -A INPUT -p udp --dport 67 -j ACCEPT
iptables -A OUTPUT -p udp --sport 67 -j ACCEPT
iptables -A INPUT -p udp --dport 68 -j ACCEPT
iptables -A OUTPUT -p udp --sport 68 -j ACCEPT
# HTTPS Enable Clients to Server
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 443 -j ACCEPT
# HTTP Enable Clients to Server
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 80 -j ACCEPT
# HTTPS Enable Server to Clients
iptables -A INPUT -p tcp --sport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
# HTTP Enable Server to Clients
iptables -A INPUT -p tcp --sport 80 -j ACCEPT # Used for packages fetch
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

# Anti-DOS Policy for ACCEPTED RULES
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A FORWARD -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP


# CAPTIVE PORTAL SETTINGS
# Forward toggle on
echo 1 > /proc/sys/net/ipv4/ip_forward
# Redirect all clients to DNS Server
iptables -t nat -A PREROUTING -i $INTERNAL -p udp --dport 53 -j DNAT --to-destination $INTERNALIP:53
# In case of forwarded MAC, go to Internet (tunnel to Internet, no interaction with external net)
#iptables -t nat -A PREROUTING -i $INT -m mac --mac-source 08:00:27:f8:9d:80 -j ACCEPT

#payment gateway and CDN access
iptables -A FORWARD -p tcp -d $PAYMENTGATEWAY -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d $PAYMENTGATEWAY -j ACCEPT

iptables -A FORWARD -p tcp -d fonts.gstatic.com -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d fonts.gstatic.com -j ACCEPT


iptables -A FORWARD -p tcp -d code.getmdl.io -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d code.getmdl.io -j ACCEPT

iptables -A FORWARD -p tcp -d stackpath.bootstrapcdn.com -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d stackpath.bootstrapcdn.com -j ACCEPT

iptables -A FORWARD -p tcp -d code.jquery.com -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d code.jquery.com -j ACCEPT

iptables -A FORWARD -p tcp -d cdn.jsdelivr.net -j ACCEPT
iptables -t nat -A PREROUTING -p tcp -d cdn.jsdelivr.net -j ACCEPT



#iptables -A FORWARD -m mac --mac-source 08:00:27:f8:9d:80 ! -d $EXTERNALNET -i $INT -o $EXT -j ACCEPT
# In case of not forwarded MAC, go to Captive Portal
iptables -t nat -A PREROUTING -i $INTERNAL -p tcp --dport 1:65535 -j DNAT --to-destination $INTERNALIP
iptables -t nat -A PREROUTING -i $INTERNAL -p udp --dport 1:65535 -j DNAT --to-destination $INTERNALIP
# Bridge EXTERNAL NET to INTERNAL
iptables -A FORWARD -i $EXTERNAL -o $INTERNAL -j ACCEPT
iptables -t nat -A POSTROUTING -o $EXTERNAL -j MASQUERADE
