import "FlowToken"
import "FungibleToken"
import "ExampleToken"

import "LostAndFound"

transaction(recipient: Address, amount: UFix64, revoke: Bool) {
    let tokenAdmin: &ExampleToken.Administrator
    let depositor: auth(LostAndFound.Deposit) &LostAndFound.Depositor
    let receiverCap: Capability<&{FungibleToken.Vault}>

    prepare(sender: auth(Storage, Capabilities) &Account, receiver: auth(Storage, Capabilities) &Account) {
        let v <- ExampleToken.createEmptyVault()
        let publicPath = v.getDefaultPublicPath()!
        let receiverPath = v.getDefaultReceiverPath()!
        let storagePath = v.getDefaultStoragePath()!
        destroy v

        self.tokenAdmin = sender.storage.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("acct is not the token admin")
        self.depositor = sender.storage.borrow<auth(LostAndFound.Deposit) &LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
        
        self.receiverCap = receiver.capabilities.storage.issue<&{FungibleToken.Vault}>(storagePath)

        if revoke {
            receiver.capabilities.storage.getController(byCapabilityID: self.receiverCap.id)!.delete()
        }
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        let memo = "test memo"

        self.depositor.trySendResource(
            item: <-mintedVault,
            cap: self.receiverCap,
            memo: nil,
            display: nil
        )
        
        destroy minter
    }
}