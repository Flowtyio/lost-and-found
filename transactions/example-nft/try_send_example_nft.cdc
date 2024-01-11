import "FlowToken"
import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

import "LostAndFound"

transaction(recipient: Address, revoke: Bool) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    let flowProvider: Capability<auth(FungibleToken.Withdrawable) &FlowToken.Vault>
    let flowReceiver: Capability<&FlowToken.Vault>
    let nftReceiverCap: Capability<&{NonFungibleToken.Collection}>

    prepare(sender: auth(Storage,Capabilities) &Account, receiver: auth(Storage,Capabilities) &Account) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = sender.storage.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")

        var provider: Capability<auth(FungibleToken.Withdrawable) &FlowToken.Vault>? = nil
        sender.capabilities.storage.forEachController(forPath: /storage/flowTokenVault, fun(c: &StorageCapabilityController): Bool {
            if c.borrowType == Type<auth(FungibleToken.Withdrawable) &FlowToken.Vault>() {
                provider = c.capability as! Capability<auth(FungibleToken.Withdrawable) &FlowToken.Vault>
            }

            return true
        })

        if provider == nil {
            provider = sender.capabilities.storage.issue<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(/storage/flowTokenVault)
        }

        self.flowProvider = provider!
        self.flowReceiver = sender.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)!

        self.nftReceiverCap = receiver.capabilities.storage.issue<&{NonFungibleToken.Collection}>(ExampleNFT.CollectionStoragePath)

        if revoke {
            receiver.capabilities.storage.getController(byCapabilityID: self.nftReceiverCap.id)!.delete()
        }
    }

    execute {
        let token <- self.minter.mint(name: "testname", description: "descr", thumbnail: "image.html")
        let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?

        let memo = "test memo"
        let depositEstimate <- LostAndFound.estimateDeposit(redeemer: recipient, item: <-token, memo: memo, display: display)
        let storageFee <- self.flowProvider.borrow()!.withdraw(amount: depositEstimate.storageFee)
        let item <- depositEstimate.withdraw()

        LostAndFound.trySendResource(
            item: <-item,
            cap: self.nftReceiverCap,
            memo: nil,
            display: display,
            storagePayment: &storageFee,
            flowTokenRepayment: self.flowReceiver
        )
        
        self.flowReceiver.borrow()!.deposit(from: <-storageFee)
        destroy depositEstimate
    }
}
