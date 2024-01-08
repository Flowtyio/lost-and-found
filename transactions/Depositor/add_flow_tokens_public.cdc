import LostAndFound from "../../contracts/LostAndFound.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"


transaction(addr: Address, amount: UFix64) {
    prepare(acct: AuthAccount) {
        let flowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
        let tokens <- flowVault.withdraw(amount: amount)
        let vault <-tokens as! @FlowToken.Vault

        let depositor = getAccount(addr).getCapability<&{LostAndFound.DepositorPublic}>(LostAndFound.DepositorPublicPath).borrow()!
        depositor.addFlowTokens(vault: <- vault)
    }
}
