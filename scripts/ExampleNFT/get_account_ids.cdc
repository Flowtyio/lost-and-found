import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

pub fun main(addr: Address): [UInt64] {
    let account = getAccount(addr)
    let cap = account.getCapability<&{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
    return cap.borrow()!.getIDs()
}