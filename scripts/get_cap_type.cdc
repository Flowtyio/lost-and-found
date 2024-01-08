import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)
    let receiver = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    assert(receiver.check(), message: "receiver not configured correctly!")

    let instanceOf = receiver.borrow()!.isInstance(Type<@NonFungibleToken.Collection>())

    let casted = receiver as Capability<&{NonFungibleToken.Receiver}>
    return instanceOf
}