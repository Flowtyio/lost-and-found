import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {

        // Return early if the account already stores a ExampleToken Vault
        if signer.storage.borrow<&ExampleToken.Vault>(from: /storage/exampleTokenVault) != nil {
            return
        }

        // Create a new ExampleToken Vault and put it in storage
        signer.storage.save(
            <-ExampleToken.createEmptyVault(),
            to: /storage/exampleTokenVault
        )

        let cap = signer.capabilities.storage.issue<&ExampleToken.Vault>(/storage/exampleTokenVault)
        signer.capabilities.publish(cap, at: /public/exampleTokenReceiver)
        signer.capabilities.publish(cap, at: /public/exampleTokenBalance)
    }
}