import LostAndFound from "../contracts/LostAndFound.cdc"

pub fun main(addr: Address, type: String, ticketID: UInt64): Address? {
    let shelfManager = LostAndFound.borrowShelfManager()
    if let shelf = shelfManager.borrowShelf(redeemer: addr) {
        if let bin = shelf.borrowBin(type: CompositeType(type)!) {
            if let ticket = bin.borrowTicket(id: ticketID) {
                return ticket.getFlowRepaymentAddress()
            }
        }
    }
    return nil
}
 