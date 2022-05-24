import ExampleToken from 0xf8d6e0586b0a20c7
import FungibleToken from 0xee82856bf20e2aa6

import LostAndFound from 0x179b6b1cb6755e31

transaction() {
    let receiver: Capability<&{FungibleToken.Receiver}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver).check() {
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
        
        self.receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
    }

    execute {
        let shelfManager = LostAndFound.borrowShelfManager()
        let shelf = shelfManager.borrowShelf(redeemer: self.redeemer)
        shelf.redeemAll(type: Type<@ExampleToken.Vault>(), max: nil, receiver: self.receiver)
    }
}
 