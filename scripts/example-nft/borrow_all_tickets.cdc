import "LostAndFound"
import "ExampleNFT"

pub fun main(addr: Address): [&LostAndFound.Ticket] {
    return LostAndFound.borrowAllTicketsByType(addr: addr, type: Type<@ExampleNFT.NFT>())
}