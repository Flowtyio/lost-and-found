import ExampleNFT from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0x179b6b1cb6755e31

transaction() {
    let receiver: Capability<&{NonFungibleToken.CollectionPublic}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath).check() {
            let collection <- ExampleNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: /storage/NFTCollection)

            // create a public capability for the collection
            acct.link<&{NonFungibleToken.CollectionPublic}>(
                ExampleNFT.CollectionPublicPath,
                target: /storage/NFTCollection
            )
        }
        
        self.receiver = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    }

    execute {
        let shelfManager = LostAndFound.borrowShelfManagerPublic()
        let shelf = shelfManager.borrowShelf(redeemer: self.redeemer)
        shelf.redeemAll(type: Type<@ExampleNFT.NFT>(), max: nil, nftReceiver: self.receiver, ftReceiver: nil, anyResourceReceiver: nil)
    }
}
 