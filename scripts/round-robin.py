#!/usr/bin/python3
# -*- coding: utf-8 -*-

import sys
import time, datetime
import logging
logging.basicConfig(level=logging.INFO)
Logging = logging.getLogger(__name__)

# params to adjust
n=4 #number of your nodes
path = '<insertpathtoipcfile>'
if len(sys.argv)>=4:
    path = sys.argv[3]

from minterWrapper import minterWrapper #communication with minter via web3 over IPC API
m=minterWrapper(path)

index = int(sys.argv[1])
if len(sys.argv)>=3:
    n = int(sys.argv[2])
counter = 14
timeStep = 0.25
blockTime = 15
waitingTime = 0
t1 = time.time() #start time for sleep duration

while True:
    try:
        #new block?
        if m.checkForNewBlock():
            Logging.info("New block found")
            counter = 0
            waitingTime = 14
            m.stop()
        #no new block
        else:
            counter+=waitingTime
            if counter == 14:
                waitingTime = timeStep
                if int(m.getBlock())%n==index:
                    Logging.info('starting my minter')
                    m.start()
                else: 
                    Logging.info('not my turn...')
    except KeyboardInterrupt:
        Logging.info("terminated smart minting")
        break
    except Exception as e:
        Logging.info(e)
    
    t2 = time.time()
    time.sleep(max(waitingTime - t2 + t1,0))
    t1 = time.time()

Logging.debug('Exited loop')