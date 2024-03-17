import "FlowToken"
import "NonFungibleToken"
import "ExampleNFT"

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {

        // Return early if the account already stores a ExampleToken Vault
        if signer.storage.borrow<&ExampleNFT.NFT>(from: ExampleNFT.CollectionStoragePath) != nil {
            return
        }

        // Create a new ExampleToken Vault and put it in storage
        signer.storage.save(
            <-ExampleNFT.createEmptyCollection(),
            to: ExampleNFT.CollectionStoragePath
        )

        let cap = signer.capabilities.storage.issue<&ExampleNFT.Collection>(ExampleNFT.CollectionStoragePath)
        signer.capabilities.publish(cap, at: ExampleNFT.CollectionPublicPath)
    }
}