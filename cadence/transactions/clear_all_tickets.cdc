import FlowToken from "../contracts/FlowToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import ExampleToken from "../contracts/ExampleToken.cdc"
import ExampleNFT from "../contracts/ExampleNFT.cdc"

import LostAndFound from "../contracts/LostAndFound.cdc"

transaction {

    prepare(signer: AuthAccount) {
        // Return early if the account already stores a ExampleToken Vault
        if signer.borrow<&AnyResource>(from: /storage/exampleTokenVault) == nil {
            // Create a new ExampleToken Vault and put it in storage
            signer.save(
                <-ExampleToken.createEmptyVault(),
                to: /storage/exampleTokenVault
            )

            // Create a public capability to the Vault that only exposes
            // the deposit function through the Receiver interface
            signer.link<&ExampleToken.Vault{FungibleToken.Receiver}>(
                /public/exampleTokenReceiver,
                target: /storage/exampleTokenVault
            )

            // Create a public capability to the Vault that only exposes
            // the balance field through the Balance interface
            signer.link<&ExampleToken.Vault{FungibleToken.Balance}>(
                /public/exampleTokenBalance,
                target: /storage/exampleTokenVault
            )
        }


        // Return early if the account already stores a ExampleToken Vault
        if signer.borrow<&AnyResource>(from: ExampleNFT.CollectionStoragePath) == nil {
            // Create a new ExampleToken Vault and put it in storage
            signer.save(
                <-ExampleNFT.createEmptyCollection(),
                to: ExampleNFT.CollectionStoragePath
            )

            // Create a public capability to the Vault that only exposes
            // the balance field through the Balance interface
            signer.link<&ExampleNFT.Collection{NonFungibleToken.CollectionPublic}>(
                ExampleNFT.CollectionPublicPath,
                target: ExampleNFT.CollectionStoragePath
            )
        }

        let redeemableTypes = LostAndFound.getRedeemableTypes(signer.address)
        let nftType = Type<@ExampleNFT.NFT>()
        if redeemableTypes.contains(nftType) {
            let nftReceiver = signer.getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
            LostAndFound.redeemAll(type: nftType, max: nil, receiver: nftReceiver)
        }

        let ftType = Type<@ExampleToken.Vault>()
        if redeemableTypes.contains(ftType) {
            let ftReceiver = signer.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
            LostAndFound.redeemAll(type: Type<@ExampleToken.Vault>(), max: nil, receiver: ftReceiver)
        }
    }
}