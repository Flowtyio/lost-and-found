import "LostAndFound"

access(all) fun main(addr: Address, identifier: String): Bool {
    let c = CompositeType(identifier)!
    let m = LostAndFound.borrowShelfManager()
    let shelf = m.borrowShelf(redeemer: addr) ?? panic("shelf not found for address")
    return shelf.hasType(type: c)
}