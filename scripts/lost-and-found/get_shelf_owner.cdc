import "LostAndFound"

pub fun main(addr: Address): Address {
    let m = LostAndFound.borrowShelfManager()
    let shelf = m.borrowShelf(redeemer: addr)!
    return shelf.getOwner()
}