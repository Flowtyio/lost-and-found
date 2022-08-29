import LostAndFound from "../../contracts/LostAndFound.cdc"

pub fun main(addr: Address): [Ticket] {

    let res : [Ticket] = []
    for ticket in  LostAndFound.borrowAllTickets(addr: addr) {
        if let t = constructResult(ticket) {
            res.append(t)
        }
    }

    return res
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