all: export

incoming.qcow2:
	qemu-img create -f qcow2 incoming.qcow2 2G

export: incoming.qcow2 netdump.sh live_migration.sh live_migration_in.sh
	rm -f vm
	ln -s ../vm
	rm -f export
	ln -s ../export
	# TODO: Update scripts in order to run everything sequentially from
	# the makefile.
	# ./netdump.sh
	# sudo ./live_migration_in.sh
	# sudo ./live_migration.sh

clean:
	rm export/*

clean-all:
	rm -f vm
	rm -f export
	rm -f incoming.qcow2

.PHONY: all export clean clean-all
