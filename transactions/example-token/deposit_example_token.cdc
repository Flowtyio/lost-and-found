import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction(redeemer: Address, amount: UFix64) {
    let tokenAdmin: &ExampleToken.Administrator

    let flowProvider: Capability<&FlowToken.Vault{FungibleToken.Provider}>
    let flowReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

    prepare(acct: AuthAccount) {
        self.tokenAdmin = acct.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("acct is not the token admin")

        let flowTokenProviderPath = /private/flowTokenLostAndFoundProviderPath

        if !acct.getCapability<&FlowToken.Vault{FungibleToken.Provider}>(flowTokenProviderPath).check() {
            acct.unlink(flowTokenProviderPath)
            acct.link<&FlowToken.Vault{FungibleToken.Provider}>(
                flowTokenProviderPath,
                target: /storage/flowTokenVault
            )
        }

        self.flowProvider = acct.getCapability<&FlowToken.Vault{FungibleToken.Provider}>(flowTokenProviderPath)
        self.flowReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let memo = "test memo"
        let depositEstimate <- LostAndFound.estimateDeposit(redeemer: redeemer, item: <-mintedVault, memo: memo, display: nil)
        let storageFee <- self.flowProvider.borrow()!.withdraw(amount: depositEstimate.storageFee)
        let resource <- depositEstimate.withdraw()

        LostAndFound.deposit(
            redeemer: redeemer,
            item: <-resource,
            memo: memo,
            display: nil,
            storagePayment: &storageFee as &FungibleToken.Vault,
            flowTokenRepayment: self.flowReceiver
        )

        self.flowReceiver.borrow()!.deposit(from: <-storageFee)
        destroy depositEstimate
        destroy minter
    }
}