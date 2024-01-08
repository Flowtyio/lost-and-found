import "FlowToken"
import "FungibleToken"
import "ExampleNFT"

transaction {
    prepare(signer: AuthAccount) {
        let resource <- signer.load<@AnyResource>(from: ExampleNFT.CollectionStoragePath)
        destroy resource
        signer.unlink(ExampleNFT.CollectionPublicPath)
    }
}