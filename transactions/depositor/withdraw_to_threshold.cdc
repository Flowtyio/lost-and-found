import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(lowBalanceThreshold: UFix64) {
    prepare(acct: AuthAccount) {
        if acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath) == nil {
            let flowTokenRepayment = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            let depositor <- LostAndFound.createDepositor(flowTokenRepayment, lowBalanceThreshold: lowBalanceThreshold)
            acct.save(<-depositor, to: LostAndFound.DepositorStoragePath)
            acct.link<&LostAndFound.Depositor{LostAndFound.DepositorPublic}>(LostAndFound.DepositorPublicPath, target: LostAndFound.DepositorStoragePath)
        }
        
        let depositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
        let balance = depositor.balance()

        let flowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
        let tokens <- flowVault.withdraw(amount: lowBalanceThreshold - balance)
        let vault <-tokens as! @FlowToken.Vault

        depositor.addFlowTokens(vault: <- vault)        
    }
}
