import Test
import "test_helpers.cdc"

import "LostAndFound"
import "LostAndFoundHelper"
import "ExampleNFT"
import "ExampleToken"

access(all) fun setup() {
    deployAll()

    mintFlow(exampleNftAccount, 10.0)
    mintFlow(exampleTokenAccount, 10.0)

    txExecutor("depositor/setup_depositor.cdc", [exampleNftAccount], [lowBalanceThreshold])
    txExecutor("depositor/add_flow_tokens.cdc", [exampleNftAccount], [lowBalanceThreshold])

    txExecutor("depositor/setup_depositor.cdc", [exampleTokenAccount], [lowBalanceThreshold])
    txExecutor("depositor/add_flow_tokens.cdc", [exampleTokenAccount], [lowBalanceThreshold])
}

access(all) fun testImport() {
    scriptExecutor("import_contracts.cdc", [])
}

access(all) fun testEstimateDeposit() {
    let acct = getNewAccount()
    setupExampleNft(acct: acct)

    let id = mintExampleNfts(acct, 1)[0]
    let estimate = scriptExecutor("lost-and-found/estimate_deposit_nft.cdc", [acct.address, id, exampleNftStoragePath])! as! UFix64

    Test.assert(estimate >= 0.00002, message: "fee is lower than expected")
}

access(all) fun testDepositNft() {
    let acct = getNewAccount()
    mintAndSendNft(acct)

    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(e.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), e.type.identifier)

    // estimate depositing another to see that the fee is reduced (we have initialized the shelf and bin for this user and resource type pairing)
    setupExampleNft(acct: acct)
    let id = mintExampleNfts(acct, 1)[0]
    let estimate = scriptExecutor("lost-and-found/estimate_deposit_nft.cdc", [acct.address, id, exampleNftStoragePath])! as! UFix64    
    Test.assert(estimate == 0.0, message: "fee is higher than expected")
}

access(all) fun testGetRedeemableTypes() {
    let acct = getNewAccount()
    mintAndSendNft(acct)

    let types = scriptExecutor("lost-and-found/get_redeemable_types.cdc", [acct.address])! as! [Type]
    let identifiers: [String] = []
    for t in types {
        identifiers.append(t.identifier)
    }

    Test.assert(identifiers.contains(exampleNftIdentifier()), message: "example nft type not found")
}

access(all) fun testTrySendNftResource_ValidCapability() {
    let acct = getNewAccount()
    setupExampleNft(acct: acct)
    
    trySendNft(acct, revoke: false)

    let e = Test.eventsOfType(Type<ExampleNFT.Deposit>()).removeLast() as! ExampleNFT.Deposit
    Test.assertEqual(acct.address, e.to!)
}

access(all) fun testTrySendNftResource_InvalidCapability() {
    let acct = getNewAccount()   
    trySendNft(acct, revoke: true)

    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(e.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), e.type.identifier)
}

access(all) fun testTrySendFtResource_ValidCapability() {
    let acct = getNewAccount()
    setupExampleToken(acct: acct)

    trySendFt(acct, 1.0, revoke: false)
    let e = Test.eventsOfType(Type<ExampleToken.TokensDeposited>()).removeLast() as! ExampleToken.TokensDeposited
    Test.assertEqual(acct.address, e.to!)
}

access(all) fun testTrySendFtResource_InvalidCapability() {
    let acct = getNewAccount()

    trySendFt(acct, 1.0, revoke: true)
    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(e.redeemer, acct.address)
    Test.assertEqual(exampleTokenIdentifier(), e.type.identifier)
}

access(all) fun testRedeemAllTickets_ExampleNft() {
    let acct = getNewAccount()
    let id = trySendNft(acct, revoke: true)

    setupExampleNft(acct: acct)
    txExecutor("example-nft/redeem_example_nft_all.cdc", [acct], [])

    let e = Test.eventsOfType(Type<ExampleNFT.Deposit>()).removeLast() as! ExampleNFT.Deposit
    Test.assertEqual(acct.address, e.to!)
    Test.assertEqual(id, e.id)
}

access(all) fun testRedeemAllTickets_ExampleToken() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount, revoke: true)

    setupExampleToken(acct: acct)
    txExecutor("example-token/redeem_example_token_all.cdc", [acct], [])

    let e = Test.eventsOfType(Type<ExampleToken.TokensDeposited>()).removeLast() as! ExampleToken.TokensDeposited
    Test.assertEqual(acct.address, e.to!)
    Test.assertEqual(amount, e.amount)
}

access(all) fun testGetAddress() {
    let addr = scriptExecutor("lost-and-found/get_address.cdc", [])! as! Address
    Test.assertEqual(lostAndFoundAccount.address, addr)
}

access(all) fun testBorrowAllTickets() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount, revoke: true)
    let id = trySendNft(acct, revoke: true)

    let tickets = scriptExecutor("lost-and-found/borrow_all_tickets.cdc", [acct.address])! as! [LostAndFoundHelper.Ticket]
    Test.assertEqual(2, tickets.length)

    // there should be one nft and one ft ticket
    var nftID: UInt64? = nil
    var foundFt = false

    for ticket in tickets {
        switch ticket.typeIdentifier {
            case exampleNftIdentifier():
                nftID = ticket.ticketID
                break
            case exampleTokenIdentifier():
                foundFt = true
                break
        }
    }

    Test.assertEqual(id, nftID!)
    Test.assertEqual(true, foundFt)
}

access(all) fun testBorrowTicketsByType_Nft() {
    let acct = getNewAccount()
    let id = trySendNft(acct, revoke: true)

    let tickets = scriptExecutor("example-nft/borrow_all_tickets.cdc", [acct.address])! as! [LostAndFoundHelper.Ticket]
    Test.assertEqual(1, tickets.length)
    Test.assertEqual(id, tickets[0].ticketID!)
}

access(all) fun testBorrowTicketsByType_Ft() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount, revoke: true)

    let tickets = scriptExecutor("example-token/borrow_all_tickets.cdc", [acct.address])! as! [LostAndFoundHelper.Ticket]
    Test.assertEqual(1, tickets.length)
}

access(all) fun testCheckTicketItem() {
    let acct = getNewAccount()
    trySendNft(acct, revoke: true)
    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited

    let res = scriptExecutor("lost-and-found/check_ticket_item.cdc", [acct.address, e.ticketID, exampleNftIdentifier()])! as! Bool
    Test.assertEqual(true, res)
}

access(all) fun testGetTicketFungibleTokenBalance() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount, revoke: true)
    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited

    let balance = scriptExecutor("lost-and-found/get_ticket_ft_balance.cdc", [acct.address, e.ticketID, exampleTokenIdentifier()])! as! UFix64
    Test.assertEqual(amount, balance)
}

access(all) fun testGetShelfOwner() {
    let acct = getNewAccount()
    trySendNft(acct, revoke: true)

    let owner = scriptExecutor("lost-and-found/get_shelf_owner.cdc", [acct.address])! as! Address
    Test.assertEqual(lostAndFoundAccount.address, owner)
}

access(all) fun testShelfHasType() {
    let acct = getNewAccount()
    trySendNft(acct, revoke: true)
    let hasExampleNFT = scriptExecutor("lost-and-found/shelf_has_type.cdc", [acct.address, exampleNftIdentifier()])! as! Bool
    Test.assertEqual(true, hasExampleNFT)

    let hasExampleToken = scriptExecutor("lost-and-found/shelf_has_type.cdc", [acct.address, exampleTokenIdentifier()])! as! Bool
    Test.assertEqual(false, hasExampleToken)
}

access(all) fun testDepositor_DepositNft() {
    let acct = getNewAccount()

    mintAndSendNftWithDepositor(acct)

    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(e.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), e.type.identifier)
}

access(all) fun testDepositor_DepositFt() {
    let acct = getNewAccount()
    let amount = 5.0
    mintAndSendExampleTokensWithDepositor(acct, amount)

    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(e.redeemer, acct.address)
    Test.assertEqual(exampleTokenIdentifier(), e.type.identifier)
}

access(all) fun testDepositor_trySendNft_ValidCapability() {
    let acct = getNewAccount()
    setupExampleNft(acct: acct)

    let nftID = trySendNftWithDepositor(acct, revoke: false)

    let e = Test.eventsOfType(Type<ExampleNFT.Deposit>()).removeLast() as! ExampleNFT.Deposit
    Test.assertEqual(acct.address, e.to!)
    Test.assertEqual(nftID, e.id)
}

access(all) fun testDepositor_trySendNft_InvalidCapability() {
    let acct = getNewAccount()

    let nftID = trySendNftWithDepositor(acct, revoke: true)

    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(acct.address, e.redeemer)
    Test.assertEqual(exampleNftIdentifier(), e.type.identifier)
}

access(all) fun testDepositor_trySendFt_ValidCapability() {
    let acct = getNewAccount()
    setupExampleToken(acct: acct)
    let amount = 5.0

    trySendFtWithDepositor(acct, amount, revoke: false)
    
    let e = Test.eventsOfType(Type<ExampleToken.TokensDeposited>()).removeLast() as! ExampleToken.TokensDeposited
    Test.assertEqual(acct.address, e.to!)
    Test.assertEqual(amount, e.amount)
}

access(all) fun testDepositor_trySendFt_InvalidCapability() {
    let acct = getNewAccount()
    let amount = 5.0

    trySendFtWithDepositor(acct, amount, revoke: true)

    let e = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(acct.address, e.redeemer)
    Test.assertEqual(exampleTokenIdentifier(), e.type.identifier)
}

access(all) fun mintAndSendNft(_ acct: Test.TestAccount): UInt64 {
    txExecutor("example-nft/mint_and_deposit_example_nft.cdc", [exampleNftAccount, acct], [acct.address])
    let e = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return e.id
}

access(all) fun trySendNft(_ acct: Test.TestAccount, revoke: Bool): UInt64 {
    txExecutor("example-nft/try_send_example_nft.cdc", [exampleNftAccount, acct], [acct.address, revoke])
    let e = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return e.id
}

access(all) fun trySendFt(_ acct: Test.TestAccount, _ amount: UFix64, revoke: Bool) {
    txExecutor("example-token/try_send_example_token.cdc", [exampleTokenAccount, acct], [acct.address, amount, revoke])
}

access(all) fun mintAndSendNftWithDepositor(_ to: Test.TestAccount): UInt64 {
txExecutor("example-nft/mint_and_deposit_with_depositor.cdc", [exampleNftAccount], [to.address])
    let e = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return e.id
}

access(all) fun mintAndSendExampleTokensWithDepositor(_ to: Test.TestAccount, _ amount: UFix64) {
    txExecutor("example-token/deposit_example_token_with_depositor.cdc", [exampleTokenAccount], [to.address, amount])
}

access(all) fun trySendNftWithDepositor(_ to: Test.TestAccount, revoke: Bool): UInt64 {
    txExecutor("example-nft/try_send_example_nft_with_depositor.cdc", [exampleNftAccount, to], [to.address, revoke])
    let e = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return e.id
}

access(all) fun trySendFtWithDepositor(_ to: Test.TestAccount, _ amount: UFix64, revoke: Bool) {
    txExecutor("example-token/try_send_example_token_depositor.cdc", [exampleTokenAccount, to], [to.address, amount, revoke])
}