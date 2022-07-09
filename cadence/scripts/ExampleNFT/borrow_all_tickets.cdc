import LostAndFound from "../../contracts/LostAndFound.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"

pub fun main(addr: Address): [&LostAndFound.Ticket] {
    return LostAndFound.borrowAllTickets(addr: addr, type: Type<@ExampleNFT.NFT>())
}