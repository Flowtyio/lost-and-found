import "FlowToken"
import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

import "LostAndFound"

transaction(recipient: Address) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter
    let depositor: auth(LostAndFound.Deposit) &LostAndFound.Depositor

    prepare(acct: auth(Storage, Capabilities) &Account) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.storage.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")
        self.depositor = acct.storage.borrow<auth(LostAndFound.Deposit) &LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    execute {
        let token <- self.minter.mint(name: "testname", description: "descr", thumbnail: "image.html")
        let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
        let memo = "test memo"

        self.depositor.deposit(
            redeemer: recipient,
            item: <-token,
            memo: memo,
            display: display
        )
    }
}
