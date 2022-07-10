# LostAndFound
Giving items to users who are not configured for a given resource type
is challenging on flow. Many applications have to either not allow users 
to receive assets, or they have to come up with their own escrow 
solution.

LostAndFound is a contract meant to solve this issue so other 
applications do not need to. It organizes items that users can redeem based on the type of the asset. This should make it easy for apps to 
integrate with that they can own allowing users to claim their items in the LostAndFound. 

|Network|Address|
|-------|-------|
|testnet|0xad5da38444961c71|

## Structure
This contract is organized into a few key components:

### Shelf
A shelf is our high-level organizer. There is one shelf per redeemable address.

A shelf has an array of Bins (covered later), and an associated address. Only that address can claim items on that shelf.
There is only one shelf allowed per address

### Bin
Bins exist on Shelf Resources. A bin consists of an array of Tickets (covered later) and an associated type.
All Items deposited to a shelf are routed to their type's bin. For instance, if I send an account USDC tokens, 
a bin corresponding to the USDC vault (FiatToken.Vault) would be made, and all subsequent deposits of FiatToken.Vault
types would be routed to that same bin. 

If a bin is emptied of all its Tickets, it can be destroyed and a new one would be made once that type is deposited again.

### Ticket
Tickets are the resource that contain our deposited items to be redeemed by other accounts. A ticket has an item which represents
the resource being deposited, a redeemer address, and a memo in case the depositer would like to send a message to the redeemer

### ShelfManager
The ShelfManager is a light wrapper around our stored shelves. It exposes a means to borrow shelves so that redeemers can withdraw
items that have been sent to them, and another helper to deposit items to a redeemer. 

## Usage

### NFTs


Deposit an item

```cadence
import ExampleNFT from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0xf669cb8d41ce0c74

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
        LostAndFound.deposit(redeemer: recipient, item: <-token, memo: "test memo")
    }
}
```

Redeem them all

```cadence
import ExampleNFT from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0xf669cb8d41ce0c74

transaction() {
    let receiver: Capability<&{NonFungibleToken.CollectionPublic}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath).check() {
            let collection <- ExampleNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: /storage/NFTCollection)

            // create a public capability for the collection
            acct.link<&{NonFungibleToken.CollectionPublic}>(
                ExampleNFT.CollectionPublicPath,
                target: /storage/NFTCollection
            )
        }
        
        self.receiver = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    }

    execute {
        LostAndFound.redeemAll(type: Type<@ExampleNFT.NFT>(), max: nil, receiver: self.receiver)
    }
}
```

### Fungible Tokens

Deposit a vault

```cadence
import FungibleToken from 0xee82856bf20e2aa6
import ExampleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0xf669cb8d41ce0c74

transaction(redeemer: Address, amount: UFix64) {
    let tokenAdmin: &ExampleToken.Administrator

    prepare(signer: AuthAccount) {
        self.tokenAdmin = signer.borrow<&ExampleToken.Administrator>(from: /storage/exampleTokenAdmin)
            ?? panic("Signer is not the token admin")
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        LostAndFound.deposit(redeemer: redeemer, item: <-mintedVault, memo: "hello!")

        destroy minter
    }
}
```

Redeem them

```cadence
import ExampleToken from 0xf8d6e0586b0a20c7
import FungibleToken from 0xee82856bf20e2aa6

import LostAndFound from 0xf669cb8d41ce0c74

transaction() {
    let receiver: Capability<&{FungibleToken.Receiver}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address

        if !acct.getCapability<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver).check() {
            acct.save(
                <-ExampleToken.createEmptyVault(),
                to: /storage/exampleTokenVault
            )

            acct.link<&ExampleToken.Vault{FungibleToken.Receiver}>(
                /public/exampleTokenReceiver,
                target: /storage/exampleTokenVault
            )

            acct.link<&ExampleToken.Vault{FungibleToken.Balance}>(
                /public/exampleTokenBalance,
                target: /storage/exampleTokenVault
            )
        }
        
        self.receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
    }

    execute {
        LostAndFound.redeemAll(type: Type<@ExampleToken.Vault>(), max: nil, receiver: self.receiver)
    }
}
 
```
