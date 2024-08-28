import "FlowToken"
import "FungibleToken"
import "FungibleTokenRouter"

access(all) contract ContractManager {
    access(all) let StoragePath: StoragePath
    access(all) let PublicPath: PublicPath

    access(all) entitlement Manage

    access(all) resource Manager {
        access(self) let acct: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        access(self) let routerCap: Capability<auth(FungibleTokenRouter.Owner) &FungibleTokenRouter.Router>

        access(all) let data: {String: AnyStruct}
        access(all) let resources: @{String: AnyResource}

        access(Manage) fun borrowContractAccount(): auth(Contracts) &Account {
            return self.acct.borrow()!
        }

        access(Manage) fun addOverride(type: Type, addr: Address) {
            let router = self.routerCap.borrow() ?? panic("fungible token router is not valid")
            router.addOverride(type: type, addr: addr)
        }

        access(Manage) fun getSwitchboard(): auth(FungibleTokenRouter.Owner) &FungibleTokenRouter.Router {
            return self.routerCap.borrow()!
        }

        access(all) fun addFlowTokensToAccount(_ tokens: @FlowToken.Vault) {
            self.acct.borrow()!.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-tokens)
        }

        access(all) fun getAccount(): &Account {
            return getAccount(self.acct.address)
        }

        init(tokens: @FlowToken.Vault, defaultRouterAddress: Address) {
            pre {
                tokens.balance >= 0.001: "minimum balance of 0.001 required for initialization"
            }

            let acct = Account(payer: ContractManager.account)
            self.acct = acct.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
            assert(self.acct.check(), message: "failed to setup account capability")

            acct.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-tokens)

            let router <- FungibleTokenRouter.createRouter(defaultAddress: defaultRouterAddress)
            acct.storage.save(<-router, to: FungibleTokenRouter.StoragePath)

            let receiver = acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(FungibleTokenRouter.StoragePath)
            assert(receiver.check(), message: "invalid switchboard receiver capability")
            acct.capabilities.publish(receiver, at: FungibleTokenRouter.PublicPath)

            self.routerCap = acct.capabilities.storage.issue<auth(FungibleTokenRouter.Owner) &FungibleTokenRouter.Router>(FungibleTokenRouter.StoragePath)

            self.data = {}
            self.resources <- {}
        }
    }

    access(all) fun createManager(tokens: @FlowToken.Vault, defaultRouterAddress: Address): @Manager {
        return <- create Manager(tokens: <- tokens, defaultRouterAddress: defaultRouterAddress)
    }

    init() {
        let identifier = "ContractManager_".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
    }
}