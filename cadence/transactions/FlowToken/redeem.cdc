import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

import LostAndFound from "../../contracts/LostAndFound.cdc"

transaction() {
    let receiver: Capability<&{FungibleToken.Receiver}>
    let redeemer: Address

    prepare(acct: AuthAccount) {
        self.redeemer = acct.address
        self.receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }

    execute {
        let shelfManager = LostAndFound.borrowShelfManager()
        let shelf = shelfManager.borrowShelf(redeemer: self.redeemer)
        shelf!.redeemAll(type: Type<@FlowToken.Vault>(), max: nil, receiver: self.receiver)
    }
}
