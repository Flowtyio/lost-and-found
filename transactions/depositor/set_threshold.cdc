import "LostAndFound"
import "FungibleToken"
import "FlowToken"

transaction(newThreshold: UFix64?) {
    let lfDepositor: auth(Mutate) &LostAndFound.Depositor

    prepare(acct: auth(Storage) &Account) {
        self.lfDepositor = acct.storage.borrow<auth(Mutate) &LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    execute {
        self.lfDepositor.setLowBalanceThreshold(threshold: newThreshold)
    }
}
