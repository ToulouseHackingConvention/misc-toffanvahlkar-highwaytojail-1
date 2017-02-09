#!/bin/bash
IF_WLAN=wlo1
IF_ETH=enp3s0
export IFPHYS="$IF_ETH"
export IFVIRT=tap0

# Guest IP is set in the virtual machine, so don't change the network configuration.
export HOSTIP=10.0.2.1
export GUESTIP=10.0.2.2

QEMU_MONITOR=5240
QEMU_SERIAL=5241

echo "Launch the virtual machine."
sudo -bE qemu-system-x86_64 -enable-kvm \
    -snapshot \
    -nographic \
    -machine "pc-i440fx-2.8" \
    -cpu "qemu64" \
    -m size=128M \
    -hda incoming.qcow2 \
    -monitor "tcp:127.0.0.1:${QEMU_MONITOR},server,nowait" \
    -serial "tcp:127.0.0.1:${QEMU_SERIAL},server,nowait" \
    -net "nic,model=virtio" \
    -net "tap,ifname=${IFVIRT},script=no,downscript=no" \
    -incoming tcp:0:4444

sleep 2
exit
echo "Waiting for connection on port 5555..."
nc -l -p 5555 | pv -L "5m" | tee export/migration.img | nc localhost 4444

read -p "Press [Enter] key to shut down the virtual machine..."

echo "Shut down the virtual machine."
echo $(echo "quit" | nc 127.0.0.1 "${QEMU_MONITOR}")

sleep 2
