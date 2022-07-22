import LostAndFound from "../../contracts/LostAndFound.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"


transaction(lowBalanceThreshold: UFix64?) {
    prepare(acct: AuthAccount) {
        if acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath) == nil {
            let flowTokenRepayment = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            let depositor <- LostAndFound.createDepositor(flowTokenRepayment, lowBalanceThreshold: lowBalanceThreshold)
            acct.save(<-depositor, to: LostAndFound.DepositorStoragePath)
            acct.link<&LostAndFound.Depositor{LostAndFound.DepositorPublic}>(LostAndFound.DepositorPublicPath, target: LostAndFound.DepositorStoragePath)
        }
    }
}
