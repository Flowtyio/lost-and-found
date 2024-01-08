import "FungibleToken"
import "ExampleToken"

import "LostAndFound"
import LostAndFoundHelper from "../../contracts/LostAndFoundHelper.cdc"

pub fun main(addr: Address, ticketID: UInt64): LostAndFoundHelper.Ticket? {
    let shelfManager = LostAndFound.borrowShelfManager()
    let shelf = shelfManager.borrowShelf(redeemer: addr)
    let bin = shelf!.borrowBin(type: Type<@ExampleToken.Vault>())!

    let ticket = bin.borrowTicket(id: ticketID)
    return LostAndFoundHelper.constructResult(ticket, id: ticketID)
}
