import "FungibleToken"
import "FlowToken"

transaction(receiver: Address, amount: UFix64) {
    prepare(account: auth(Storage) &Account) {
        let flowVault = account.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow BlpToken.Vault reference")

        let receiverRef = getAccount(receiver)
            .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
            .borrow()
            ?? panic("Could not borrow FungibleToken.Receiver reference")

        let tokens <- flowVault.withdraw(amount: amount)
        receiverRef.deposit(from: <- tokens)
    }
}