import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

transaction() {
    let receiver: Capability<&{NonFungibleToken.CollectionPublic}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath).check() {
            let collection <- ExampleNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: ExampleNFT.CollectionStoragePath)

            // create a public capability for the collection
            acct.link<&AnyResource{NonFungibleToken.CollectionPublic}>(
                ExampleNFT.CollectionPublicPath,
                target: ExampleNFT.CollectionStoragePath
            )
        }

        self.receiver = acct.getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
        assert(self.receiver.check(), message: "receiver not configured correctly!")
    }

    execute {
        LostAndFound.redeemAll(type: Type<@ExampleNFT.NFT>(), max: nil, receiver: self.receiver)
    }
}
