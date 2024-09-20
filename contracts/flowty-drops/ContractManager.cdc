import "FlowToken"
import "FungibleToken"
import "FungibleTokenRouter"

access(all) contract ContractManager {
    access(all) let StoragePath: StoragePath
    access(all) let PublicPath: PublicPath

    access(all) let OwnerStoragePath: StoragePath
    access(all) let OwnerPublicPath: PublicPath

    access(all) entitlement Manage

    access(all) event ManagerSaved(uuid: UInt64, contractAddress: Address, ownerAddress: Address)

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

        // Should be called after saving a ContractManager resource to signal that a new address stores (and therefore "owns")
        // this manager resource's acct capability. Without this, it is not possible to track the original creator of a contract
        // when using the ContractManager
        access(Manage) fun onSave() {
            let acct = self.acct.borrow()!

            acct.storage.load<Address>(from: ContractManager.OwnerStoragePath)
            acct.storage.save(self.owner!.address, to: ContractManager.OwnerStoragePath)

            if !acct.capabilities.get<&Address>(ContractManager.OwnerPublicPath).check() {
                acct.capabilities.unpublish(ContractManager.OwnerPublicPath)
                acct.capabilities.publish(
                    acct.capabilities.storage.issue<&Address>(ContractManager.OwnerStoragePath),
                    at: ContractManager.OwnerPublicPath
                )
            }

            emit ManagerSaved(uuid: self.uuid, contractAddress: self.acct.address, ownerAddress: self.owner!.address)
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

        let ownerIdentifier = "ContractManager_Owner_".concat(self.account.address.toString())
        self.OwnerStoragePath = StoragePath(identifier: ownerIdentifier)!
        self.OwnerPublicPath = PublicPath(identifier: ownerIdentifier)!
    }
}