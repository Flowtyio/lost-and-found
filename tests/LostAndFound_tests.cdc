import Test
import "test_helpers.cdc"

import "LostAndFound"
import "LostAndFoundHelper"
import "ExampleNFT"
import "ExampleToken"

pub fun setup() {
    deployAll()

    mintFlow(exampleNftAccount, 10.0)
    mintFlow(exampleTokenAccount, 10.0)

    txExecutor("depositor/setup_depositor.cdc", [exampleNftAccount], [lowBalanceThreshold])
    txExecutor("depositor/add_flow_tokens.cdc", [exampleNftAccount], [lowBalanceThreshold])

    txExecutor("depositor/setup_depositor.cdc", [exampleTokenAccount], [lowBalanceThreshold])
    txExecutor("depositor/add_flow_tokens.cdc", [exampleTokenAccount], [lowBalanceThreshold])
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

pub fun testBorrowAllTickets() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount)
    let id = trySendNft(acct)

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

pub fun testBorrowTicketsByType_Nft() {
    let acct = getNewAccount()
    let id = trySendNft(acct)

    let tickets = scriptExecutor("example-nft/borrow_all_tickets.cdc", [acct.address])! as! [LostAndFoundHelper.Ticket]
    Test.assertEqual(1, tickets.length)
    Test.assertEqual(id, tickets[0].ticketID!)
}

pub fun testBorrowTicketsByType_Ft() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount)

    let tickets = scriptExecutor("example-token/borrow_all_tickets.cdc", [acct.address])! as! [LostAndFoundHelper.Ticket]
    Test.assertEqual(1, tickets.length)
}

pub fun testCheckTicketItem() {
    let acct = getNewAccount()
    trySendNft(acct)
    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited

    let res = scriptExecutor("lost-and-found/check_ticket_item.cdc", [acct.address, event.ticketID, exampleNftIdentifier()])! as! Bool
    Test.assertEqual(true, res)
}

pub fun testGetTicketFungibleTokenBalance() {
    let acct = getNewAccount()
    let amount = 5.0
    trySendFt(acct, amount)
    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited

    let balance = scriptExecutor("lost-and-found/get_ticket_ft_balance.cdc", [acct.address, event.ticketID, exampleTokenIdentifier()])! as! UFix64
    Test.assertEqual(amount, balance)
}

pub fun testGetShelfOwner() {
    let acct = getNewAccount()
    trySendNft(acct)

    let owner = scriptExecutor("lost-and-found/get_shelf_owner.cdc", [acct.address])! as! Address
    Test.assertEqual(lostAndFoundAccount.address, owner)
}

pub fun testShelfHasType() {
    let acct = getNewAccount()
    trySendNft(acct)
    let hasExampleNFT = scriptExecutor("lost-and-found/shelf_has_type.cdc", [acct.address, exampleNftIdentifier()])! as! Bool
    Test.assertEqual(true, hasExampleNFT)

    let hasExampleToken = scriptExecutor("lost-and-found/shelf_has_type.cdc", [acct.address, exampleTokenIdentifier()])! as! Bool
    Test.assertEqual(false, hasExampleToken)
}

pub fun testDepositor_DepositNft() {
    let acct = getNewAccount()

    mintAndSendNftWithDepositor(acct)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(event.redeemer, acct.address)
    Test.assertEqual(exampleNftIdentifier(), event.type.identifier)
}

pub fun testDepositor_DepositFt() {
    let acct = getNewAccount()
    let amount = 5.0
    mintAndSendExampleTokensWithDepositor(acct, amount)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(event.redeemer, acct.address)
    Test.assertEqual(exampleTokenIdentifier(), event.type.identifier)
}

pub fun testDepositor_trySendNft_ValidCapability() {
    let acct = getNewAccount()
    setupExampleNft(acct: acct)

    let nftID = trySendNftWithDepositor(acct)

    let event = Test.eventsOfType(Type<ExampleNFT.Deposit>()).removeLast() as! ExampleNFT.Deposit
    Test.assertEqual(acct.address, event.to!)
    Test.assertEqual(nftID, event.id)
}

pub fun testDepositor_trySendNft_InvalidCapability() {
    let acct = getNewAccount()

    let nftID = trySendNftWithDepositor(acct)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(acct.address, event.redeemer)
    Test.assertEqual(exampleNftIdentifier(), event.type.identifier)
}

pub fun testDepositor_trySendFt_ValidCapability() {
    let acct = getNewAccount()
    setupExampleToken(acct: acct)
    let amount = 5.0

    trySendFtWithDepositor(acct, amount)
    
    let event = Test.eventsOfType(Type<ExampleToken.TokensDeposited>()).removeLast() as! ExampleToken.TokensDeposited
    Test.assertEqual(acct.address, event.to!)
    Test.assertEqual(amount, event.amount)
}

pub fun testDepositor_trySendFt_InvalidCapability() {
    let acct = getNewAccount()
    let amount = 5.0

    trySendFtWithDepositor(acct, amount)

    let event = Test.eventsOfType(Type<LostAndFound.TicketDeposited>()).removeLast() as! LostAndFound.TicketDeposited
    Test.assertEqual(acct.address, event.redeemer)
    Test.assertEqual(exampleTokenIdentifier(), event.type.identifier)
}

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

pub fun mintAndSendNftWithDepositor(_ to: Test.Account): UInt64 {
    txExecutor("example-nft/mint_and_deposit_with_depositor.cdc", [exampleNftAccount], [to.address])
    let event = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return event.id
}

pub fun mintAndSendExampleTokensWithDepositor(_ to: Test.Account, _ amount: UFix64) {
    txExecutor("example-token/deposit_example_token_with_depositor.cdc", [exampleTokenAccount], [to.address, amount])
}

pub fun trySendNftWithDepositor(_ to: Test.Account): UInt64 {
    txExecutor("example-nft/try_send_example_nft_with_depositor.cdc", [exampleNftAccount], [to.address])
    let event = Test.eventsOfType(Type<ExampleNFT.Mint>()).removeLast() as! ExampleNFT.Mint

    return event.id
}

pub fun trySendFtWithDepositor(_ to: Test.Account, _ amount: UFix64) {
    txExecutor("example-token/try_send_example_token_depositor.cdc", [exampleTokenAccount], [to.address, amount])
}