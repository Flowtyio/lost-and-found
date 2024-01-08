import "LostAndFound"

pub fun main(addr: Address): UFix64 {
    let depositorPublic = getAccount(addr).getCapability<&LostAndFound.Depositor{LostAndFound.DepositorPublic}>(LostAndFound.DepositorPublicPath).borrow()!
    return depositorPublic.balance()
}
