import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction() {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let cap = acct.capabilities.storage.issue<&ExampleToken.Vault>(/storage/exampleTokenVault)
        LostAndFound.redeemAll(type: Type<@ExampleToken.Vault>(), max: nil, receiver: cap)
        acct.capabilities.storage.getController(byCapabilityID: cap.id)!.delete()
    }
}
