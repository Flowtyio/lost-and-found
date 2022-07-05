import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"

transaction {
    prepare(signer: AuthAccount) {
        let resource <- signer.load<@AnyResource>(from: ExampleNFT.CollectionStoragePath)
        destroy resource
        signer.unlink(ExampleNFT.CollectionPublicPath)
    }
}