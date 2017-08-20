!/bin/bash
# PIA Port-forwarding by Rhoel Crax
#
# Put identifying details in a separate config file with 
# two lines: (1) user id, (2) password
#
CONFIG=.pia_config
#
# Make sure running as root/sudo
if [[ $EUID -ne 0 ]]; then
echo "sudo or root please"
exit 1
fi
# Read config
mapfile -n 2 -t CONF < $CONFIG
USER=${CONF[0]}
PASS=${CONF[1]}
ID=`head -n 100 /dev/urandom | sha256sum | tr -d " -"`
# Get local PPTP IP
IP=`ip addr show ppp0 | grep inet | awk '{print $2}'`
#IP=`ip addr show tun0 | grep inet | awk '{print $2}'` uncomment if using openvpn
if [[ $IP == "" ]]; then
echo "PPTP not up, exiting."
exit 1
fi
echo "PPTP local ip = $IP"
# Make API call to get port
JSON=`wget -q --post-data="user=$USER&pass=$PASS&client_id=$ID&local_ip=$IP" \
-O - 'https://www.privateinternetaccess.com/vpninfo/port_forward_assignment' \
| head -1`
PORT=`echo $JSON | awk 'BEGIN { FS="[:}]" } {print $2}'`
# Open port on firewall
P=`firewall-cmd --query-port=$PORT/tcp`
if [[ $P == "no" ]]; then
echo "Opening port $PORT"
firewall-cmd --add-port=$PORT/tcp
else
echo "Port $PORT already open"
fi
# Listen sshd on port; will report open on internet port forward tools
echo "Listening for netcat connections on port $PORT"
/bin/nc -lvp $PORT
