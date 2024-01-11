import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction(recipient: Address, amount: UFix64) {
    let tokenAdmin: &ExampleToken.Administrator
    let depositor: auth(LostAndFound.Deposit) &LostAndFound.Depositor

    prepare(acct: auth(Storage, Capabilities) &Account) {
        self.tokenAdmin = acct.storage.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("acct is not the token admin")
        self.depositor = acct.storage.borrow<auth(LostAndFound.Deposit) &LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let memo = "test memo"
        self.depositor.deposit(redeemer: recipient, item: <- mintedVault, memo: memo, display: nil)
        
        destroy minter
    }
}