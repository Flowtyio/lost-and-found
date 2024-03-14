import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction(recipient: Address, amount: UFix64, revoke: Bool) {
    let tokenAdmin: &ExampleToken.Administrator

    let flowProvider: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>
    let flowReceiver: Capability<&FlowToken.Vault>
    let receiverCap: Capability<&{FungibleToken.Vault}>

    prepare(sender: auth(Storage, Capabilities) &Account, receiver: auth(Storage, Capabilities) &Account) {
        let v <- ExampleToken.createEmptyVault()
        let publicPath = v.getDefaultPublicPath()!
        let receiverPath = v.getDefaultReceiverPath()!
        let storagePath = v.getDefaultStoragePath()!
        destroy v

        self.tokenAdmin = sender.storage.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("acct is not the token admin")

        var provider: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>? = nil
        sender.capabilities.storage.forEachController(forPath: /storage/flowTokenVault, fun(c: &StorageCapabilityController): Bool {
            if c.borrowType == Type<auth(FungibleToken.Withdraw) &FlowToken.Vault>() {
                provider = c.capability as! Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>
            }

            return true
        })

        if provider == nil {
            provider = sender.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)
        }

        self.flowProvider = provider!
        self.flowReceiver = sender.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)!

        self.receiverCap = receiver.capabilities.storage.issue<&{FungibleToken.Vault}>(storagePath)

        if revoke {
            receiver.capabilities.storage.getController(byCapabilityID: self.receiverCap.id)!.delete()
        }
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let memo = "test memo"
        let depositEstimate <- LostAndFound.estimateDeposit(redeemer: recipient, item: <-mintedVault, memo: memo, display: nil)
        let storageFee <- self.flowProvider.borrow()!.withdraw(amount: depositEstimate.storageFee)
        let item <- depositEstimate.withdraw()

        LostAndFound.trySendResource(
            item: <-item,
            cap: self.receiverCap,
            memo: nil,
            display: nil,
            storagePayment: &storageFee as auth(FungibleToken.Withdraw) &{FungibleToken.Vault},
            flowTokenRepayment: self.flowReceiver
        )

        self.flowReceiver.borrow()!.deposit(from: <-storageFee)
        destroy depositEstimate
        destroy minter
    }
}