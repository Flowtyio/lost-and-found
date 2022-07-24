import FungibleToken from "../../contracts/FungibleToken.cdc"

pub fun main(addr: Address): UFix64 {
    let cap = getAccount(addr).getCapability<&{FungibleToken.Balance}>(/public/flowTokenBalance)
    let balance = cap.borrow()!.balance

    return balance
}