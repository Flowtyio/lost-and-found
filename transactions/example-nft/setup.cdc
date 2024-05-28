import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Return early if the account already stores a ExampleToken Vault
        if signer.storage.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {
            // Create a new ExampleToken Vault and put it in storage
            signer.storage.save(
                <-ExampleNFT.createEmptyCollection(),
                to: ExampleNFT.CollectionStoragePath
            )
        }

        let cd = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        var pubCap = signer.capabilities.get<&ExampleNFT.Collection>(cd.publicPath)
        if pubCap == nil {
            pubCap = signer.capabilities.storage.issue<&ExampleNFT.Collection>(cd.storagePath)
        } else if !pubCap!.check() {
            pubCap = signer.capabilities.storage.issue<&ExampleNFT.Collection>(cd.storagePath)
        }

        // does the public capability exist and succeed?
        signer.capabilities.unpublish(cd.publicPath)
        signer.capabilities.publish(pubCap!, at: cd.publicPath)

        // ensure there is a provider path for this collection
        var foundProvider = false
        let providerSubtype = Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>()
        let caps = signer.capabilities.storage.forEachController(forPath: cd.storagePath, fun(c: &StorageCapabilityController): Bool {
            if providerSubtype.isSubtype(of: c.borrowType) {
                foundProvider = true
            }
            return true   
        })

        if foundProvider {
            return
        }

        let cap = signer.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(cd.storagePath)
        assert(cap.check(), message: "unable to issue provider capability")
    }
}