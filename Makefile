all: export

###   Files and dependencies.   ################################################

tmp/severus-work.qcow2: prepare-disk

tmp/qemu.pid: start-vm

tmp/migration.qemu: migrate

2-stegano/export/: export-stegano

3-forensic/export/cryptolock: export-forensic


###   Rules   ##################################################################

export: capture

prepare-disk: res/severus.qcow2 2-stegano/export/
	mkdir -p tmp
	bin/prepare-disk

start-vm: tmp/severus-work.qcow2
	bin/start-vm

export-stegano: 2-stegano/Makefile
	make -C 2-stegano export

export-forensic: 3-forensic/Makefile
	make -C 3-forensic export

run-cryptolock: tmp/qemu.pid 3-forensic/export/cryptolock
	bin/run-cryptolock

migrate: tmp/qemu.pid run-cryptolock
	bin/migrate

capture: tmp/migration.qemu
	mkdir -p export
	bin/capture

stop-vm:
	bin/stop-vm

check: export/capture.pcap
	tcpflow -a -r $< -o /tmp/flow/

clean:
	rm -rf tmp/
	-make -C 2-stegano/ clean
	-make -C 3-forensic/ clean

clean-all: clean
	rm -rf export/
	-make -C 2-stegano/ clean-all
	-make -C 3-forensic/ clean-all

# .PHONY: export prepare-disk start-vm export-stegano export-forensic run-cryptolock migrate capture stop-vm check clean clean-all
