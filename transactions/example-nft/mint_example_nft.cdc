import "FungibleToken"
import "ExampleNFT"
import "NonFungibleToken"
import "MetadataViews"

transaction(recipient: Address, num: Int) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    prepare(acct: AuthAccount) {
        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")
    }

    execute {
        let receiver = getAccount(recipient).getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath).borrow()!

        var count = 0
        while count < num {
            count = count + 1
            self.minter.mintNFT(recipient: receiver, name: "testname", description: "descr", thumbnail: "image.html", royaltyReceipient: self.minter.owner!.address)
        }
    }
}
