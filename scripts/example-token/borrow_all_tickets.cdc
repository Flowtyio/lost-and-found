import "LostAndFound"
import "LostAndFoundHelper"
import "ExampleToken"

pub fun main(addr: Address): [LostAndFoundHelper.Ticket] {
    let tickets: [LostAndFoundHelper.Ticket] = []
    for ticket in LostAndFound.borrowAllTicketsByType(addr: addr, type: Type<@ExampleToken.Vault>()) {
        tickets.append(LostAndFoundHelper.constructResult(ticket, id: ticket.getNonFungibleTokenID())!)
    }

    return tickets
}