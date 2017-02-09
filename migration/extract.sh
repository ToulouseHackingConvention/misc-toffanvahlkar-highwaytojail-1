#!/bin/bash
tshark -T fields -e data -r export/capture.pcap | xxd -r -p | pv -s "$(du export/migration.img | awk '{ print $1 }')k" > /tmp/migration_tshark.img
