#!/bin/bash
#tshark -T fields -e data -r export/capture.pcap | xxd -r -p | pv > /tmp/migration_tshark.img
tcpflow -a -r export/migration.pcap -o /tmp/flow/
