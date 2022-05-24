import FungibleToken from 0xee82856bf20e2aa6
import ExampleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0x179b6b1cb6755e31

transaction(redeemer: Address, amount: UFix64) {
    let tokenAdmin: &ExampleToken.Administrator

    prepare(signer: AuthAccount) {
        self.tokenAdmin = signer.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("Signer is not the token admin")
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let manager = LostAndFound.borrowShelfManager()
        manager.deposit(redeemer: redeemer, item: <-mintedVault, memo: "hello!")

        destroy minter
    }
}