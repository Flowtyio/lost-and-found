import ExampleNFT from 0x179b6b1cb6755e31
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0xf8d6e0586b0a20c7

transaction() {
    let receiver: Capability<&{NonFungibleToken.CollectionPublic}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath).check() {
            let collection <- ExampleNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: ExampleNFT.CollectionStoragePath)

            // create a public capability for the collection
            acct.link<&{NonFungibleToken.CollectionPublic}>(
                ExampleNFT.CollectionPublicPath,
                target: ExampleNFT.CollectionStoragePath
            )
        }
        
        self.receiver = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
        assert(self.receiver.check(), message: "receiver not configured correctly!")
    }

    execute {
        let shelfManager = LostAndFound.borrowShelfManager()
        let shelf = shelfManager.borrowShelf(redeemer: self.redeemer)
        shelf.redeemAll(type: Type<@ExampleNFT.NFT>(), max: nil, receiver: self.receiver)
    }
}
 