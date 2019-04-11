# DVPP
DLT based platform for community driven active power flexibility provision

## Quickstart
For a test of the smart contract just try it in Remix (https://remix.ethereum.org/) e.g. with Ganache (https://truffleframework.com/ganache)

For a setup on a private chain follow the Quickstart according to https://github.com/cs7org/ethome, using the files from cs7org/ethome/scripts.
However:
* deploy the CommunityController.sol from this project (tested on solidity 0.4.24+commit.e67f0147)
* adjust your HTTP host, contract address and folfer path in random-contracting.py and node-dvpp.py
* use more nodes (in our case we used 20), sync chain and start node-dvpp.py (tested with web3.py 5.0.0a9) in each node of the community
* make sure each node has enough ETH and accounts unlocked
* unfortunately you have to parameterize the battery in battery.py model yourself as the data is not publicly available 
* add at least an extra node for contracting flexibility and use e.g. random-contracting.py to create contracting txs pseudo-randomly
* use round-robin.py for round robin mining with index of node, total number of nodes and path to IPC file, e.g. for first of 20 nodes:
```
python3 round-robin.py 0 20 .ethereum/geth.ipc
```
* psutil is used for the analysis of the network traffic and more other vars are logged like balance change. You find all logs in a csv logfile

## License
This project is licensed under the LGPL License - see the [LICENSE](LICENSE) file for details
