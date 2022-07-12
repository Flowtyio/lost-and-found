import LostAndFound from "../../contracts/LostAndFound.cdc"

transaction {
    prepare(acct: AuthAccount) {
        let depositer <- acct.load<@AnyResource>(from: LostAndFound.DepositerStoragePath)
        destroy depositer

        acct.unlink(LostAndFound.DepositerPublicPath)
    }
}