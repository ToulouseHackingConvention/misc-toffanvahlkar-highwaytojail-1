# IF_WLAN=wlo1
# IF_ETH=enp3s0
# export IFPHYS="${IF_ETH}"
# export IFVIRT=tap0

# Guest IP is set in the virtual machine, so don't change the network configuration.
IFVIRT=tap0
HOSTIP=10.0.2.1
GUESTIP=10.0.2.2

QEMU_MONITOR=5200
QEMU_SERIAL=5201

all: export


###   Files and dependencies.   ################################################

tmp/allnightlong-work.qcow2: prepare-disk

tmp/qemu.pid: start-vm

tmp/migration.qemu: migrate

2-stegano/export/export.tgz: export-stegano

3-forensic/export/cryptolock: export-forensic


###   Rules   ##################################################################

export: capture

prepare-disk: res/allnightlong.qcow2 2-stegano/export/export.tgz 3-forensic/export/cryptolock
	mkdir -p tmp
	bin/prepare-disk

start-vm: tmp/allnightlong-work.qcow2
	bin/start-vm

export-stegano: 2-stegano/Makefile
	make -C 2-stegano export

export-forensic: 3-forensic/Makefile
	make -C 3-forensic export

run-cryptolock: tmp/qemu.pid
	bin/run-cryptolock

clear-vm:
	echo "TODO: Delete history..."

migrate: tmp/qemu.pid run-cryptolock
	bin/migrate

capture: tmp/migration.qemu
	mkdir -p export
	bin/capture

stop-vm:
	bin/stop-vm

check:
	echo "TODO: Extract migration from capture."

clean:
	make -C 2-stegano/ clean
	make -C 3-forensic/ clean
	rm tmp/ -rf

clean-all: clean
	make -C 2-stegano/ clean-all
	make -C 3-forensic/ clean-all
	rm export/ -rf

# .PHONY: export prepare-vm start-vm populate-vm prepare-steg prepare-forensic insert-steg clear-vm insert-forensic migrate capture check clean clean-all
