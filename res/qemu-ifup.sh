#!/bin/bash
IFVIRT=tap0
HOSTIP=10.0.2.1

echo "Set up the virtual network interface."
# Set up the virtual interface.
ip l s dev ${IFVIRT} up
# Configure host IP address.
ip a flush dev ${IFVIRT}
ip a a ${HOSTIP}/24 dev ${IFVIRT}
