import LostAndFound from "../contracts/LostAndFound.cdc"

pub fun main(addr: Address): [Type] {
    let shelfManager = LostAndFound.borrowShelfManager()
    let shelf = shelfManager.borrowShelf(redeemer: addr)
    if shelf == nil {
        return []
    }
    
    return shelf!.getRedeemableTypes()
}
