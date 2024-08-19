import "ContractInitializer"
import "NFTMetadata"
import "FlowtyDrops"

access(all) contract OpenEditionInitializer: ContractInitializer {
    access(all) fun initialize(contractAcct: auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account, params: {String: AnyStruct}): NFTMetadata.InitializedCaps {
        pre {
            params["data"] != nil: "missing param data"
            params["data"]!.getType() == Type<NFTMetadata.Metadata>(): "data param must be of type NFTMetadata.Metadata"
            params["collectionInfo"] != nil: "missing param collectionInfo"
            params["collectionInfo"]!.getType() == Type<NFTMetadata.CollectionInfo>(): "collectionInfo param must be of type NFTMetadata.CollectionInfo"
        }

        let data = params["data"]! as! NFTMetadata.Metadata
        let collectionInfo = params["collectionInfo"]! as! NFTMetadata.CollectionInfo

        let acct: auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account = Account(payer: contractAcct)
        let cap = acct.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()

        let t = self.getType()
        let contractName = t.identifier.split(separator: ".")[2]

        self.account.storage.save(cap, to: StoragePath(identifier: "metadataAuthAccount_".concat(contractName))!)

        // do we have information to setup a drop as well?
        if params.containsKey("dropDetails") && params.containsKey("phaseDetails") && params.containsKey("minterController") {
            // extract expected keys
            let minterCap = params["minterController"]! as! Capability<&{FlowtyDrops.Minter}>
            let dropDetails = params["dropDetails"]! as! FlowtyDrops.DropDetails
            let phaseDetails = params["phaseDetails"]! as! [FlowtyDrops.PhaseDetails]

            assert(minterCap.check(), message: "invalid minter capability")


            let phases: @[FlowtyDrops.Phase] <- []
            for p in phaseDetails {
                phases.append(<- FlowtyDrops.createPhase(details: p))
            }

            let drop <- FlowtyDrops.createDrop(details: dropDetails, minterCap: minterCap, phases: <- phases)
            if acct.storage.borrow<&AnyResource>(from: FlowtyDrops.ContainerStoragePath) == nil {
                acct.storage.save(<- FlowtyDrops.createContainer(), to: FlowtyDrops.ContainerStoragePath)

                acct.capabilities.unpublish(FlowtyDrops.ContainerPublicPath)
                acct.capabilities.publish(
                    acct.capabilities.storage.issue<&{FlowtyDrops.ContainerPublic}>(FlowtyDrops.ContainerStoragePath),
                    at: FlowtyDrops.ContainerPublicPath
                )
            }

            let container = acct.storage.borrow<auth(FlowtyDrops.Owner) &FlowtyDrops.Container>(from: FlowtyDrops.ContainerStoragePath)
                ?? panic("drops container not found")
            container.addDrop(<- drop)
        }
        
        return NFTMetadata.initialize(acct: acct, collectionInfo: collectionInfo, collectionType: self.getType())
    }
}