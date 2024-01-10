import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction {
    prepare(signer: AuthAccount) {
        let resource <- signer.load<@AnyResource>(from: /storage/exampleTokenVault)
        destroy resource
        signer.unlink(/public/exampleTokenReceiver)
        signer.unlink(/public/exampleTokenBalance)
    }
}