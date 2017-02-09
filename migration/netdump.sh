#!/bin/bash
# 100 MiB buffer.
sudo tcpdump -B 102400 -n -i lo -w export/capture.pcap -Z "$(whoami)" "port 4444"
