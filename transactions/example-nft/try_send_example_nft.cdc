import "FlowToken"
import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

import "LostAndFound"

transaction(recipient: Address) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    let flowProvider: Capability<&FlowToken.Vault{FungibleToken.Provider}>
    let flowReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

    prepare(acct: AuthAccount) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")

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
        let exampleNFTReceiver = getAccount(recipient).getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)

        let token <- self.minter.mint(name: "testname", description: "descr", thumbnail: "image.html")
        let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?

        let memo = "test memo"
        let depositEstimate <- LostAndFound.estimateDeposit(redeemer: recipient, item: <-token, memo: memo, display: display)
        let storageFee <- self.flowProvider.borrow()!.withdraw(amount: depositEstimate.storageFee)
        let resource <- depositEstimate.withdraw()

        LostAndFound.trySendResource(
            resource: <-resource,
            cap: exampleNFTReceiver,
            memo: nil,
            display: display,
            storagePayment: &storageFee as &FungibleToken.Vault,
            flowTokenRepayment: self.flowReceiver
        )
        
        self.flowReceiver.borrow()!.deposit(from: <-storageFee)
        destroy depositEstimate
    }
}
