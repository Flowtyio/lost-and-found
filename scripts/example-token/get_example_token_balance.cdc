import "FungibleToken"
import "ExampleToken"

pub fun main(addr: Address): UFix64 {
    let acct = getAccount(addr)
    return acct.getCapability<&{FungibleToken.Balance}>(/public/exampleTokenBalance).borrow()!.balance
}