import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

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
        self.depositor.deposit(redeemer: recipient, item: <- mintedVault, memo: memo, display: nil)
        
        destroy minter
    }
}