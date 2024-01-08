import "FlowToken"
import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

import "LostAndFound"

transaction(recipient: Address) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter
    let depositor: &LostAndFound.Depositor

    prepare(acct: AuthAccount) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")
        self.depositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    execute {
        let token <- self.minter.mintAndReturnNFT(name: "testname", description: "descr", thumbnail: "image.html", royalties: [])
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
