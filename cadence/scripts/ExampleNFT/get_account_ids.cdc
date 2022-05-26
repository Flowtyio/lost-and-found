import ExampleNFT from 0x179b6b1cb6755e31
import NonFungibleToken from 0xf8d6e0586b0a20c7

pub fun main(addr: Address): [UInt64] {
    let account = getAccount(addr)
    let cap = account.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    return cap.borrow()!.getIDs()
}