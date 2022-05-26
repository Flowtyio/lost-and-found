import FlowToken from 0x0ae53cb6e3f42a79
import ExampleNFT from 0x179b6b1cb6755e31
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0xf669cb8d41ce0c74

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
        let token <- self.minter.mintAndReturnNFT(name: "testname", description: "descr", thumbnail: "image.html", royalties: [])
        LostAndFound.borrowShelfManager().deposit(
            redeemer: recipient,
            item: <-token,
            memo: "test memo",
            storagePaymentProvider: self.flowProvider,
            flowTokenRepayment: self.flowReceiver
        )
    }
}
 