#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
from web3 import Web3, HTTPProvider
from web3.middleware import geth_poa_middleware
from web3.contract import Contract

class contractWrapper(object):
    """This class is a wrapper for the smart contract, providing easy update of the state und calls/transactions. It is initialized with the contracts address, the host of the HTTP provider and the unlocked account number"""
    def __init__(self, address, host, account):
        self.contractAddress = address
        self.web3 = Web3(HTTPProvider(host))
        self.account = int(account)
        self.web3.middleware_onion.inject(geth_poa_middleware, layer=0) #necessary sice upgrade to v5
        abiFile = open('../smartcontracts/CommunityController_abi.json')
        abi = json.load(abiFile)
        abiFile.close()
        self.contract_inst = self.web3.eth.contract(address = self.contractAddress, abi=abi, ContractFactoryClass=Contract)
        self.tx_hash_post = '0x'
        self.tx_hash_contr = '0x'
        self.gasConsumption_post = 0
        self.gasConsumption_contr = 0
        self.updateState()
    def updateState(self):    
        """updates the state of the contractWrapper instance by calling the state variables from the smart contract"""
        self.blockNumber = self.web3.eth.blockNumber
        self.noUsers=self.contract_inst.functions.numberOfAdresses().call({'from': self.web3.eth.accounts[self.account]})
        self.Contracted = self.contract_inst.functions.isContracted().call({'from': self.web3.eth.accounts[self.account]})
        self.Registered = self.contract_inst.functions.registered(self.web3.eth.accounts[self.account]).call({'from': self.web3.eth.accounts[self.account]})
        self.Contractor = self.contract_inst.functions.contractor().call({'from': self.web3.eth.accounts[self.account]})
        if self.Registered == True or self.Contractor == self.web3.eth.accounts[self.account]:
            self.PricePerBlock = self.contract_inst.functions.readPricePerBlock().call({'from': self.web3.eth.accounts[self.account]})
            self.SetPoint = self.contract_inst.functions.readSetPoint().call({'from': self.web3.eth.accounts[self.account]})
            self.PresTot = self.contract_inst.functions.readPresTot().call({'from': self.web3.eth.accounts[self.account]})
            self.Balance = self.contract_inst.functions.readBalance().call({'from': self.web3.eth.accounts[self.account]})
            self.BalanceOfContractor = self.contract_inst.functions.readBalanceOfContractor().call({'from': self.web3.eth.accounts[self.account]})
        else:
            self.PricePerBlock = 0
            self.SetPoint = 0
            self.PresTot = 0
            self.Balance = 0
            self.BalanceOfContractor = 0
        if self.Registered == True:
            self.RegistrationIndex = self.contract_inst.functions.RegistrationIndex(self.web3.eth.accounts[self.account]).call({'from': self.web3.eth.accounts[self.account]})
            self.SOC = self.contract_inst.functions.readSOC(self.web3.eth.accounts[self.account]).call({'from': self.web3.eth.accounts[self.account]})
        else:
            self.RegistrationIndex = 0
            self.SOC = 0
        if self.tx_hash_post != '0x':
            try:
                temp = self.web3.eth.getTransactionReceipt(self.tx_hash_post)
                self.gasConsumption_post = temp['gasUsed']
                self.tx_hash_post = '0x'
            except Exception as e:
                raise ValueError(str(e)+' old tx was not yet included in block...') 
        elif self.gasConsumption_post != 0:
            self.gasConsumption_post = 0
        if self.tx_hash_contr != '0x':
            temp = self.web3.eth.getTransactionReceipt(self.tx_hash_contr)
            self.gasConsumption_contr = temp['gasUsed']
            self.tx_hash_contr = '0x'
        elif self.gasConsumption_contr != 0:
            self.gasConsumption_contr = 0
    def getSetValue(self):
        """call to readInstruction function from the specified account of the wrappers instance"""
        return self.contract_inst.functions.readInstruction().call({'from': self.web3.eth.accounts[self.account]})
    def postStatus(self, Pres, SOC, oldI, oldO):
        """posts the current state"""
        self.tx_hash_post = self.contract_inst.functions.setState(SOC,Pres,oldI,oldO).transact({'from': self.web3.eth.accounts[self.account]})
    def checkForNewBlock(self):
        """checks if a new block is available and updated the state of the contractWrapper instance if yes"""
        if self.web3.eth.blockNumber<=self.blockNumber:
            return False
        else:
            self.updateState()
            return True
    def register(self,PoptCh,PoptDch,Pmax,SOC,Pres,value):
        """registers a participant in the community"""
        self.contract_inst.functions.register(PoptCh,PoptDch,Pmax,SOC,Pres).transact({'from': self.web3.eth.accounts[self.account], 'value': value})
    def deregister(self):
        """deregisters a participant in the community"""
        self.contract_inst.functions.deregister().transact({'from': self.web3.eth.accounts[self.account]})
    def contractNewSetPoint(self,newSetValue,MaxPrice,Value):
        """used to contract a new setpoint. Specified Value is transacted to contract"""
        self.tx_hash_contr = self.contract_inst.functions.contractNewSetPoint(newSetValue,MaxPrice).transact({'from': self.web3.eth.accounts[self.account], 'value': Value})
    def cancelContract(self):
        """used to cancel an active flex. provision"""
        self.contract_inst.functions.cancelContract().transact({'from': self.web3.eth.accounts[self.account]})
    def hardCancelContract(self):
        """for testing purposes"""
        self.contract_inst.functions.hardCancelContract().transact({'from': self.web3.eth.accounts[self.account]})
    def callFlexibilityAvailable(self,setValue,SOCborder):
        """calls to the contract to check if there is enough flex. available"""
        return self.contract_inst.functions.flexibilityAvailable(setValue,SOCborder).call({'from': self.web3.eth.accounts[self.account]})
    def callContracted(self):
        """direct call to contract to see is flex. provision is active, as the contracted variable is only updated via updateState()"""
        return self.contract_inst.functions.isContracted().call({'from': self.web3.eth.accounts[self.account]})
    def getReward(self):
        """withdrawal of reward"""
        self.contract_inst.functions.getReward().transact({'from': self.web3.eth.accounts[self.account]})
    def __del__(self):
        pass