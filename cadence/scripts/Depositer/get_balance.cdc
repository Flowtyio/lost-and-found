import LostAndFound from "../../contracts/LostAndFound.cdc"

pub fun main(addr: Address): UFix64 {
    let depositerPublic = getAccount(addr).getCapability<&LostAndFound.Depositer{LostAndFound.DepositerPublic}>(LostAndFound.DepositerPublicPath).borrow()!
    return depositerPublic.balance()
}