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

        let cap = acct.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)
        self.flowProvider = cap
        self.flowReceiver = acct.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)!
    }

    execute {
        var numMinted = 0
        while numMinted < numToMint {
            numMinted = numMinted + 1

            let token <- self.minter.mint(name: "testname", description: "descr", thumbnail: "image.html")
            let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?

            let memo = "test memo"
            let storageFee <- self.flowProvider.borrow()!.withdraw(amount: 0.1)

            LostAndFound.deposit(
                redeemer: recipient,
                item: <-token,
                memo: memo,
                display: display,
                storagePayment: &storageFee as auth(FungibleToken.Withdraw) &{FungibleToken.Vault},
                flowTokenRepayment: self.flowReceiver
            )

            self.flowReceiver.borrow()!.deposit(from: <-storageFee)
        }
    }
}
