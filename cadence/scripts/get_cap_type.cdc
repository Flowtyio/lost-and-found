import ExampleNFT from 0x179b6b1cb6755e31
import NonFungibleToken from 0xf8d6e0586b0a20c7

import LostAndFound from 0xf8d6e0586b0a20c7

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)
    let receiver = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    assert(receiver.check(), message: "receiver not configured correctly!")

    let instanceOf = receiver.borrow()!.isInstance(Type<@NonFungibleToken.Collection>())

    let casted = receiver as Capability<&{NonFungibleToken.Receiver}>
    return instanceOf
}