import "LostAndFound"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let depositor <- acct.storage.load<@AnyResource>(from: LostAndFound.DepositorStoragePath)
        destroy depositor

        acct.capabilities.unpublish(LostAndFound.DepositorPublicPath)
    }
}
