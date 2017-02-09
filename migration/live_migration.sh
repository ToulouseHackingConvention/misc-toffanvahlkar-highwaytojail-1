#!/bin/bash
IF_WLAN=wlo1
IF_ETH=enp3s0
export IFPHYS="$IF_ETH"
export IFVIRT=tap0

# Guest IP is set in the virtual machine, so don't change the network configuration.
export HOSTIP=10.0.2.1
export GUESTIP=10.0.2.2

QEMU_MONITOR=5230
QEMU_SERIAL=5231

echo "Launch the virtual machine."
sudo -bE qemu-system-x86_64 -enable-kvm \
    -snapshot \
    -nographic \
    -machine "pc-i440fx-2.8" \
    -cpu "qemu64" \
    -m size=128M \
    -hda allnightlong.qcow2 \
    -monitor "tcp:127.0.0.1:${QEMU_MONITOR},server,nowait" \
    -serial "tcp:127.0.0.1:${QEMU_SERIAL},server,nowait" \
    -net "nic,model=virtio" \
    -net "tap,ifname=${IFVIRT},script=vm/qemu-ifup.sh,downscript=vm/qemu-ifdown.sh"

sleep 2

read -p "Press [Enter] key to start live migration."

echo $(echo "migrate -b tcp:localhost:5555" | nc "127.0.0.1 ${QEMU_MONITOR}")

read -p "Press [Enter] key to shut down the virtual machine..."

echo "Shut down the virtual machine."
echo $(echo "quit" | nc 127.0.0.1 "${QEMU_MONITOR}")

sleep 2
