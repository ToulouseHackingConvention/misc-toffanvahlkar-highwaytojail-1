#!/usr/bin/python3
import sys

if len(sys.argv) != 2:
    print("Usage: {0} size (in MB)".format(sys.argv[0]))
    exit(1)

size=int(sys.argv[1])

f = open('/tmp/data.txt', 'w')

for i in range(int(size*(10**5)*20/21)):
    # One line equals 10B.
    f.write("0x{0:08x}\n".format(i))

f.close()
