import LostAndFound from "../../contracts/LostAndFound.cdc"
import LostAndFoundHelper from "../../contracts/LostAndFoundHelper.cdc"

pub fun main(addr: Address): [LostAndFoundHelper.Ticket] {

    let res : [LostAndFoundHelper.Ticket] = []
    for ticket in  LostAndFound.borrowAllTickets(addr: addr) {
        if let t = LostAndFoundHelper.constructResult(ticket, id: nil) {
            res.append(t)
        }
    }

    return res
}
