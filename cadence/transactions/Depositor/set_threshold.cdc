import LostAndFound from "../../contracts/LostAndFound.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"

transaction(newThreshold: UFix64?) {
    let lfDepositor: &LostAndFound.Depositor

    prepare(acct: AuthAccount) {
        self.lfDepositor = acct.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!

        self.lfDepositor.setLowBalanceThreshold(threshold: newThreshold)
    }
}
