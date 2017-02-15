#!/bin/bash
IF_WLAN=wlo1
IF_ETH=enp3s0
export IFPHYS="$IF_ETH"
export IFVIRT=tap0

# Guest IP is set in the virtual machine, so don't change the network configuration.
export HOSTIP=10.0.2.1
export GUESTIP=10.0.2.2

QEMU_MONITOR=5200
QEMU_SERIAL=5201

mkdir -p export

echo "Create incoming hard drive."
qemu-img create -f qcow2 export/incoming.qcow2 2G

echo "Launch the virtual machine."
sudo -b qemu-system-x86_64 \
    -enable-kvm \
    -machine "pc-i440fx-2.8" \
    -m size=256M \
    -hda export/incoming.qcow2 \
    -monitor "tcp:127.0.0.1:${QEMU_MONITOR},server,nowait" \
    -serial "tcp:127.0.0.1:${QEMU_SERIAL},server,nowait" \
    -net "nic,model=virtio" \
    -net "tap,ifname=${IFVIRT},script=no,downscript=no" \
    -incoming tcp:0:4444
    # -nographic \
    # -net "tap,ifname=${IFVIRT},script=qemu-ifup.sh,downscript=qemu-ifdown.sh" \
    # -m size=128M \
    # -cpu "qemu64" \
    # -m size=2G \
    # -cdrom "$HOME/Documents/ISO/OS/Linux/archlinux/archlinux-2017.01.01-dual.iso" \
    # -boot once=d \

sleep 2

echo "Waiting for connection on port 4444..."
pv res/migration.qemu | nc localhost 4444
echo "Migration done! You should be able to use the VM."

echo "Backup the ram into a file (for forensic analysis): export/guest_dump"
nc 127.0.0.1 "${QEMU_MONITOR}" <<< "pmemsave 0 0x8000000 export/guest_dump"
sleep 2
sudo chown "$USER:$(id -g)" "export/guest_dump"

echo "Save the state of the vm (snapshot): export/snapshot"
nc -l -p 5555 | pv > export/snapshot.qemu &
nc 127.0.0.1 "${QEMU_MONITOR}" <<< "migrate tcp:127.0.0.1:5555"
wait

echo "Done! You may want to edit the disk (in order to add you SSH key to authorized_keys, etc.) and reload the VM with the snapshot."
echo "You can also extract some relevant files from the disk export/incoming.qcow2"

read -p "Press [Enter] key to shut down the virtual machine..."

echo "Shut down the virtual machine."
nc 127.0.0.1 "${QEMU_MONITOR}" <<< "quit"

sleep 2
