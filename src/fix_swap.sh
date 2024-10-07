#!/bin/bash
#
# Purpose: Set the swapspace size so we can actually compile!
#
# Example:
#  ./fix_swap.sh

echo "Checking swap"
if grep -q "^CONF_SWAPSIZE=100$" "/etc/dphys-swapfile"; then
    echo Need to expand swap
    echo -e ":g/^CONF_SWAPSIZE=/s/100/1024/\n:wq\n" | sudo ex /etc/dphys-swapfile
    sudo /etc/init.d/dphys-swapfile restart
else
    echo Swap OK
fi

