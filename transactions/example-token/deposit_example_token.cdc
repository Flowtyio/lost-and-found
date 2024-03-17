import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction(redeemer: Address, amount: UFix64) {
    let tokenAdmin: &ExampleToken.Administrator

    let flowProvider: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>
    let flowReceiver: Capability<&FlowToken.Vault>

    prepare(acct: auth(Storage, Capabilities) &Account) {
        self.tokenAdmin = acct.storage.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("acct is not the token admin")

        let flowTokenProviderPath = /private/flowTokenLostAndFoundProviderPath
        let cap = acct.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)
        self.flowProvider = cap
        self.flowReceiver = acct.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)!
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let memo = "test memo"
        let depositEstimate <- LostAndFound.estimateDeposit(redeemer: redeemer, item: <-mintedVault, memo: memo, display: nil)
        let storageFee <- self.flowProvider.borrow()!.withdraw(amount: depositEstimate.storageFee)
        let item <- depositEstimate.withdraw()

        LostAndFound.deposit(
            redeemer: redeemer,
            item: <-item,
            memo: memo,
            display: nil,
            storagePayment: &storageFee as auth(FungibleToken.Withdraw) &{FungibleToken.Vault},
            flowTokenRepayment: self.flowReceiver
        )

        self.flowReceiver.borrow()!.deposit(from: <-storageFee)
        destroy depositEstimate
        destroy minter
    }
}