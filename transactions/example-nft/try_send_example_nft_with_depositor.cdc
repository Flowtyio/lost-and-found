import "FlowToken"
import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

import "LostAndFound"

transaction(recipient: Address, revoke: Bool) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter
    let depositor: auth(LostAndFound.Deposit) &LostAndFound.Depositor
    let nftReceiverCap: Capability<&{NonFungibleToken.Collection}>

    prepare(sender: auth(Storage, Capabilities) &Account, receiver: auth(Storage, Capabilities) &Account) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = sender.storage.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")
        self.depositor = sender.storage.borrow<auth(LostAndFound.Deposit) &LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!

        self.nftReceiverCap = receiver.capabilities.storage.issue<&{NonFungibleToken.Collection}>(ExampleNFT.CollectionStoragePath)

        if revoke {
            receiver.capabilities.storage.getController(byCapabilityID: self.nftReceiverCap.id)!.delete()
        }
    }

    execute {
        let token <- self.minter.mint(name: "testname", description: "descr", thumbnail: "image.html")
        let display = token.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
        let memo = "test memo"

        self.depositor.trySendResource(
            item: <-token,
            cap: self.nftReceiverCap,
            memo: memo,
            display: display
        )
    }
}
