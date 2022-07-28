import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleToken from "../../contracts/ExampleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

transaction(recipient: Address, amount: UFix64) {
    let tokenAdmin: &ExampleToken.Administrator
    let depositor: &LostAndFound.Depositor

    prepare(acct: AuthAccount) {
        self.tokenAdmin = acct.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("acct is not the token admin")
        self.depositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let memo = "test memo"
        let exampleTokenReceiver = getAccount(recipient).getCapability<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)

        self.depositor.trySendResource(
            item: <-mintedVault,
            cap: exampleTokenReceiver,
            memo: nil,
            display: nil
        )
        
        destroy minter
    }
}