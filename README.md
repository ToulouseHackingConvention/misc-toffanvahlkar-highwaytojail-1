# misc-toffanvahlkar-allnightlong-1
## Network Capture of a Live Migration

Only a draft, Makefile not functional.

First get the vm folder from the chall forensic-toffanvahlkar... (will be submoduled).

Use in that order:

 * `./netdump.sh`
 * `./live_migration_in.sh`
 * `./live_migration.sh`

It should make a capture of the live migration between the two VM and store it in test.pcap.
