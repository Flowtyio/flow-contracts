import "FlowtyDrops"
import "MetadataViews"
import "ViewResolver"
import "AddressUtils"

access(all) contract DropTypes {
    access(all) struct Display {
        access(all) let name: String
        access(all) let description: String
        access(all) let url: String

        init(_ display: MetadataViews.Display) {
            self.name = display.name
            self.description = display.description
            self.url = display.thumbnail.uri()
        }
    }

    access(all) struct Media {
        access(all) let url: String
        access(all) let mediaType: String

        init(_ media: MetadataViews.Media) {
            self.url = media.file.uri()
            self.mediaType = media.mediaType
        }
    }

    access(all) struct DropSummary {
        access(all) let id: UInt64
        access(all) let display: Display
        access(all) let medias: [Media]
        access(all) let totalMinted: Int
        access(all) let minterCount: Int
        access(all) let commissionRate: UFix64
        access(all) let nftType: String

        access(all) let address: Address?
        access(all) let mintedByAddress: Int?

        access(all) let phases: [PhaseSummary]

        access(all) let blockTimestamp: UInt64
        access(all) let blockHeight: UInt64

        init(
            id: UInt64,
            display: MetadataViews.Display,
            medias: MetadataViews.Medias?,
            totalMinted: Int,
            minterCount: Int,
            mintedByAddress: Int?,
            commissionRate: UFix64,
            nftType: Type,
            address: Address?,
            phases: [PhaseSummary]
        ) {
            self.id = id
            self.display = Display(display)
            
            self.medias = []
            for m in medias?.items ?? [] {
                self.medias.append(Media(m))
            }


            self.totalMinted = totalMinted
            self.commissionRate = commissionRate
            self.minterCount = minterCount
            self.mintedByAddress = mintedByAddress
            self.nftType = nftType.identifier
            self.address = address
            self.phases = phases

            let b = getCurrentBlock()
            self.blockHeight = b.height
            self.blockTimestamp = UInt64(b.timestamp)
        }
    }

    access(all) struct Quote {
        access(all) let price: UFix64
        access(all) let quantity: Int
        access(all) let paymentIdentifier: String
        access(all) let minter: Address?

        init(price: UFix64, quantity: Int, paymentIdentifier: String, minter: Address?) {
            self.price = price
            self.quantity = quantity
            self.paymentIdentifier = paymentIdentifier
            self.minter = minter
        }
    }

    access(all) struct PhaseSummary {
        access(all) let id: UInt64
        access(all) let index: Int

        access(all) let switcherType: String
        access(all) let pricerType: String
        access(all) let addressVerifierType: String

        access(all) let hasStarted: Bool
        access(all) let hasEnded: Bool
        access(all) let start: UInt64?
        access(all) let end: UInt64?

        access(all) let paymentTypes: [String]
        
        access(all) let address: Address?
        access(all) let remainingForAddress: Int?

        access(all) let quote: Quote?

        init(
            index: Int,
            phase: &{FlowtyDrops.PhasePublic},
            address: Address?,
            totalMinted: Int?,
            minter: Address?,
            quantity: Int?,
            paymentIdentifier: String?
        ) {
            self.index = index
            self.id = phase.uuid

            let d = phase.getDetails()
            self.switcherType = d.switcher.getType().identifier
            self.pricerType = d.pricer.getType().identifier
            self.addressVerifierType = d.addressVerifier.getType().identifier

            self.hasStarted = d.switcher.hasStarted()
            self.hasEnded = d.switcher.hasEnded()
            self.start = d.switcher.getStart()
            self.end = d.switcher.getEnd()

            self.paymentTypes = []
            for pt in d.pricer.getPaymentTypes() {
                self.paymentTypes.append(pt.identifier)
            }

            if let addr = address {
                self.address = address
                self.remainingForAddress = d.addressVerifier.remainingForAddress(addr: addr, totalMinted: totalMinted ?? 0)
            } else {
                self.address = nil
                self.remainingForAddress = nil
            }

            if paymentIdentifier != nil && quantity != nil {
                let price = d.pricer.getPrice(num: quantity!, paymentTokenType: CompositeType(paymentIdentifier!)!, minter: minter)

                self.quote = Quote(price: price, quantity: quantity!, paymentIdentifier: paymentIdentifier!, minter: minter)
            } else {
                self.quote = nil
            }
        }
    }

    access(all) fun getDropSummary(nftTypeIdentifier: String, dropID: UInt64, minter: Address?, quantity: Int?, paymentIdentifier: String?): DropSummary? {
        let nftType = CompositeType(nftTypeIdentifier) ?? panic("invalid nft type identifier")
        let segments = nftTypeIdentifier.split(separator: ".")
        let contractAddress = AddressUtils.parseAddress(nftType)!
        let contractName = segments[2]

        let resolver = getAccount(contractAddress).contracts.borrow<&{ViewResolver}>(name: contractName)
        if resolver == nil {
            return nil
        }

        let dropResolver = resolver!.resolveContractView(resourceType: nftType, viewType: Type<FlowtyDrops.DropResolver>()) as! FlowtyDrops.DropResolver?
        if dropResolver == nil {
            return nil
        }

        let container = dropResolver!.borrowContainer()
        if container == nil {
            return nil
        }

        let drop = container!.borrowDropPublic(id: dropID)
        if drop == nil {
            return nil
        }

        let dropDetails = drop!.getDetails()

        let phaseSummaries: [PhaseSummary] = []
        for index, phase in drop!.borrowAllPhases() {
            let summary = PhaseSummary(
                index: index,
                phase: phase,
                address: minter,
                totalMinted: minter != nil ? dropDetails.minters[minter!] : nil,
                minter: minter,
                quantity: quantity,
                paymentIdentifier: paymentIdentifier
            )
            phaseSummaries.append(summary)
        }

        let dropSummary = DropSummary(
            id: drop!.uuid,
            display: dropDetails.display,
            medias: dropDetails.medias,
            totalMinted: dropDetails.totalMinted,
            minterCount: dropDetails.minters.keys.length,
            mintedByAddress: minter != nil ? dropDetails.minters[minter!] : nil,
            commissionRate: dropDetails.commissionRate,
            nftType: CompositeType(dropDetails.nftType)!,
            address: minter,
            phases: phaseSummaries
        )

        return dropSummary
    }

    access(all) fun getAllDropSummaries(nftTypeIdentifier: String, minter: Address?, quantity: Int?, paymentIdentifier: String?): [DropSummary] {
        let nftType = CompositeType(nftTypeIdentifier) ?? panic("invalid nft type identifier")
        let segments = nftTypeIdentifier.split(separator: ".")
        let contractAddress = AddressUtils.parseAddress(nftType)!
        let contractName = segments[2]
        
        let resolver = getAccount(contractAddress).contracts.borrow<&{ViewResolver}>(name: contractName)
        if resolver == nil {
            return []
        }

        let dropResolver = resolver!.resolveContractView(resourceType: nftType, viewType: Type<FlowtyDrops.DropResolver>()) as! FlowtyDrops.DropResolver?
        if dropResolver == nil {
            return []
        }

        let container = dropResolver!.borrowContainer()
        if container == nil {
            return []
        }

        let summaries: [DropSummary] = []
        for id in container!.getIDs() {
            let drop = container!.borrowDropPublic(id: id)
            if drop == nil {
                continue
            }

            let dropDetails = drop!.getDetails()

            let phaseSummaries: [PhaseSummary] = []
            for index, phase in drop!.borrowAllPhases() {
                let summary = PhaseSummary(
                    index: index,
                    phase: phase,
                    address: minter,
                    totalMinted: minter != nil ? dropDetails.minters[minter!] : nil,
                    minter: minter,
                    quantity: quantity,
                    paymentIdentifier: paymentIdentifier
                )
                phaseSummaries.append(summary)
            }

            summaries.append(DropSummary(
                id: drop!.uuid,
                display: dropDetails.display,
                medias: dropDetails.medias,
                totalMinted: dropDetails.totalMinted,
                minterCount: dropDetails.minters.keys.length,
                mintedByAddress: minter != nil ? dropDetails.minters[minter!] : nil,
                commissionRate: dropDetails.commissionRate,
                nftType: CompositeType(dropDetails.nftType)!,
                address: minter,
                phases: phaseSummaries
            ))
        }

        return summaries
    }
}