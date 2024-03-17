import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(addr: Address, amount: UFix64) {
    prepare(acct: auth(BorrowValue) &Account) {
        let flowVault = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)!
        let tokens <- flowVault.withdraw(amount: amount)
        let vault <-tokens as! @FlowToken.Vault

        let depositor = getAccount(addr).capabilities.get<&{LostAndFound.DepositorPublic}>(LostAndFound.DepositorPublicPath)!.borrow()!
        depositor.addFlowTokens(vault: <- vault)
    }
}
