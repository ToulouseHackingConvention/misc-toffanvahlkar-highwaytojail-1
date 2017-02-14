#!/bin/bash

# Guest IP is set in the virtual machine, so don't change the network configuration.
HOSTIP=10.0.2.1
GUESTIP=10.0.2.2

readonly IFVIRT=tap0
readonly QEMU_MONITOR=5200
readonly QEMU_SERIAL=5201
readonly DISK="severus.qcow2"
readonly RAM=256M

sudo qemu-system-x86_64 -enable-kvm \
    -machine "pc-i440fx-2.8" \
    -cpu "qemu64" \
    -m "size=$RAM" \
    -hda "$DISK" \
    -monitor "tcp:127.0.0.1:${QEMU_MONITOR},server,nowait" \
    -serial "tcp:127.0.0.1:${QEMU_SERIAL},server,nowait" \
    -net "nic,model=virtio" \
    -net "tap,ifname=${IFVIRT},script=qemu-ifup.sh,downscript=qemu-ifdown.sh"
    # -cdrom "debian.iso" \
    # -boot once=d \
