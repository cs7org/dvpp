#!/usr/bin/python3
# -*- coding: utf-8 -*-

# parameters to adapt
contr_adr = '<insertaddressyouyourdeployedcontract>'
host = '<insertyourhost>'


import time, datetime
import logging
logging.basicConfig(level=logging.INFO)
Logging = logging.getLogger(__name__)
from web3.exceptions import BadFunctionCallOutput

import dataIn
dataPV = dataIn.dataIn(logging.getLogger("dataPV"), 'testpv.txt',False) #call class dataIn of module dataIn#dataPV = dataIn.dataIn(logging.getLogger("dataPV"), 'yourpath/yourPVsourcefile.txt',False) #call class dataIn of module dataIn
dataHH = dataIn.dataIn(logging.getLogger("dataHH"), 'testhh.txt',False)#dataHH = dataIn.dataIn(logging.getLogger("dataHH"), 'yourpath/yourHHsourcefile.txt',False)

import log
logger = log.log(logging.getLogger("logger"), datetime.datetime.now().strftime('log-%Y%m%d-%H%M%S.csv'))#logger = log.log(logging.getLogger("logger"), datetime.datetime.now().strftime('yourpath/log-%Y%m%d-%H%M%S.csv'))
logger.newEntry(['blocknumber[-]','number_of_users[-]','battery_management_command[mW]','power_battery[mW]','power_residual[mW]','SOC[m%]','load_household[mW]','production_pv[mW]', 'losses_ch[mWs]', 'losses_dch[mWs]', 'losses_idle_int[mWs]', 'losses_idle_ext[mWs]', 'time waited[us]','Contracted','registered','errorcode','bytes_sent','bytes_recv','packets_sent','packets_recv','errin','errout','dropin','dropout','cpu_geth','mem_geth','cpu_pythonloop','mem_pythonloop','gas_cons_prev'])

from contractWrapper import contractWrapper #communication with contract via web3 over HTTP RPC API
c=contractWrapper(contr_adr,host,0)

battery_size=6 #specify size of battery here
import battery #simple battery model
b=battery.battery(battery_size,battery_size,battery_size,battery_size/2)

import psutil
import analysis
import subprocess

#optional factors to scale the input data
facPV = 1.3
facHH = 0.8

#further params
sendtime = 5 #how log to wait after new block to send new status (1...15, default 5)
setValue = 0 #charging/discharging command for battery management
Pbat = 0 #charging/discharging action of battery
counter = 0 #counter in order to estimate when next block is expected
timeStep = 1 #timeStep for while loop; suggested minimum: 0.5
tw = 0 #waiting time
tw_overhead = 0
errorcode = 0 #for debugging reasons

#read in next load and production data
pv = dataPV.nextValue() * facPV
hh = dataHH.nextValue() * facHH

#calculate residual load
Pres = hh-pv

p_pythonloop = psutil.Process()
p_geth = analysis.find_proc_by_name('geth')

# register if not yet registered
c.checkForNewBlock()
try:
    if (c.Registered==False):
        c.register(battery_size * 500000,battery_size * 500000,50000000,b.SOC(),int(Pres), 5000000000000000000000000) #register with Popt = Pmax/2
        Logging.info('registering')
        while(True):
            time.sleep(1)
            if (c.checkForNewBlock()==True):
                Logging.info('succesfully registered')                
                break
    else:       
        Logging.info('already registered')
except Exception as e:
    if c.Contracted == True:    
        Logging.info('DVPP still contracted, wait till end of contract and try to join again')
    else:        
        Logging.info('Unknown error during registration: '+str(e))

t1 = time.time() #start time for sleep duration

while dataPV.valuesLeft() and dataHH.valuesLeft():
    try:
        #new block?
        if c.checkForNewBlock():            
            Logging.info('New block found')
            #Get new command for battery management from blockchain
            if (c.Registered==False):
                c.register(battery_size * 500000,battery_size * 500000,50000000,b.SOC(),int(Pres), 0)
                setValue=Pres                
                Logging.info('still unregistered --> operating battery alone: " + str(setValue), re-registering ...')
                counter = -15
            else:
                if c.Contracted == True:                   
                    Logging.info("Flexibility provision active")
                setValue = c.getSetValue()               
                Logging.info("New Set Value: " + str(setValue))
                counter = 0
        #no new block
        else:
            #wait till new block is expected to come, then post new status
            counter+=timeStep
            if counter == sendtime:
                #post current value in subprocess
                subprocess.Popen("python3 postStatus.py " + contr_adr + " " + host + " 0 " + str(int(Pres)) + " " + str(b.SOC()) + " " + str(setValue) + " " + str(int(Pbat)),shell=True)
    except BadFunctionCallOutput as e:
        setValue=Pres
        Logging.info("call failed (new block update) --> operating battery alone: " + str(setValue))
        errorcode = 1
    except ValueError as e:
        setValue=Pres
        Logging.info("transaction failed (post status or re-register) --> operating battery alone: " + str(setValue))
        errorcode = 2
    except Exception as e:
        setValue=Pres
        Logging.info("unknown error --> operating battery alone: " + str(setValue))
        errorcode = 3
    #charge/discharge battery according to setValue for the next timeStep
    if setValue > 0:
        Pbat = b.discharge(setValue,timeStep)
    elif setValue == 0:
        Pbat = b.idle(timeStep)
    else:
        Pbat = b.charge(setValue,timeStep)
    net_io = psutil.net_io_counters()
    logger.newEntry([c.blockNumber,c.noUsers,setValue,Pbat,Pres,b.SOC(),hh,pv,b.Elosses_charge,b.Elosses_discharge,b.Elosses_idle_internal,b.Elosses_idle_external,tw,c.SetPoint,c.PresTot,c.PricePerBlock,c.Balance,c.Contracted,c.Registered,errorcode,net_io[0],net_io[1],net_io[2],net_io[3],net_io[4],net_io[5],net_io[6],net_io[7],p_geth.cpu_percent(),p_geth.memory_percent(),p_pythonloop.cpu_percent(),p_pythonloop.memory_percent(),c.gasConsumption_post]) #load and production just to have it in the same file)
    errorcode = 0
    t2 = time.time()
    time.sleep(max(timeStep - t2 + t1 - tw_overhead,0))
    tt = time.time() #start time for sleep duration
    tw = (timeStep - t2 + t1 - tw_overhead)*1000000
    Logging.info('Waited for ' + str(tw) + 'ms')
    t1 = tt
    tw_overhead=0
    if tw <0:
        tw_overhead = int(-tw/1000000)
        Logging.info('could not finish loop in 1s', logging.INFO)
    
    #read in new data
    pv = dataPV.nextValue() * facPV
    hh = dataHH.nextValue() * facHH 
        
    # calculate residual load
    Pres = hh-pv
Logging.debug('Exited loop')