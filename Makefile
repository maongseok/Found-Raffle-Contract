-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

install :; forge install https://github.com/Cyfrin/foundry-devops@0.3.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 && forge install transmissions11/solmate@6 && forge install foundry-rs/forge-std@v1.9.7

deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(RPC_URL_SEPOLIA) --account metamask --broadcast --verify --etherscan-api-key $(SEPOLIA_ETHERSCAN_API_KEY) -vvvv

manual-verfiy :
	@forge verify-contract 0xb10D1f477FCc58b1409a57570Cb3DB4028B29d04 src/Raffle.sol:Raffle --etherscan-api-key $(SEPOLIA_ETHERSCAN_API_KEY) --rpc-url $(RPC_URL_SEPOLIA) --show-standard-json-input > json.json
