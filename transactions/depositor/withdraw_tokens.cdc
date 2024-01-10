import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(amount: UFix64) {
    let flowReceiver: &{FungibleToken.Receiver}
    let lfDepositor: &LostAndFound.Depositor
    prepare(acct: AuthAccount) {
        self.flowReceiver = acct.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!
        self.lfDepositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!

        self.flowReceiver.deposit(from: <- self.lfDepositor.withdrawTokens(amount: amount))
    }
}
