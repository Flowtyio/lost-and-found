import Test

pub fun scriptExecutor(_ scriptName: String, _ arguments: [AnyStruct]): AnyStruct? {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = Test.executeScript(scriptCode, arguments)
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
}

pub fun deploy(_ name: String, _ path: String, _ arguments: [AnyStruct]) {
    let err = Test.deployContract(name: name, path: path, arguments: arguments)
    Test.expect(err, Test.beNil()) 
}

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