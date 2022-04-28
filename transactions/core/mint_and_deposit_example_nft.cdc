import ExampleNFT from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0x179b6b1cb6755e31

transaction(recipient: Address) {
    // local variable for storing the minter reference
    let minter: &ExampleNFT.NFTMinter

    prepare(acct: AuthAccount) {

        // borrow a reference to the NFTMinter resource in storage
        self.minter = acct.borrow<&ExampleNFT.NFTMinter>(from: /storage/exampleNFTMinter)
            ?? panic("Could not borrow a reference to the NFT minter")
    }

    execute {
        let token <- self.minter.mintAndReturnNFT(name: "testname", description: "descr", thumbnail: "image.html", royalties: [])
        LostAndFound.borrowShelfManagerPublic().deposit(redeemer: recipient, item: <-token, memo: "test memo")
    }
}