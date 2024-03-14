import "FlowToken"
import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

import "LostAndFound"

transaction(recipient: Address, numToMint: Int) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    let flowProvider: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>
    let flowReceiver: Capability<&FlowToken.Vault>

    prepare(acct: auth(Storage, Capabilities) &Account) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.storage.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")

        let flowTokenProviderPath = /private/flowTokenLostAndFoundProviderPath
        let cap = acct.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)

        self.flowProvider = cap
        self.flowReceiver = acct.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)!
    }

    execute {
        let exampleNFTReceiver = getAccount(recipient).capabilities.get<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)!
        var numMinted = 0
        while numMinted < numToMint {
            numMinted = numMinted + 1

            let token <- self.minter.mintAndReturnNFT(name: "testname", description: "descr", thumbnail: "image.html")
            let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?

            let memo = "test memo"
            let depositEstimate <- LostAndFound.estimateDeposit(redeemer: recipient, item: <-token, memo: memo, display: display)
            let storageFee <- self.flowProvider.borrow()!.withdraw(amount: depositEstimate.storageFee)
            let item <- depositEstimate.withdraw()

            LostAndFound.trySendResource(
                item: <-item,
                cap: exampleNFTReceiver,
                memo: nil,
                display: display,
                storagePayment: &storageFee as auth(FungibleToken.Withdraw) &{FungibleToken.Vault},
                flowTokenRepayment: self.flowReceiver
            )

            self.flowReceiver.borrow()!.deposit(from: <-storageFee)
            destroy depositEstimate
        }
        
    }
}
