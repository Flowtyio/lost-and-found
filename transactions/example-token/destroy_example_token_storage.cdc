import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        destroy signer.storage.load<@AnyResource>(from: /storage/exampleTokenVault)
        
        signer.capabilities.unpublish(/public/exampleTokenReceiver)
        signer.capabilities.unpublish(/public/exampleTokenBalance)
    }
}