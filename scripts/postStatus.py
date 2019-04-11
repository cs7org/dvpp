#!/usr/bin/python3
import sys
from contractWrapper import contractWrapper #communication with contract via web3
if (len(sys.argv) >= 7):
    c=contractWrapper(sys.argv[1],sys.argv[2],sys.argv[3])
    c.postStatus(int(sys.argv[4]),int(sys.argv[5]),int(sys.argv[6]),int(sys.argv[7]))
else:
    raise ValueError("not enough args")