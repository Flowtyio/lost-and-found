import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(amount: UFix64) {
    prepare(acct: AuthAccount) {
        let flowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
        let tokens <- flowVault.withdraw(amount: amount)
        let vault <-tokens as! @FlowToken.Vault

        let depositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
        depositor.addFlowTokens(vault: <- vault)
    }
}
