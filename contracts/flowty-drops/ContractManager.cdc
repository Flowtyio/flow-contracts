import "FlowToken"
import "FungibleToken"

access(all) contract ContractManager {
    access(all) let StoragePath: StoragePath
    access(all) let PublicPath: PublicPath

    access(all) entitlement Manage

    access(all) resource Manager {
        access(self) let acct: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>

        access(Manage) fun borrowContractAccount(): auth(Contracts) &Account {
            return self.acct.borrow()!
        }

        access(all) fun addFlowTokensToAccount(_ tokens: @FlowToken.Vault) {
            self.acct.borrow()!.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-tokens)
        }

        access(all) fun getAccount(): &Account {
            return getAccount(self.acct.address)
        }

        init(tokens: @FlowToken.Vault) {
            pre {
                tokens.balance >= 0.001: "minimum balance of 0.001 required for initialization"
            }

            let acct = Account(payer: ContractManager.account)
            self.acct = acct.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
            assert(self.acct.check(), message: "failed to setup account capability")

            acct.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-tokens)
        }
    }

    access(all) fun createManager(tokens: @FlowToken.Vault): @Manager {
        return <- create Manager(tokens: <- tokens)
    }

    init() {
        let identifier = "ContractManager_".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
    }
}