import LostAndFound from "../../contracts/LostAndFound.cdc"

pub fun main(addr: Address): [&LostAndFound.Ticket] {
    return LostAndFound.borrowAllTickets(addr: addr)
}