import "LostAndFound"

pub fun main(addr: Address): [&LostAndFound.Ticket] {
    return LostAndFound.borrowAllTickets(addr: addr)
}