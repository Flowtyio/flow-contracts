import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"
import "AddressUtils"

access(all) contract FlowtyDrops {
    access(all) let ContainerStoragePath: StoragePath
    access(all) let ContainerPublicPath: PublicPath

    access(all) event DropAdded(address: Address, id: UInt64, name: String, description: String, imageUrl: String, start: UInt64?, end: UInt64?)
    access(all) event Minted(address: Address, dropID: UInt64, phaseID: UInt64, nftID: UInt64, nftType: String)
    access(all) event PhaseAdded(dropID: UInt64, dropAddress: Address, id: UInt64, index: Int, switcherType: String, pricerType: String, addressVerifierType: String)
    access(all) event PhaseRemoved(dropID: UInt64, dropAddress: Address, id: UInt64)

    access(all) entitlement Owner
    access(all) entitlement EditPhase

    // Interface to expose all the components necessary to participate in a drop
    // and to ask questions about a drop.
    access(all) resource interface DropPublic {
        access(all) fun borrowPhasePublic(index: Int): &{PhasePublic}
        access(all) fun borrowActivePhases(): [&{PhasePublic}]
        access(all) fun borrowAllPhases(): [&{PhasePublic}]
        access(all) fun mint(
            payment: @{FungibleToken.Vault},
            amount: Int,
            phaseIndex: Int,
            expectedType: Type,
            receiverCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            commissionReceiver: Capability<&{FungibleToken.Receiver}>,
            data: {String: AnyStruct}
        ): @{FungibleToken.Vault}
        access(all) fun getDetails(): DropDetails
    }

    access(all) resource Drop: DropPublic {
        access(all) event ResourceDestroyed(
            uuid: UInt64 = self.uuid,
            minterAddress: Address = self.minterCap.address,
            nftType: String = self.details.nftType,
            totalMinted: Int = self.details.totalMinted
        )

        // phases represent the stages of a drop. For example, a drop might have an allowlist and a public mint phase.
        access(self) let phases: @[Phase]
        // the details of a drop. This includes things like display information and total number of mints
        access(self) let details: DropDetails
        access(self) let minterCap: Capability<&{Minter}>

        access(all) fun mint(
            payment: @{FungibleToken.Vault},
            amount: Int,
            phaseIndex: Int,
            expectedType: Type,
            receiverCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            commissionReceiver: Capability<&{FungibleToken.Receiver}>,
            data: {String: AnyStruct}
        ): @{FungibleToken.Vault} {
            pre {
                expectedType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()): "expected type must be an NFT"
                expectedType.identifier == self.details.nftType: "expected type does not match drop details type"
                self.phases.length > phaseIndex: "phase index is too high"
                receiverCap.check(): "receiver capability is not valid"
            }

            // validate the payment vault amount and type
            let phase: &Phase = &self.phases[phaseIndex]
            assert(
                phase.details.addressVerifier.canMint(addr: receiverCap.address, num: amount, totalMinted: self.details.minters[receiverCap.address] ?? 0, data: {}),
                message: "receiver address has exceeded their mint capacity"
            )

            let paymentAmount = phase.details.pricer.getPrice(num: amount, paymentTokenType: payment.getType(), minter: receiverCap.address)
            let withdrawn <- payment.withdraw(amount: paymentAmount) // make sure that we have a fresh vault resource

            // take commission
            let commission <- withdrawn.withdraw(amount: self.details.commissionRate * withdrawn.balance)
            commissionReceiver.borrow()!.deposit(from: <-commission)

            assert(phase.details.pricer.getPrice(num: amount, paymentTokenType: withdrawn.getType(), minter: receiverCap.address) * (1.0 - self.details.commissionRate) == withdrawn.balance, message: "incorrect payment amount")
            assert(phase.details.pricer.getPaymentTypes().contains(withdrawn.getType()), message: "unsupported payment type")

            // mint the nfts
            let minter = self.minterCap.borrow() ?? panic("minter capability could not be borrowed")
            let mintedNFTs <- minter.mint(payment: <-withdrawn, amount: amount, phase: phase, data: data)
            assert(phase.details.switcher.hasStarted() && !phase.details.switcher.hasEnded(), message: "phase is not active")
            assert(mintedNFTs.length == amount, message: "incorrect number of items returned")

            // distribute to receiver
            let receiver = receiverCap.borrow() ?? panic("could not borrow receiver capability")
            self.details.addMinted(num: mintedNFTs.length, addr: receiverCap.address)

            while mintedNFTs.length > 0 {
                let nft <- mintedNFTs.removeFirst()

                let nftType = nft.getType()
                emit Minted(address: receiverCap.address, dropID: self.uuid, phaseID: phase.uuid, nftID: nft.id, nftType: nftType.identifier)

                // validate that every nft is the right type
                assert(nftType == expectedType, message: "unexpected nft type was minted")
    
                receiver.deposit(token: <-nft)
            }

            // cleanup
            destroy mintedNFTs

            // return excess payment
            return <- payment
        }

        access(Owner) fun borrowPhase(index: Int): auth(EditPhase) &Phase {
            return &self.phases[index]
        }


        access(all) fun borrowPhasePublic(index: Int): &{PhasePublic} {
            return &self.phases[index]
        }

        access(all) fun borrowActivePhases(): [&{PhasePublic}] {
            let arr: [&{PhasePublic}] = []
            var count = 0
            while count < self.phases.length {
                let ref = self.borrowPhasePublic(index: count)
                let switcher = ref.getDetails().switcher
                if switcher.hasStarted() && !switcher.hasEnded() {
                    arr.append(ref)
                }

                count = count + 1
            }

            return arr
        }

        access(all) fun borrowAllPhases(): [&{PhasePublic}] {
            let arr: [&{PhasePublic}] = []
            var index = 0
            while index < self.phases.length {
                let ref = self.borrowPhasePublic(index: index)
                arr.append(ref)
                index = index + 1
            }

            return arr
        }

        access(Owner) fun addPhase(_ phase: @Phase) {
            emit PhaseAdded(
                dropID: self.uuid,
                dropAddress: self.owner!.address,
                id: phase.uuid,
                index: self.phases.length,
                switcherType: phase.details.switcher.getType().identifier,
                pricerType: phase.details.pricer.getType().identifier,
                addressVerifierType: phase.details.addressVerifier.getType().identifier
            )
            self.phases.append(<-phase)
        }

        access(Owner) fun removePhase(index: Int): @Phase {
            pre {
                self.phases.length > index: "index is greater than length of phases"
            }

            let phase <- self.phases.remove(at: index)
            emit PhaseRemoved(dropID: self.uuid, dropAddress: self.owner!.address, id: phase.uuid)

            return <- phase
        }

        access(all) fun getDetails(): DropDetails {
            return self.details
        }

        init(details: DropDetails, minterCap: Capability<&{Minter}>, phases: @[Phase]) {
            pre {
                minterCap.check(): "minter capability is not valid"
            }

            self.phases <- phases
            self.details = details
            self.minterCap = minterCap
        }
    }

    access(all) struct DropDetails {
        access(all) let display: MetadataViews.Display
        access(all) let medias: MetadataViews.Medias?
        access(all) var totalMinted: Int
        access(all) var minters: {Address: Int}
        access(all) let commissionRate: UFix64
        access(all) let nftType: String

        access(contract) fun addMinted(num: Int, addr: Address) {
            self.totalMinted = self.totalMinted + num
            if self.minters[addr] == nil {
                self.minters[addr] = 0
            }

            self.minters[addr] = self.minters[addr]! + num
        }

        init(display: MetadataViews.Display, medias: MetadataViews.Medias?, commissionRate: UFix64, nftType: String) {
            self.display = display
            self.medias = medias
            self.totalMinted = 0
            self.commissionRate = commissionRate
            self.minters = {}
            self.nftType = nftType
        }
    }

    // A switcher represents a phase being on or off, and holds information
    // about whether a phase has started or not.
    access(all) struct interface Switcher {
        // Signal that a phase has started. If the phase has not ended, it means that this switcher's phase
        // is active
        access(all) view fun hasStarted(): Bool
        // Signal that a phase has ended. If a switcher has ended, minting will not work. That could mean
        // the drop is over, or it could mean another phase has begun.
        access(all) view fun hasEnded(): Bool

        access(all) view fun getStart(): UInt64?
        access(all) view fun getEnd(): UInt64?
    }

    // A phase represents a stage of a drop. Some drops will only have one
    // phase, while others could have many. For example, a drop with an allow list
    // and a public mint would likely have two phases.
    access(all) resource Phase: PhasePublic {
        access(all) event ResourceDestroyed(uuid: UInt64 = self.uuid)

        access(all) let details: PhaseDetails

        // returns whether this phase of a drop has started.
        access(all) fun isActive(): Bool {
            return self.details.switcher.hasStarted() && !self.details.switcher.hasEnded()
        }

        access(all) fun getDetails(): PhaseDetails {
            return self.details
        }

        access(EditPhase) fun borrowSwitchAuth(): auth(Mutate) &{Switcher} {
            return &self.details.switcher
        }

        access(EditPhase) fun borrowPricerAuth(): auth(Mutate) &{Pricer} {
            return &self.details.pricer
        }

        access(EditPhase) fun borrowAddressVerifierAuth(): auth(Mutate) &{AddressVerifier} {
            return &self.details.addressVerifier
        }

        init(details: PhaseDetails) {
            self.details = details
        }
    }

    access(all) resource interface PhasePublic {
        // What does a phase need to be able to answer/manage?
        // - What are the details of the phase being interactive with?
        // - How many items are left in the current phase?
        // - Can Address x mint on a phase?
        // - What is the cost to mint for the phase I am interested in (for address x)?
        access(all) fun getDetails(): PhaseDetails
        access(all) fun isActive(): Bool
    }

    access(all) struct PhaseDetails {
        // handles whether a phase is on or not
        access(all) let switcher: {Switcher}

        // display information about a phase
        access(all) let display: MetadataViews.Display?

        // handles the pricing of a phase
        access(all) let pricer: {Pricer}

        // verifies whether an address is able to mint
        access(all) let addressVerifier: {AddressVerifier}

        // placecholder data dictionary to allow new fields to be accessed
        access(all) let data: {String: AnyStruct}

        init(switcher: {Switcher}, display: MetadataViews.Display?, pricer: {Pricer}, addressVerifier: {AddressVerifier}) {
            self.switcher = switcher
            self.display = display
            self.pricer = pricer
            self.addressVerifier = addressVerifier

            self.data = {}
        }
    }

    access(all) struct interface AddressVerifier {
        access(all) fun canMint(addr: Address, num: Int, totalMinted: Int, data: {String: AnyStruct}): Bool {
            return true
        }

        access(all) fun remainingForAddress(addr: Address, totalMinted: Int): Int? {
            return nil
        }
    }

    access(all) struct interface Pricer {
        access(all) fun getPrice(num: Int, paymentTokenType: Type, minter: Address?): UFix64
        access(all) fun getPaymentTypes(): [Type]
    }

    access(all) resource interface Minter {
        access(contract) fun mint(payment: @{FungibleToken.Vault}, amount: Int, phase: &FlowtyDrops.Phase, data: {String: AnyStruct}): @[{NonFungibleToken.NFT}] {
            let resourceAddress = AddressUtils.parseAddress(self.getType())!
            let receiver = getAccount(resourceAddress).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver).borrow()
                ?? panic("invalid flow token receiver")
            receiver.deposit(from: <-payment)

            let nfts: @[{NonFungibleToken.NFT}] <- []

            var count = 0
            while count < amount {
                count = count + 1
                nfts.append(<- self.createNextNFT())
            }

            return <- nfts
        }

        access(contract) fun createNextNFT(): @{NonFungibleToken.NFT}
    }
    
    access(all) struct DropResolver {
        access(self) let cap: Capability<&{ContainerPublic}>

        access(all) fun borrowContainer(): &{ContainerPublic}? {
            return self.cap.borrow()
        }

        init(cap: Capability<&{ContainerPublic}>) {
            pre {
                cap.check(): "container capability is not valid"
            }

            self.cap = cap
        }
    }

    access(all) resource interface ContainerPublic {
        access(all) fun borrowDropPublic(id: UInt64): &{DropPublic}?
        access(all) fun getIDs(): [UInt64]
    }

    // Contains drops. 
    access(all) resource Container: ContainerPublic {
        access(self) let drops: @{UInt64: Drop}

        access(Owner) fun addDrop(_ drop: @Drop) {
            let details = drop.getDetails()

            let phases = drop.borrowAllPhases()
            assert(phases.length > 0, message: "drops must have at least one phase to be added to a container")

            let firstPhaseDetails = phases[0].getDetails()

            emit DropAdded(
                address: self.owner!.address,
                id: drop.uuid,
                name: details.display.name,
                description: details.display.description,
                imageUrl: details.display.thumbnail.uri(),
                start: firstPhaseDetails.switcher.getStart(),
                end: firstPhaseDetails.switcher.getEnd()
            )
            destroy self.drops.insert(key: drop.uuid, <-drop)
        }

        access(Owner) fun removeDrop(id: UInt64): @Drop {
            pre {
                self.drops.containsKey(id): "drop was not found"
            }

            return <- self.drops.remove(key: id)!
        }

        access(Owner) fun borrowDrop(id: UInt64): auth(Owner) &Drop? {
            return &self.drops[id]
        }

        access(all) fun borrowDropPublic(id: UInt64): &{DropPublic}? {
            return &self.drops[id]
        }

        access(all) fun getIDs(): [UInt64] {
            return self.drops.keys
        }

        init() {
            self.drops <- {}
        }
    }

    access(all) fun createPhase(details: PhaseDetails): @Phase {
        return <- create Phase(details: details)
    }

    access(all) fun createDrop(details: DropDetails, minterCap: Capability<&{Minter}>, phases: @[Phase]): @Drop {
        return <- create Drop(details: details, minterCap: minterCap, phases: <- phases)
    }

    access(all) fun createContainer(): @Container {
        return <- create Container()
    }

    access(all) fun getMinterStoragePath(type: Type): StoragePath {
        let segments = type.identifier.split(separator: ".")
        let identifier = "FlowtyDrops_Minter_".concat(segments[1]).concat(segments[2])
        return StoragePath(identifier: identifier)!
    }

    init() {
        let identifier = "FlowtyDrops_".concat(self.account.address.toString())
        let containerIdentifier = identifier.concat("_Container")
        let minterIdentifier = identifier.concat("_Minter")

        self.ContainerStoragePath = StoragePath(identifier: containerIdentifier)!
        self.ContainerPublicPath = PublicPath(identifier: containerIdentifier)!
    }
}