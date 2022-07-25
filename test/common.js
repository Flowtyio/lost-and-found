import path from "path";
import {
    deployContractByName,
    emulator,
    executeScript,
    getAccountAddress,
    init,
    mintFlow,
    sendTransaction,
} from "flow-js-testing";


export const ExampleNFT = "ExampleNFTDeployer"
export const ExampleToken = "ExampleTokenDeployer"
export const LostAndFound = "LostAndFound"

export let alice, exampleNFTAdmin, exampleTokenAdmin, lostAndFoundAdmin

export const cleanup = async (account) => {
    const [clearTx, clearTxErr] = await sendTransaction({name: "clear_all_tickets", args: [], signers: [account], limit: 9999})
    expect(clearTxErr).toBe(null)
    const [destroyFT, destroyFTErr] = await sendTransaction({name: "ExampleToken/destroy_example_token_storage", args: [], signers: [account], limit: 9999})
    expect(destroyFTErr).toBe(null)
    const [destroyNFT, destroyNFTErr] = await sendTransaction({name: "ExampleNFT/destroy_example_nft_storage", args: [], signers: [account], limit: 9999})
    expect(destroyNFTErr).toBe(null)
}

export const setup = async () => {
    const basePath = path.resolve(__dirname, "../cadence");
    const port = 8080;
    const logging = false;

    await init(basePath, {port});
    await emulator.start(port, logging);

    alice = await getAccountAddress("Alice")
    exampleNFTAdmin = await getAccountAddress(ExampleNFT)
    exampleTokenAdmin = await getAccountAddress(ExampleToken)
    lostAndFoundAdmin = await getAccountAddress(LostAndFound)

    await deployContractByName({name: "NonFungibleToken", update: true})
    await deployContractByName({name: "MetadataViews", update: true})
    await deployContractByName({name: "ExampleNFT", to: exampleNFTAdmin, update: true})
    await deployContractByName({name: "LostAndFound", to: lostAndFoundAdmin, update: true})
    await deployContractByName({name: "ExampleToken", to: exampleTokenAdmin, update: true})
}

export const before = async () => {
    await setup()
    await cleanup(alice)

    await mintFlow(alice, 1.0)
    await mintFlow(exampleNFTAdmin, 1.0)
    await mintFlow(exampleTokenAdmin, 1.0)
    await mintFlow(lostAndFoundAdmin, 1.0)
}

export const after = async () => {
    await emulator.stop()
}

export const getRedeemableTypes = async (account) => {
    return await executeScript("get_redeemable_types_for_addr", [account])
}

export const delay = (ms) =>
    new Promise(resolve => {
        setTimeout(resolve, ms)
    })

export const getEventFromTransaction = (txRes, eventType, throwError = true) => {
    for(let i = 0; i < txRes.events.length; i++) {
        if(txRes.events[i].type === eventType) {
            return txRes.events[i]
        }
    }
    if (throwError) {
        throw Error("did not find event in transaction")
    }
}

export const composeCadenceTypeIdentifier = (addressWithOrWithoutPrefix, contractName, typeName) => {
    const address = addressWithOrWithoutPrefix.startsWith('0x') ? addressWithOrWithoutPrefix.slice(2) : addressWithOrWithoutPrefix
    return `A.${address}.${contractName}.${typeName}`
}

export const cadenceTypeIdentifierGenerator = (addressWithOrWithoutPrefix, contractName) => {
    return (typeName) => composeCadenceTypeIdentifier(addressWithOrWithoutPrefix, contractName, typeName)
}

export const cadenceContractTypeIdentifierGenerator = (addressWithOrWithoutPrefix) => {
    return (contractName) => cadenceTypeIdentifierGenerator(addressWithOrWithoutPrefix, contractName)
}