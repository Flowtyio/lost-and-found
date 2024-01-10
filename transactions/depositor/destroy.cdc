import "LostAndFound"

transaction {
    prepare(acct: AuthAccount) {
        let depositor <- acct.load<@AnyResource>(from: LostAndFound.DepositorStoragePath)
        destroy depositor

        acct.unlink(LostAndFound.DepositorPublicPath)
    }
}
