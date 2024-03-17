import "LostAndFound"

access(all) fun main(addr: Address): [Type] {
    return LostAndFound.getRedeemableTypes(addr)
}