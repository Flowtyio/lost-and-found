import "LostAndFound"
import "NonFungibleToken"

access(all) fun main(addr: Address, nftID: UInt64, nftStoragePath: StoragePath): UFix64 {
    let acct = getAuthAccount<auth(Storage) &Account>(addr)
    let c = acct.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(from: nftStoragePath)
        ?? panic("collection not found")
    let nft <- c.withdraw(withdrawID: nftID)
    let estimate <- LostAndFound.estimateDeposit(redeemer: addr, item: <-nft, memo: nil, display: nil)

    let item <- estimate.withdraw()
    c.deposit(token: <- (item as! @{NonFungibleToken.NFT}))

    let fee = estimate.storageFee
    destroy estimate

    return fee
}