#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from web3 import Web3, IPCProvider

class minterWrapper(object):
    def __init__(self, path):
        """wrapper for convenient control of miner with status 0=idle, 1=mining"""
        self.web3 = Web3(IPCProvider(path))
        self.status = 1 
        self.blockNumber=self.web3.eth.blockNumber
    def start(self):
        self.status=1
        return self.web3.miner.start(1)
    def stop(self):
        self.status=0
        return self.web3.miner.stop()
    def getStatus(self):
        return self.status
    def checkForNewBlock(self):
        if self.web3.eth.blockNumber<=self.blockNumber:
            return False
        else:
            self.blockNumber=self.web3.eth.blockNumber
            return True
    def getBlock(self):
        return self.blockNumber
    def __del__(self):
        pass
