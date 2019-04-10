# DVPP
DLT based platform for community driven active power flexibility provision

coming soon

## Quickstart
For a test of the smart contract just try it in Remix (https://remix.ethereum.org/) e.g. with Ganache (https://truffleframework.com/ganache)

For a setup on a private chain follow the Quickstart according to https://github.com/cs7org/ethome
However:
* use more nodes (in our case we used 20), sync chain and start node.py in each node 
* add at least an extra node for contracting flexibility
* make sure each node has enoght eth
* use contractDVPP.py in the contracting nodes to contract the community to provide flexibility pseudo-randomly
