import "FungibleToken"
import "ExampleToken"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&ExampleToken.Vault>(from: /storage/exampleTokenVault) == nil {
            acct.storage.save(<-ExampleToken.createEmptyVault(), to: /storage/exampleTokenVault)
        }

        let v <- ExampleToken.createEmptyVault()
        let publicPath = v.getDefaultPublicPath()!
        let receiverPath = v.getDefaultReceiverPath()!
        let storagePath = v.getDefaultStoragePath()!
        destroy v

        var publicCap = acct.capabilities.get<&{FungibleToken.Vault}>(publicPath)
        if publicCap == nil {
            publicCap = acct.capabilities.storage.issue<&ExampleToken.Vault>(storagePath)
            acct.capabilities.publish(publicCap!, at: publicPath)
        }


        var receiverCap = acct.capabilities.get<&{FungibleToken.Receiver}>(receiverPath)
        if receiverCap == nil {
            receiverCap = acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(storagePath)
            acct.capabilities.publish(receiverCap!, at: receiverPath)
        }

        var foundProvider = false
        let providerSubtype = Type<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>()
        let caps = acct.capabilities.storage.forEachController(forPath: storagePath, fun(c: &StorageCapabilityController): Bool {
            if providerSubtype.isSubtype(of: c.borrowType) {
                foundProvider = true
            }
            return true   
        })

        if foundProvider {
            return
        }

        let cap = acct.capabilities.storage.issue<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(storagePath)
        assert(cap.check(), message: "unable to issue provider capability")
    }
}
 