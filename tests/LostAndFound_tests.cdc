import Test
import "test_helpers.cdc"

import "LostAndFound"

pub fun setup() {
    deployAll()
}

pub fun testImport() {
    scriptExecutor("import_contracts.cdc", [])
}

pub fun testEstimateDeposit() {
    let acct = getNewAccount()
    setupExampleNft(acct: acct)

    let id = mintExampleNfts(acct, 1)[0]
    let estimate = scriptExecutor("lost-and-found/estimate_deposit_nft.cdc", [acct.address, id, exampleNftStoragePath])! as! UFix64

    Test.assert(estimate >= 0.00002, message: "fee is lower than expected")
}

pub fun testDepositNft() {
    let acct = getNewAccount()
    mintAndSendNft(acct: acct)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(event.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), event.type.identifier)

    // estimate depositing another to see that the fee is reduced (no shelf initialization)
    let id = mintExampleNfts(acct, 1)[0]
    let estimate = scriptExecutor("lost-and-found/estimate_deposit_nft.cdc", [acct.address, id, exampleNftStoragePath])! as! UFix64    
    Test.assert(estimate >= 0.00001, message: "fee is lower than expected")
    Test.assert(estimate < 0.00002, message: "fee is higher than expected")
}

// TODO: getRedeemableTypes
// TODO: deposit invalid payment type
// TODO: try send resource (NFT) - valid collection public capability
// TODO: try send resource (NFT) - invalid collection public capability
// TODO: try send resource (NFT) - valid receiver capability
// TODO: try send resource (NFT) - invalid receiver capability
// TODO: try send resource (FT) - valid receiver capability
// TODO: send non nft/ft resource
// TODO: getAddress
// TODO: redeemAll - nft
// TODO: redeemAll - ft
// TODO: borrowAllTickets for address
// TODO: borrowAllTicketsByType - nft
// TODO: borrowAllTicketsByType - ft
// TODO: create depositor

pub fun mintAndSendNft(acct: Test.Account) {
    txExecutor("example-nft/mint_and_deposit_example_nft.cdc", [exampleNftAccount], [acct.address])
}