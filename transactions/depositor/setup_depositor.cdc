import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(lowBalanceThreshold: UFix64?) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath) == nil {
            let flowTokenRepayment = acct.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)
            let depositor <- LostAndFound.createDepositor(flowTokenRepayment, lowBalanceThreshold: lowBalanceThreshold)
            acct.storage.save(<-depositor, to: LostAndFound.DepositorStoragePath)

            let cap = acct.capabilities.storage.issue<&{LostAndFound.DepositorPublic}>(LostAndFound.DepositorStoragePath)
            acct.capabilities.publish(cap, at: LostAndFound.DepositorPublicPath)
        }
    }
}
