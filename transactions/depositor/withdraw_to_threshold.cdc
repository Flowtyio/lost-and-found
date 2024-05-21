import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(lowBalanceThreshold: UFix64) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath) == nil {
            let flowTokenRepayment = acct.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)
            let depositor <- LostAndFound.createDepositor(flowTokenRepayment, lowBalanceThreshold: lowBalanceThreshold)
            acct.storage.save(<-depositor, to: LostAndFound.DepositorStoragePath)

            let cap = acct.capabilities.storage.issue<auth(LostAndFound.Deposit, Mutate) &LostAndFound.Depositor>(LostAndFound.DepositorStoragePath)
            acct.capabilities.publish(cap, at: LostAndFound.DepositorPublicPath)
        }
        
        let depositor = acct.storage.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
        let balance = depositor.balance()

        let flowVault = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)!
        let tokens <- flowVault.withdraw(amount: lowBalanceThreshold - balance)
        let vault <-tokens as! @FlowToken.Vault

        depositor.addFlowTokens(vault: <- vault)        
    }
}
