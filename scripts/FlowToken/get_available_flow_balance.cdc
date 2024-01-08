import FlowStorageFees from "../../contracts/FlowStorageFees.cdc"

pub fun main(addr: Address): UFix64 {
    return FlowStorageFees.defaultTokenAvailableBalance(addr)
}
