import LostAndFound from "../contracts/LostAndFound.cdc"

pub fun main(addr: Address, type: String, ticketID: UInt64): Address? {
    let shelfManager = LostAndFound.borrowShelfManager()
    let shelf = shelfManager.borrowShelf(redeemer: addr) ?? panic("No items to redeem for this user: ".concat(addr.toString()))
    let bin = shelf.borrowBin(type: CompositeType(type)!) ?? panic("No items to redeem for this user: ".concat(addr.toString()))
    let ticket = bin.borrowTicket(id: ticketID) ?? panic("No items to redeem for this user: ".concat(addr.toString()))
    
    return ticket.getFlowRepaymentAddress()
}
