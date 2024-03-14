import "FlowToken"
import "FungibleToken"
import "NonFungibleToken"
import "ExampleToken"
import "ExampleNFT"

import "LostAndFound"

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Return early if the account already stores a ExampleToken Vault
        if signer.storage.borrow<&AnyResource>(from: /storage/exampleTokenVault) == nil {
            // Create a new ExampleToken Vault and put it in storage
            signer.storage.save(
                <-ExampleToken.createEmptyVault(),
                to: /storage/exampleTokenVault
            )

            let cap = signer.capabilities.storage.issue<&ExampleToken.Vault>(/storage/exampleTokenVault)
            signer.capabilities.publish(cap, at: /public/exampleTokenReceiver)
            signer.capabilities.publish(cap, at: /public/exampleTokenBalance)
        }


        // Return early if the account already stores a ExampleToken Vault
        if signer.storage.borrow<&AnyResource>(from: ExampleNFT.CollectionStoragePath) == nil {
            // Create a new ExampleToken Vault and put it in storage
            signer.storage.save(
                <-ExampleNFT.createEmptyCollection(),
                to: ExampleNFT.CollectionStoragePath
            )

            let cap = signer.capabilities.storage.issue<&ExampleNFT.Collection>(ExampleNFT.CollectionStoragePath)
            signer.capabilities.publish(cap, at: ExampleNFT.CollectionPublicPath)
        }

        let redeemableTypes = LostAndFound.getRedeemableTypes(signer.address)
        let nftType = Type<@ExampleNFT.NFT>()
        if redeemableTypes.contains(nftType) {
            let nftReceiver = signer.capabilities.get<&{NonFungibleToken.Collection}>(ExampleNFT.CollectionPublicPath)!
            LostAndFound.redeemAll(type: nftType, max: nil, receiver: nftReceiver)
        }

        let ftType = Type<@ExampleToken.Vault>()
        if redeemableTypes.contains(ftType) {
            let ftReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)!
            LostAndFound.redeemAll(type: Type<@ExampleToken.Vault>(), max: nil, receiver: ftReceiver)
        }
    }
}