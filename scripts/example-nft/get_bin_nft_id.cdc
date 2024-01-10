import "ExampleNFT"
import "LostAndFound"

pub fun main(addr: Address, type: String): [UInt64] {
    let tickets = LostAndFound.borrowAllTicketsByType(addr: addr, type: CompositeType(type)!)
    let ids : [UInt64] = []
    for ticket in tickets {
        if let id = ticket.getNonFungibleTokenID() {
            ids.append(id)
        }
    }
    return ids
}