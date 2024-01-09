import "LostAndFound"

pub fun main(addr: Address): [Type] {
    return LostAndFound.getRedeemableTypes(addr)
}