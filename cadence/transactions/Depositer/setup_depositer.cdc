import LostAndFound from "../../contracts/LostAndFound.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"


transaction {
    prepare(acct: AuthAccount) {
        let flowTokenRepayment = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let depositer <- LostAndFound.createDepositer(flowTokenRepayment)
        acct.save(<-depositer, to: LostAndFound.DepositerStoragePath)
        acct.link<&LostAndFound.Depositer{LostAndFound.DepositerPublic}>(LostAndFound.DepositerPublicPath, target: LostAndFound.DepositerStoragePath)
    }
}