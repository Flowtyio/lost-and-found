import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import LostAndFound from "../../contracts/LostAndFound.cdc"

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