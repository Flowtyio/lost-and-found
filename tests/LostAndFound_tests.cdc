import Test
import "test_helpers.cdc"

import "LostAndFound"
import "ExampleNFT"
import "ExampleToken"

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
    mintAndSendNft(acct)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(event.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), event.type.identifier)

    // estimate depositing another to see that the fee is reduced (we have initialized the shelf and bin for this user and resource type pairing)
    setupExampleNft(acct: acct)
    let id = mintExampleNfts(acct, 1)[0]
    let estimate = scriptExecutor("lost-and-found/estimate_deposit_nft.cdc", [acct.address, id, exampleNftStoragePath])! as! UFix64    
    Test.assert(estimate == 0.0, message: "fee is higher than expected")
}

pub fun testGetRedeemableTypes() {
    let acct = getNewAccount()
    mintAndSendNft(acct)

    let types = scriptExecutor("lost-and-found/get_redeemable_types.cdc", [acct.address])! as! [Type]
    let identifiers: [String] = []
    for t in types {
        identifiers.append(t.identifier)
    }

    Test.assert(identifiers.contains(exampleNftIdentifier()), message: "example nft type not found")
}

pub fun testTrySendNftResource_ValidCapability() {
    let acct = getNewAccount()
    setupExampleNft(acct: acct)
    
    trySendNft(acct)

    let event = Test.eventsOfType(Type<ExampleNFT.Deposit>()).removeLast() as! ExampleNFT.Deposit
    Test.assertEqual(acct.address, event.to!)
}

pub fun testTrySendNftResource_InvalidCapability() {
    let acct = getNewAccount()   
    trySendNft(acct)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(event.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), event.type.identifier)
}

pub fun testTrySendFtResource_ValidCapability() {
    let acct = getNewAccount()
    setupExampleToken(acct: acct)

    trySendFt(acct, 1.0)
    let event = Test.eventsOfType(Type<ExampleToken.TokensDeposited>()).removeLast() as! ExampleToken.TokensDeposited
    Test.assertEqual(acct.address, event.to!)
}

pub fun testTrySendFtResource_InvalidCapability() {
    let acct = getNewAccount()

    trySendFt(acct, 1.0)
    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(event.redeemer, acct.address)
    Test.assertEqual(exampleTokenIdentifier(), event.type.identifier)
}

pub fun testRedeemAllTickets_ExampleNft() {
    let acct = getNewAccount()
    let id = trySendNft(acct)

    setupExampleNft(acct: acct)
    txExecutor("example-nft/redeem_example_nft_all.cdc", [acct], [])

    let event = Test.eventsOfType(Type<ExampleNFT.Deposit>()).removeLast() as! ExampleNFT.Deposit
    Test.assertEqual(acct.address, event.to!)
    Test.assertEqual(id, event.id)
}

pub fun testRedeemAllTickets_ExampleToken() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount)

    setupExampleToken(acct: acct)
    txExecutor("example-token/redeem_example_token_all.cdc", [acct], [])

    let event = Test.eventsOfType(Type<ExampleToken.TokensDeposited>()).removeLast() as! ExampleToken.TokensDeposited
    Test.assertEqual(acct.address, event.to!)
    Test.assertEqual(amount, event.amount)
}

pub fun testGetAddress() {
    let addr = scriptExecutor("lost-and-found/get_address.cdc", [])! as! Address
    Test.assertEqual(lostAndFoundAccount.address, addr)
}

// TODO: send non nft/ft resource
// TODO: borrowAllTickets for address
// TODO: borrowAllTicketsByType - nft
// TODO: borrowAllTicketsByType - ft
// TODO: create depositor

pub fun mintAndSendNft(_ acct: Test.Account): UInt64 {
    txExecutor("example-nft/mint_and_deposit_example_nft.cdc", [exampleNftAccount], [acct.address])
    let event = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return event.id
}

pub fun trySendNft(_ acct: Test.Account): UInt64 {
    txExecutor("example-nft/try_send_example_nft.cdc", [exampleNftAccount], [acct.address])
    let event = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return event.id
}

pub fun trySendFt(_ acct: Test.Account, _ amount: UFix64) {
    txExecutor("example-token/try_send_example_token.cdc", [exampleTokenAccount], [acct.address, amount])
}