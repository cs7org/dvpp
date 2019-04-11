# DVPP
DLT based platform for community driven active power flexibility provision

coming soon

## Quickstart
For a test of the smart contract just try it in Remix (https://remix.ethereum.org/) e.g. with Ganache (https://truffleframework.com/ganache)

For a setup on a private chain follow the Quickstart according to https://github.com/cs7org/ethome, using the files from cs7org/ethome/scripts.
However:
* smart contract tested on solidity 0.4.24+commit.e67f0147
* tested with web3.py 5.0.0a9 
* use more nodes (in our case we used 20), sync chain and start node.py in each node 
* add at least an extra node for contracting flexibility
* make sure each node has enough ETH
* use contractDVPP.py in the contracting nodes to contract the community to provide flexibility pseudo-randomly
* use round-robin.py for round robin minting
* psutil is used for analysis of network traffic and more other vars are logged like balance change 

## License
This project is licensed under the LGPL License - see the [LICENSE](LICENSE) file for details
