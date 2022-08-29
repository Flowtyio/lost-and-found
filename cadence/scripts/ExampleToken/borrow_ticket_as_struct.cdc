import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleToken from "../../contracts/ExampleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

pub fun main(addr: Address, ticketID: UInt64): Ticket? {
    let shelfManager = LostAndFound.borrowShelfManager()
    let shelf = shelfManager.borrowShelf(redeemer: addr)
    let bin = shelf!.borrowBin(type: Type<@ExampleToken.Vault>())!

    let ticket = bin.borrowTicket(id: ticketID)
    return constructResult(ticket)
}

pub struct Ticket {

    // An optional message to attach to this item.
    pub let memo: String?
    // The address that it allowed to withdraw the item fromt this ticket
    pub let redeemer: Address
    //The type of the resource (non-optional) so that bins can represent the true type of an item
    pub let type: Type
    // State maintained by LostAndFound
    pub var redeemed: Bool

    init(_ ticket: &LostAndFound.Ticket) {
        self.memo = ticket.memo 
        self.redeemer = ticket.redeemer 
        self.type = ticket.type 
        self.redeemed = ticket.redeemed 
    }

}

pub fun constructResult(_ ticket: &LostAndFound.Ticket?) : Ticket? {
    if ticket != nil {
        return Ticket(ticket!)
    }
    return nil
}