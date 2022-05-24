import LostAndFound from 0xf8d6e0586b0a20c7

pub fun main(addr: Address): [Type] {
    let shelfManager = LostAndFound.borrowShelfManager()
    let shelf = shelfManager.borrowShelf(redeemer: addr)
    return shelf.getRedeemableTypes()
}