import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

transaction {
    prepare(signer: AuthAccount) {
        // Return early if the account already stores a ExampleToken Vault
        if signer.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {
            // Create a new ExampleToken Vault and put it in storage
            signer.save(
                <-ExampleNFT.createEmptyCollection(),
                to: ExampleNFT.CollectionStoragePath
            )
        }

        signer.unlink(ExampleNFT.CollectionPublicPath)
        signer.unlink(/private/exampleNFTCollection)

        // Create a public capability to the Vault that only exposes
        // the balance field through the Balance interface
        signer.link<&ExampleNFT.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
            ExampleNFT.CollectionPublicPath,
            target: ExampleNFT.CollectionStoragePath
        )

        signer.link<&ExampleNFT.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>(
            /private/exampleNFTCollection,
            target: ExampleNFT.CollectionStoragePath
        )
    }
}