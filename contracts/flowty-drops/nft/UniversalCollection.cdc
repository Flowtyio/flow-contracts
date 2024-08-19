import "NonFungibleToken"
import "MetadataViews"
import "BaseCollection"

access(all) contract UniversalCollection {
    access(all) resource Collection: BaseCollection.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}
        access(all) var nftType: Type

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Collection(nftType: self.nftType)
        }

        init (nftType: Type) {
            self.ownedNFTs <- {}
            self.nftType = nftType
        }
    }

    access(all) fun createCollection(nftType: Type): @Collection {
        return <- create Collection(nftType: nftType)
    }
}