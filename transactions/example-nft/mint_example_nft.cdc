import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

transaction(recipient: Address, num: Int) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    prepare(acct: auth(Storage, Capabilities) &Account) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.storage.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")
    }

    execute {
        let cap = getAccount(recipient).capabilities.get<&{NonFungibleToken.Collection}>(ExampleNFT.CollectionPublicPath) 
            ?? panic("receiver not found")
        let receiver = cap.borrow() ?? panic("unable to borrow collection")

        var count = 0
        while count < num {
            count = count + 1
            self.minter.mintNFT(recipient: receiver, name: "testname", description: "descr", thumbnail: "image.html", royaltyReceipient: self.minter.owner!.address)
        }
    }
}
