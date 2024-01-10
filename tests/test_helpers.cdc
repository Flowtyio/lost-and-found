import Test

import "ExampleNFT"
import "ExampleToken"

access(all) let lowBalanceThreshold = 1.0

// the cadence testing framework allocates 4 addresses for system acounts,
// and 10 pre-created accounts for us to use for deployments:
access(all) let Account0x1 = Address(0x0000000000000001)
access(all) let Account0x2 = Address(0x0000000000000002)
access(all) let Account0x3 = Address(0x0000000000000003)
access(all) let Account0x4 = Address(0x0000000000000004)
access(all) let Account0x5 = Address(0x0000000000000005)
access(all) let Account0x6 = Address(0x0000000000000006)
access(all) let Account0x7 = Address(0x0000000000000007)
access(all) let Account0x8 = Address(0x0000000000000008)
access(all) let Account0x9 = Address(0x0000000000000009)
access(all) let Account0xa = Address(0x000000000000000a)
access(all) let Account0xb = Address(0x000000000000000b)
access(all) let Account0xc = Address(0x000000000000000c)
access(all) let Account0xd = Address(0x000000000000000d)
access(all) let Account0xe = Address(0x000000000000000e)

access(all) let lostAndFoundAccount = Test.getAccount(Account0x5)
access(all) let exampleNftAccount = Test.getAccount(Account0x6)
access(all) let exampleTokenAccount = Test.getAccount(Account0x7)

access(all) fun scriptExecutor(_ scriptName: String, _ arguments: [AnyStruct]): AnyStruct? {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = Test.executeScript(scriptCode, arguments)

    if scriptResult.error != nil {
        panic(scriptResult.error!.message)
    }

    return scriptResult.returnValue
}

access(all) fun txExecutor(_ txName: String, _ signers: [Test.TestAccount], _ arguments: [AnyStruct]): Test.TransactionResult {
    let txCode = loadCode(txName, "transactions")

    let authorizers: [Address] = []
    for signer in signers {
        authorizers.append(signer.address)
    }

    let tx = Test.Transaction(
        code: txCode,
        authorizers: authorizers,
        signers: signers,
        arguments: arguments,
    )

    let txResult = Test.executeTransaction(tx)
    if let err = txResult.error {
        panic(err.message)
    }

    return txResult
}

access(all) fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("../".concat(baseDirectory).concat("/").concat(fileName))
}

access(all) fun deployAll() {
    deploy("ExampleNFT", "../contracts/standard/ExampleNFT.cdc", [])
    deploy("ExampleToken", "../contracts/standard/ExampleToken.cdc", [])
    deploy("FeeEstimator", "../contracts/FeeEstimator.cdc", [])
    deploy("LostAndFound", "../contracts/LostAndFound.cdc", [])
    deploy("LostAndFoundHelper", "../contracts/LostAndFoundHelper.cdc", [])
}

access(all) fun deploy(_ name: String, _ path: String, _ arguments: [AnyStruct]) {
    let err = Test.deployContract(name: name, path: path, arguments: arguments)
    Test.expect(err, Test.beNil()) 
}

// Example NFT constants
access(all) let exampleNftStoragePath = /storage/exampleNFTCollection
access(all) let exampleNftPublicPath = /public/exampleNFTCollection
access(all) let exampleNftProviderPath = /private/exampleNFTCollection

// Example Token constants
access(all) let exampleTokenStoragePath = /storage/exampleTokenVault
access(all) let exampleTokenReceiverPath = /public/exampleTokenReceiver
access(all) let exampleTokenProviderPath = /private/exampleTokenProvider
access(all) let exampleTokenBalancePath = /public/exampleTokenBalance

access(all) fun exampleNftIdentifier(): String {
    return Type<@ExampleNFT.NFT>().identifier
}

access(all) fun exampleTokenIdentifier(): String {
    return Type<@ExampleToken.Vault>().identifier
}

access(all) fun getNewAccount(): Test.TestAccount {
    let acct = Test.createAccount()
    return acct
}

access(all) fun setupExampleToken(acct: Test.TestAccount) {
    txExecutor("example-token/setup.cdc", [acct], [])
}

access(all) fun setupExampleNft(acct: Test.TestAccount) {
    txExecutor("example-nft/setup.cdc", [acct], [])
}

access(all) fun mintExampleNfts(_ acct: Test.TestAccount, _ num: Int): [UInt64] {
    let txRes = txExecutor("example-nft/mint_example_nft.cdc", [exampleNftAccount], [acct.address, num])
    let events = Test.eventsOfType(Type<ExampleNFT.Deposit>())

    let ids: [UInt64] = []
    while ids.length < num {
        let e = events.removeLast() as! ExampleNFT.Deposit
        ids.append(e.id)
    }

    return ids
}

access(all) fun mintExampleNftByID(_ acct: Test.TestAccount, _ id: UInt64): UInt64 {
    post {
        result == id
    }

    let txRes = txExecutor("example-nft/mint_example_nft_with_id.cdc", [exampleNftAccount], [acct.address, id])
    let events = Test.eventsOfType(Type<ExampleNFT.Deposit>())
    let e = events.removeLast() as! ExampleNFT.Deposit
    return e.id
}

access(all) fun mintExampleTokens(_ acct: Test.TestAccount, _ amount: UFix64) {
    txExecutor("example-token/mint.cdc", [exampleTokenAccount], [acct.address, amount])
}

access(all) fun mintFlow(_ receiver: Test.TestAccount, _ amount: UFix64) {
    let code = loadCode("flow/mint_flow.cdc", "transactions")
    let tx = Test.Transaction(
        code: code,
        authorizers: [Test.serviceAccount().address],
        signers: [],
        arguments: [receiver.address, amount]
    )
    let txResult = Test.executeTransaction(tx)
    if txResult.error != nil {
        panic(txResult.error!.message)
    }
}

access(all) fun initializeDepositor(_ acct: Test.TestAccount) {
    txExecutor("depositor/setup_depositor.cdc", [acct], [lowBalanceThreshold])
    mintFlow(acct, lowBalanceThreshold + 1.0)
    txExecutor("depositor/add_flow_tokens.cdc", [acct], [lowBalanceThreshold])
}

access(all) fun initializeDepositorWithoutBalance(_ acct: Test.TestAccount) {
    txExecutor("depositor/setup_depositor.cdc", [acct], [lowBalanceThreshold])
}

access(all) fun getNewDepositor(): Test.TestAccount {
    let acct = getNewAccount()
    initializeDepositor(acct)
    return acct
}