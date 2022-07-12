import LostAndFound from "../../contracts/LostAndFound.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"


transaction(amount: UFix64) {
    prepare(acct: AuthAccount) {
        let flowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
        let tokens <- flowVault.withdraw(amount: amount)
        let vault <-tokens as! @FlowToken.Vault

        let depositer = acct.borrow<&LostAndFound.Depositer>(from: LostAndFound.DepositerStoragePath)!
        depositer.addFlowTokens(vault: <- vault)
    }
}