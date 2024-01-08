import Test

import "ExampleNFT"
import "ExampleToken"

// the cadence testing framework allocates 4 addresses for system acounts,
// and 10 pre-created accounts for us to use for deployments:
pub let Account0x1 = Address(0x0000000000000001)
pub let Account0x2 = Address(0x0000000000000002)
pub let Account0x3 = Address(0x0000000000000003)
pub let Account0x4 = Address(0x0000000000000004)
pub let Account0x5 = Address(0x0000000000000005)
pub let Account0x6 = Address(0x0000000000000006)
pub let Account0x7 = Address(0x0000000000000007)
pub let Account0x8 = Address(0x0000000000000008)
pub let Account0x9 = Address(0x0000000000000009)
pub let Account0xa = Address(0x000000000000000a)
pub let Account0xb = Address(0x000000000000000b)
pub let Account0xc = Address(0x000000000000000c)
pub let Account0xd = Address(0x000000000000000d)
pub let Account0xe = Address(0x000000000000000e)

pub let lostAndFoundAccount = Test.getAccount(Account0x5)
pub let exampleNftAccount = Test.getAccount(Account0x6)
pub let exampleTokenAccount = Test.getAccount(Account0x7)

pub fun scriptExecutor(_ scriptName: String, _ arguments: [AnyStruct]): AnyStruct? {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = Test.executeScript(scriptCode, arguments)

    if scriptResult.error != nil {
        panic(scriptResult.error!.message)
    }

    return scriptResult.returnValue
}

pub fun txExecutor(_ txName: String, _ signers: [Test.Account], _ arguments: [AnyStruct]): Test.TransactionResult {
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

pub fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("../".concat(baseDirectory).concat("/").concat(fileName))
}

pub fun deployAll() {
    deploy("ExampleNFT", "../contracts/standard/ExampleNFT.cdc", [])
    deploy("ExampleToken", "../contracts/standard/ExampleToken.cdc", [])
    deploy("FeeEstimator", "../contracts/FeeEstimator.cdc", [])
    deploy("LostAndFound", "../contracts/LostAndFound.cdc", [])

    mintFlow(exampleNftAccount, 10.0)
    mintFlow(exampleTokenAccount, 10.0)
}

pub fun deploy(_ name: String, _ path: String, _ arguments: [AnyStruct]) {
    let err = Test.deployContract(name: name, path: path, arguments: arguments)
    Test.expect(err, Test.beNil()) 
}

// Example NFT constants
pub let exampleNftStoragePath = /storage/exampleNFTCollection
pub let exampleNftPublicPath = /public/exampleNFTCollection
pub let exampleNftProviderPath = /private/exampleNFTCollection

// Example Token constants
pub let exampleTokenStoragePath = /storage/exampleTokenVault
pub let exampleTokenReceiverPath = /public/exampleTokenReceiver
pub let exampleTokenProviderPath = /private/exampleTokenProvider
pub let exampleTokenBalancePath = /public/exampleTokenBalance

pub fun exampleNftIdentifier(): String {
    return Type<@ExampleNFT.NFT>().identifier
}

pub fun exampleTokenIdentifier(): String {
    return Type<@ExampleToken.Vault>().identifier
}

pub fun getNewAccount(): Test.Account {
    let acct = Test.createAccount()
    return acct
}

pub fun setupExampleToken(acct: Test.Account) {
    txExecutor("example-token/setup.cdc", [acct], [])
}

pub fun setupExampleNft(acct: Test.Account) {
    txExecutor("example-nft/setup.cdc", [acct], [])
}

pub fun mintExampleNfts(_ acct: Test.Account, _ num: Int): [UInt64] {
    let txRes = txExecutor("example-nft/mint_example_nft.cdc", [exampleNftAccount], [acct.address, num])
    let events = Test.eventsOfType(Type<ExampleNFT.Deposit>())

    let ids: [UInt64] = []
    while ids.length < num {
        let event = events.removeLast() as! ExampleNFT.Deposit
        ids.append(event.id)
    }

    return ids
}

pub fun mintExampleNftByID(_ acct: Test.Account, _ id: UInt64): UInt64 {
    post {
        result == id
    }

    let txRes = txExecutor("example-nft/mint_example_nft_with_id.cdc", [exampleNftAccount], [acct.address, id])
    let events = Test.eventsOfType(Type<ExampleNFT.Deposit>())
    let event = events.removeLast() as! ExampleNFT.Deposit
    return event.id
}

pub fun mintExampleTokens(_ acct: Test.Account, _ amount: UFix64) {
    txExecutor("example-token/mint.cdc", [exampleTokenAccount], [acct.address, amount])
}

pub fun mintFlow(_ receiver: Test.Account, _ amount: UFix64) {
    let code = Test.readFile("../transactions/flow/mint_flow.cdc    ")
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