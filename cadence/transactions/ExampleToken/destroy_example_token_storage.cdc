import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleToken from "../../contracts/ExampleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

transaction {
    prepare(signer: AuthAccount) {
        let resource <- signer.load<@AnyResource>(from: /storage/exampleTokenVault)
        destroy resource
        signer.unlink(/public/exampleTokenReceiver)
        signer.unlink(/public/exampleTokenBalance)
    }
}