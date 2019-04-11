#!/usr/bin/python3
import time
import log
import sys
import logging
import datetime
from random import randint
from contractWrapper import contractWrapper #communication with contract via web3 over HTTP RPC API

folderstr = '<insertyourpath>'
contr_adr = '<insertyourcontractaddress>'
c=contractWrapper(contr_adr,'<insertyourhost>',1)
logger = log.log(logging.getLogger("logger"), datetime.datetime.now().strftime(folderstr + "log_contractDVPP_scheduled-%Y%m%d-%H%M%S.csv"))

def printlog(text):
    print(text)
    logger.newEntry([text])

def cancelOldContract():
    try: 
        c.updateState()
        if c.isContracted == 0:
            printlog('there is no contract to cancel')
        else:
            printlog("cancelling contract")
            i = 0
            while i<10:
                printlog('try number ' + str(i))
                i += 1 
                try:
                    c.cancelContract()
                    time.sleep(75)
                    c.updateState()
                    if c.Contracted == True:
                        c.hardCancelContract()
                        time.sleep(30)
                    printlog("contract cancelled")
                    break
                except Exception as e:
                    printlog(e)
                    try: 
                        c.hardCancelContract()
                        time.sleep(30)
                        printlog("contract hard cancelled")#
                        break
                    except Exception as e:
                        printlog(e)
    except Exception as e:
        printlog(e)
        printlog('probably no connection to blockchain')

def newContract(setValue,maxprice,money,timeinterval):
    printlog("starting new contract with setValue = " + str(setValue) + ', maxprice = ' + str(maxprice) + ', timeinterval = ' + str(timeinterval))
    try:
        if (c.callFlexibilityAvailable(setValue, 10000)):
            try:
                c.contractNewSetPoint(setValue,maxprice,money)
                printlog("successfully contracted")
            except ValueError as e:
                printlog(e)
                printlog("unsuccessful --> try to cancel old contract")
                while True:
                    try:
                        cancelOldContract()
                        c.contractNewSetPoint(setValue,maxprice,money)
                        printlog("successfully contracted after cancelOldContract")
                        break
                    except ValueError as e:
                        time.sleep(30)
            j=0
            while True:
                j+=1
                time.sleep(60)
                try:
                    if (c.callContracted()==False):
                        printlog(str((j+1)*60) + " no longer contracted (contract ended by itself either due to no more funds or no more flexibility)")
                        break
                    elif (c.callFlexibilityAvailable(setValue,1000)==False):
                        printlog(str((j+1)*60) + " no flexibility left --> cancelContract (should be cancelled automatically before)")
                        cancelOldContract()
                        break
                    else:
                        printlog(str((j+1)*60) + " still flexibility left :)")
                except Exception as e:
                    printlog(e)
        else:
            printlog("no flexibility --> do not start new contract")
    except Exception as e:
        printlog(e)
        printlog('probably no connection to blockchain')

price = 1000000000
time_interval = 0
time.sleep(time_interval)
while True:
    time_interval = randint(4,8) * 15 * 60
    vz = randint(0,1)
    if vz == 0:
        vz = -1
    new_set_value = randint(4,8) * 10 * 1000000
    new_set_value_vz = new_set_value * vz
    newContract(int(new_set_value_vz),price,int(time_interval/15*new_set_value*price),time_interval)
    time.sleep(60 + randint(1,14400))