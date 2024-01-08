import "ExampleNFT"
import "NonFungibleToken"

import "LostAndFound"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)
    let receiver = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    assert(receiver.check(), message: "receiver not configured correctly!")

    let instanceOf = receiver.borrow()!.isInstance(Type<@NonFungibleToken.Collection>())

    let casted = receiver as Capability<&{NonFungibleToken.Receiver}>
    return instanceOf
}