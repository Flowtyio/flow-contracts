# flow-contracts

```
npm i @flowtyio/flow-contracts
```

## Commands

**These commands assume you have installed flow-contracts and npx on your machine**

You can use `flow-contracts` to edit your own flow configuration so that you don't have to manually add contracts to your project.
Currently, there are two commands:
- add -> adds a contract and its dependencies to your flow.json
- add-all -> adds all contracts in this repo to your flow.json

### Add a contract

Adds a contract and its dependencies to your flow.json. This command will also add the contract to your emulator deployment section.
If there are any contracts already defined in your config which would be imported, it will be skipped

```
npx flow-contracts add MetadataViews -c /path/to/config/flow.json
```

### Add all contracts

Adds all contracts maintained in this repo to your own flow.json, and add them to your emulator deployment section.

```
npx flow-contracts add-all -c /path/to/config/flow.json
```


This repository publishes common Flow contracts as an npm package so that they can be more easily consumed. 
Currently, the list includes:

|  Name  |  Mainnet  |  Testnet  |
|--------|-----------|-----------|
| FungibleToken | 0xf233dcee88fe0abe | 0x9a0766d93b6608b7 |
| NonFungibleToken | 0x1d7e57aa55817448 | 0x631e88ae7f1d7c20 |
| MetadataViews | 0x1d7e57aa55817448 | 0x631e88ae7f1d7c20 |
| ViewResolver | 0x1d7e57aa55817448 | 0x631e88ae7f1d7c20 |
| HybridCusody | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| CapabilityFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| CapabilityFilter | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| CapabilityDelegator | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| FTAllFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| FTBalanceFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| FTProviderFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| FTReceiverFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| NFTCollectionPublicFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| NFTProviderAndCollectionPublicFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |
| NFTProviderFactory | 0x294e44e1ec6993c6 | 0xd8a7e05a7ac670c0 |


## Using a contract

You can follow our `example/flow.json` to see how to import each contract. Please note the following:
- **Some contracts need special handling and are marked with a * (see section below.)**
- The address of the emulator version of a deployed address might need to change depending on your setup
- You will also need to ensure that any contract you add is also in your emulator deployment section.

For example, here is how you might add `NonFungibleToken` to your flow.json :

```
{
	"networks": {
		"emulator": "127.0.0.1:3569",
		...
	},
	"accounts": {
		"emulator-account": {
			...
		}
	},
	"contracts": {
		"NonFungibleToken": {
			"source": "./node_modules/@flowty/flow-contracts/contracts/NonFungibleToken.cdc",
			"aliases": {
				"emulator": "0xf8d6e0586b0a20c7",
				"testnet": "0x631e88ae7f1d7c20",
				"mainnet": "0x1d7e57aa55817448"
			}
		}
	},
	"deployments": {
		"emulator": {
			"emulator-account": [
				"NonFungibleToken"
			]
		}
	}
}
```

## Important Notes

### FungibleToken

FungibleToken is a contract that is automatically deployed to the flow emulator. If you want to deploy
your project to the flow emulator AND you and to import `FungibleToken` into your contracts, scripts, or transactions,
you will need to:

- Add an account which deploys to the FungibleToken address
- Setup a deployment section in the emulator for this account
- Always deploy your project using the `--update` flag, even if it's the first deployment (this is because FungibleToken is already deployed)

```
{
	"networks": {
		"emulator": "127.0.0.1:3569"
	},
	"accounts": {
		"emulator-account": {
			"address": "f8d6e0586b0a20c7",
			"key": "a8201e155882e2a7ec94644ef0f023ecce8baec418276f95217db1ecf90b03db"
		},
		"emulator-ft": {
			"address": "ee82856bf20e2aa6",
			"key": "a8201e155882e2a7ec94644ef0f023ecce8baec418276f95217db1ecf90b03db"
		}
	},
	"contracts": {
		"FungibleToken": {
			"source": "./node_modules/@flowty/flow-contracts/contracts/FungibleToken.cdc",
			"aliases": {
				"emulator": "0xee82856bf20e2aa6",
			}
		}
	},
	"deployments": {
		"emulator": {
			"emulator-ft": [
				"FungibleToken"
			]
		}
	}
}
```

If you would like to request other contracts be included, please create a ticket, or submit a PullRequest to add them and
ping us on Twitter/Discord.

Cheers!
