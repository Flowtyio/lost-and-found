import "LostAndFound"
import "FungibleToken"
import "FlowToken"

transaction(newThreshold: UFix64?) {
    let lfDepositor: &LostAndFound.Depositor

    prepare(acct: AuthAccount) {
        self.lfDepositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!

        self.lfDepositor.setLowBalanceThreshold(threshold: newThreshold)
    }
}
