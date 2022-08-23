import FungibleToken from "../../contracts/FungibleToken.cdc"
import LostAndFound from "../../contracts/LostAndFound.cdc"

pub fun main(addr: Address, type: Type): UFix64 {
    let tickets = LostAndFound.borrowAllTicketsByType(addr: addr, type: type)
    var balance : UFix64 = 0.0
    for ticket in tickets {
        if let b = ticket.getFungibleTokenBalance() {
            balance = balance + b
        }
    }
    return balance
}