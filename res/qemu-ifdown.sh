#!/bin/bash
IFVIRT=tap0

echo "Unconfigure the virtual network interface."
# Remove host IP address.
ip a flush dev ${IFVIRT}
# Set down the virtual interface.
ip l s dev ${IFVIRT} down
