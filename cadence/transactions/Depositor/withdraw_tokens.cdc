import LostAndFound from "../../contracts/LostAndFound.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"


transaction(amount: UFix64) {
    let flowReceiver: &{FungibleToken.Receiver}
    let lfDepositor: &LostAndFound.Depositor
    prepare(acct: AuthAccount) {
        self.flowReceiver = acct.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!
        self.lfDepositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!

        self.flowReceiver.deposit(from: <- self.lfDepositor.withdrawTokens(amount: amount))
    }
}
