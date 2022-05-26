import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleToken from "../../contracts/ExampleToken.cdc"

pub fun main(addr: Address): UFix64 {
    let acct = getAccount(addr)
    return acct.getCapability<&{FungibleToken.Balance}>(/public/exampleTokenBalance).borrow()!.balance
}