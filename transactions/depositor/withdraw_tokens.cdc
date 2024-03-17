import "LostAndFound"
import "FungibleToken"
import "FlowToken"


transaction(amount: UFix64) {

    let flowReceiver: &{FungibleToken.Receiver}
    let lfDepositor: auth(Mutate) &LostAndFound.Depositor

    prepare(acct: auth(Storage) &Account) {
        self.flowReceiver = acct.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!
        self.lfDepositor = acct.storage.borrow<auth(Mutate) &LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    execute {
        self.flowReceiver.deposit(from: <- self.lfDepositor.withdrawTokens(amount: amount))
    }
}
