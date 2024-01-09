import "LostAndFound"
import "LostAndFoundHelper"

pub fun main(addr: Address): [LostAndFoundHelper.Ticket] {
    let tickets: [LostAndFoundHelper.Ticket] = []
    for ticket in LostAndFound.borrowAllTickets(addr: addr) {
        tickets.append(LostAndFoundHelper.constructResult(ticket, id: ticket.getNonFungibleTokenID())!)
    }
    
    return tickets
}