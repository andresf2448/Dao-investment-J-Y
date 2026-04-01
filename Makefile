
.PHONY: install

i_foundry:; forge init --force

i_chainlink:; forge install smartcontractkit/chainlink-brownie-contracts --no-git

i_solmate:; forge install transmissions11/solmate --no-git

i_foundry_dev:; forge install Cyfrin/foundry-devops --no-git

i_openzeppelin:; forge install openzeppelin/openzeppelin-contracts --no-git

i_chainlinkKit:; forge install smartcontractkit/ccip --no-git

i_chainlinkLocal:; forge install smartcontractkit/chainlink-local --no-git

#  Merkle Tree Generation with Foundry and Murky
i_murky:; forge install dmfxyz/murky --no-git

#
i_oz_upgradeable:; forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-git

# AA EIP 4337
i_ethAccountAbstraction:; forge install eth-infinitism/account-abstraction --no-git

# NATIVE AA ZK
i_zkAccountAbstraction:; forge install Cyfrin/foundry-era-contracts --no-git

.PHONY: coverage

coverage:
	forge coverage --report lcov
	genhtml lcov.info --output-directory coverage
	xdg-open coverage/index.html