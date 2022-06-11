import path from "path";
import {deployContractByName, emulator, executeScript, getAccountAddress, init, mintFlow} from "flow-js-testing";

export const ExampleNFT = "ExampleNFTDeployer"
export const ExampleToken = "ExampleTokenDeployer"
export const LostAndFound = "LostAndFound"

export let alice, exampleNFTAdmin, exampleTokenAdmin, lostAndFoundAdmin

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

    console.log(await deployContractByName({name: "NonFungibleToken", update: true}))
    console.log(await deployContractByName({name: "MetadataViews", update: true}))
    console.log(await deployContractByName({name: "ExampleNFT", to: exampleNFTAdmin, update: true}))
    console.log(await deployContractByName({name: "LostAndFound", to: lostAndFoundAdmin, update: true}))
    console.log(await deployContractByName({name: "ExampleToken", to: exampleTokenAdmin, update: true}))
    console.log('addresses', {alice, exampleNFTAdmin, exampleTokenAdmin, lostAndFoundAdmin})
}

export const before = async () => {
    await setup()
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
