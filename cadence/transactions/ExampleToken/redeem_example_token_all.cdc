import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleToken from "../../contracts/ExampleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

transaction() {
    let receiver: Capability<&{FungibleToken.Receiver}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/exampleTokenReceiver).check() {
            acct.save(
                <-ExampleToken.createEmptyVault(),
                to: /storage/exampleTokenVault
            )

            acct.link<&ExampleToken.Vault{FungibleToken.Receiver}>(
                /public/exampleTokenReceiver,
                target: /storage/exampleTokenVault
            )

            acct.link<&ExampleToken.Vault{FungibleToken.Balance}>(
                /public/exampleTokenBalance,
                target: /storage/exampleTokenVault
            )
        }

        self.receiver = acct.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
    }

    execute {
        LostAndFound.redeemAll(type: Type<@ExampleToken.Vault>(), max: nil, receiver: self.receiver)
    }
}
