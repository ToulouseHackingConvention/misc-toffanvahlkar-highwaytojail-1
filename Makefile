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

2-stegano/Makefile:
	git submodule update --init --remote

3-forensic/Makefile:
	git submodule update --init --remote

tmp/allnightlong-work.qcow2: prepare-vm

tmp/vm.pid: start-vm

tmp/migration.img: migrate

2-stegano/export/export.tgz: prepare-steg

3-forensic/export/cryptolock: prepare-forensic


###   Rules   ##################################################################

export: prepare-vm start-vm populate-vm prepare-steg prepare-forensic insert-steg clear-vm insert-forensic migrate capture

prepare-vm: res/allnightlong.qcow2
	mkdir -p tmp
	qemu-img create -f qcow2 -b ../res/allnightlong.qcow2 tmp/allnightlong-work.qcow2

start-vm: tmp/allnightlong-work.qcow2
	sudo -b qemu-system-x86_64 -enable-kvm \
		-nographic \
		-machine "pc-i440fx-2.8" \
		-cpu "qemu64" \
		-m size=128M \
		-hda tmp/allnightlong-work.qcow2 \
		-monitor "tcp:127.0.0.1:${QEMU_MONITOR},server,nowait" \
		-serial "tcp:127.0.0.1:${QEMU_SERIAL},server,nowait" \
		-net "nic,model=virtio" \
		-net "tap,ifname=${IFVIRT},script=res/qemu-ifup.sh,downscript=res/qemu-ifdown.sh"
	pidof -s qemu-system-x86_64 > tmp/vm.pid
	sleep 5

populate-vm: res/rdash-home.tgz tmp/vm.pid
	tar xvf res/rdash-home.tgz --directory=./tmp
	scp -F res/ssh_config -r tmp/rdash "rdash@${GUESTIP}:/home/"

prepare-steg: 2-stegano/Makefile
	make -C 2-stegano export

prepare-forensic: 3-forensic/Makefile
	make -C 3-forensic export

insert-steg: 2-stegano/export/export.tgz tmp/vm.pid
	scp -F res/ssh_config 2-stegano/export/export.tgz "rdash@${GUESTIP}:/home/rdash/"
	ssh -F res/ssh_config "rdash@${GUESTIP}" tar xvf export.tgz
	ssh -F res/ssh_config "rdash@${GUESTIP}" mv wallpaper.png Pictures/Wallpapers/
	ssh -F res/ssh_config "rdash@${GUESTIP}" mv flag.gpg .flag.gpg
	ssh -F res/ssh_config "root@${GUESTIP}" mv /home/rdash/hide /usr/local/bin/
	ssh -F res/ssh_config "rdash@${GUESTIP}" shred -u export.tgz

insert-forensic: 3-forensic/export/cryptolock tmp/vm.pid
	scp -F res/ssh_config 3-forensic/export/cryptolock "gru@${GUESTIP}:/tmp/"
	ssh -F res/ssh_config "gru@${GUESTIP}" chmod +x /tmp/cryptolock
	# Run in background.
	ssh -nf -F res/ssh_config "gru@${GUESTIP}" /tmp/cryptolock -e
	# Get back the key from the malware.
	nc -l -p 54321 > tmp/key

clear-vm:
	echo "TODO: Delete history..."

migrate: tmp/vm.pid
	nc -l -p 5555 | dd of=tmp/migration.img & \
	nc 127.0.0.1 "${QEMU_MONITOR}" <<< "migrate -b tcp:localhost:5555"; \
	wait;

capture: tmp/migration.img
	mkdir -p export
	# 100 MiB buffer.
	sudo -b tcpdump -B 102400 -n -i lo -w export/capture.pcap -Z "$(whoami)" "port 4444"
	pidof -s tcpdump > tmp/tcpdump.pid
	nc -l -p 4444 | dd of=/dev/null & \
	pv -L "5m" tmp/migration.img | nc localhost 4444; \
	wait;
	sudo kill "$$(cat tmp/tcpdump.pid)"

stop-vm:
	nc 127.0.0.1 "${QEMU_MONITOR}" <<< "system_powerdown"
	sleep 5
	-nc 127.0.0.1 "${QEMU_MONITOR}" <<< "quit"

check:
	echo "TODO: Extract migration from capture."

clean:
	rm -rf tmp
	make -C 2-stegano/ clean
	make -C 3-forensic/ clean

clean-all: clean
	make -C 2-stegano/ clean-all
	make -C 3-forensic/ clean-all

.PHONY: all export prepare-vm start-vm populate-vm prepare-steg prepare-forensic insert-steg clear-vm insert-forensic migrate capture check clean clean-all
