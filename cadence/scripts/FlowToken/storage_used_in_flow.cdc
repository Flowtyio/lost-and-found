import FeeEstimator from "../../contracts/FeeEstimator.cdc"

pub fun main(addr: Address): UFix64 {
    return FeeEstimator.storageUsedToFlowAmount(getAccount(addr).storageUsed)
}
