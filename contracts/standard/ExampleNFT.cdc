/* 
*
*  This is an example implementation of a Flow Non-Fungible Token
*  It is not part of the official standard but it assumed to be
*  similar to how many NFTs would implement the core functionality.
*
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FungibleToken"

access(all) contract ExampleNFT: ViewResolver {

    access(all) var totalSupply: UInt64

    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)
    access(all) event Mint(id: UInt64)

    access(all) event CollectionCreated(id: UInt64)
    access(all) event CollectionDestroyed(id: UInt64)

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let MinterPublicPath: PublicPath

    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {
        access(all) let id: UInt64

        access(all) let name: String
        access(all) let description: String
        access(all) let thumbnail: String
        access(self) var royalties: [MetadataViews.Royalty]

        access(all) view fun getID(): UInt64 {
            return self.id
        }

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties

            emit Mint(id: self.id)
        }

        access(Mutate) fun setRoyalties(_ royalties: [MetadataViews.Royalty]) {
            self.royalties = royalties
        }
    
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionName = self.id % 2 == 0 ? "Example NFT Edition (even)" : "Example NFT Edition (odd)"
                    let editionInfo = MetadataViews.Edition(name: editionName, number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://example-nft.onflow.org/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: ExampleNFT.CollectionStoragePath,
                        publicPath: ExampleNFT.CollectionPublicPath,
                        providerPath: /private/exampleNFTCollection,
                        publicCollection: Type<&ExampleNFT.Collection>(),
                        publicLinkedType: Type<&ExampleNFT.Collection>(),
                        providerLinkedType: Type<auth(NonFungibleToken.Withdrawable) &ExampleNFT.Collection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-ExampleNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Example Collection",
                        description: "This collection is used as an example to help you develop your next Flow NFT.",
                        externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    let dict: {String: AnyStruct} = {
                        "name": self.name,
                        "even": self.id % 2 == 0,
                        "id": self.id
                    }
                    return MetadataViews.dictToTraits(dict: dict, excludedNames: [])
            }
            return nil
        }
    }

    access(all) resource interface ExampleNFTCollectionPublic: NonFungibleToken.Collection {
        access(all) fun deposit(token: @{NonFungibleToken.NFT})
        access(all) fun borrowExampleNFT(id: UInt64): &ExampleNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ExampleNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    access(all) resource Collection: ExampleNFTCollectionPublic {
        access(all) event ResourceDestroyed(id: UInt64 = self.uuid)

        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        access(self) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init () {
            self.ownedNFTs <- {}
            emit CollectionCreated(id: self.uuid)
        }

        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return ExampleNFT.CollectionStoragePath
        }

        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return ExampleNFT.CollectionPublicPath
        }

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {
                Type<@ExampleNFT.NFT>(): true
            }
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@ExampleNFT.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- ExampleNFT.createEmptyCollection()
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdrawable) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.getID(), from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @ExampleNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }
 
        access(all) fun borrowExampleNFT(id: UInt64): &ExampleNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
                return ref as! &ExampleNFT.NFT
            }

            return nil
        }
    }

    // public function that anyone can call to create a new empty collection
    access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    access(all) resource NFTMinter {
        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        access(all) fun mintNFT(
            recipient: &{NonFungibleToken.Collection},
            name: String,
            description: String,
            thumbnail: String,
            royaltyReceipient: Address,
        ) {
            ExampleNFT.totalSupply = ExampleNFT.totalSupply + 1
            self.mintNFTWithId(recipient: recipient, name: name, description: description, thumbnail: thumbnail, royaltyReceipient: royaltyReceipient, id: ExampleNFT.totalSupply)
        }

        access(all) fun mint(
            name: String,
            description: String,
            thumbnail: String,
        ): @NFT {
            ExampleNFT.totalSupply = ExampleNFT.totalSupply + 1
            let newNFT <- create NFT(
                id: ExampleNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: []
            )

            return <- newNFT
        }

        access(all) fun mintNFTWithId(
            recipient: &{NonFungibleToken.Collection},
            name: String,
            description: String,
            thumbnail: String,
            royaltyReceipient: Address,
            id: UInt64
        ) {
            let royaltyRecipient = getAccount(royaltyReceipient).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
            let cutInfo = MetadataViews.Royalty(receiver: royaltyRecipient, cut: 0.05, description: "")
            // create a new NFT
            var newNFT <- create NFT(
                id: id,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: [cutInfo]
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        access(all) fun mintNFTWithRoyaltyCuts(
            recipient: &{NonFungibleToken.Collection},
            name: String,
            description: String,
            thumbnail: String,
            royaltyReceipients: [Address],
            royaltyCuts: [UFix64]
        ) {
            assert(royaltyReceipients.length == royaltyCuts.length, message: "mismatched royalty recipients and cuts")
            let royalties: [MetadataViews.Royalty] = []

            var index = 0
            while index < royaltyReceipients.length {
                let royaltyRecipient = getAccount(royaltyReceipients[index]).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
                let cutInfo = MetadataViews.Royalty(receiver: royaltyRecipient, cut: royaltyCuts[index], description: "")
                royalties.append(cutInfo)
                index = index + 1
            }            

            ExampleNFT.totalSupply = ExampleNFT.totalSupply + 1

            // create a new NFT
            var newNFT <- create NFT(
                id: ExampleNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: royalties
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all) view fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                        storagePath: ExampleNFT.CollectionStoragePath,
                        publicPath: ExampleNFT.CollectionPublicPath,
                        providerPath: /private/exampleNFTCollection,
                        publicCollection: Type<&ExampleNFT.Collection>(),
                        publicLinkedType: Type<&ExampleNFT.Collection>(),
                        providerLinkedType: Type<auth(NonFungibleToken.Withdrawable) &ExampleNFT.Collection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-ExampleNFT.createEmptyCollection()
                        })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The Example Collection",
                    description: "This collection is used as an example to help you develop your next Flow NFT.",
                    externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                    }
                )
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all) view fun getViews(): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/exampleNFTCollection
        self.CollectionPublicPath = /public/exampleNFTCollection
        self.MinterStoragePath = /storage/exampleNFTMinter
        self.MinterPublicPath = /public/exampleNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        let cap = self.account.capabilities.storage.issue<&ExampleNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)

        // Create a Minter resource and save it to storage
        // let minter <- create NFTMinter()
        // self.account.save(<-minter, to: self.MinterStoragePath)
        let minterCap = self.account.capabilities.storage.issue<&ExampleNFT.NFTMinter>(self.MinterStoragePath)
        self.account.capabilities.publish(minterCap, at: self.MinterPublicPath)

        emit ContractInitialized()
    }
}
 