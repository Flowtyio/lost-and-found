import path from "path";
import {deployContractByName, emulator, getAccountAddress, init} from "flow-js-testing";

export const ExampleNFT = "ExampleNFTDeployer"
export const ExampleToken = "ExampleTokenDeployer"
export let alice, exampleNFTAdmin, exampleTokenAdmin

export const setup = async () => {
    const basePath = path.resolve(__dirname, "../cadence");
    const port = 8080;
    const logging = false;

    await init(basePath, {port});
    await emulator.start(port, logging);

    alice = await getAccountAddress("Alice")
    exampleNFTAdmin = await getAccountAddress(ExampleNFT)
    exampleTokenAdmin = await getAccountAddress(ExampleToken)

    await deployContractByName({name: "NonFungibleToken", update: true});
    await deployContractByName({name: "MetadataViews", update: true});
    await deployContractByName({name: "ExampleNFT", to: exampleNFTAdmin, update: true})
    await deployContractByName({name: "LostAndFound", update: true});
    await deployContractByName({name: "ExampleToken", to: exampleTokenAdmin, update: true})
}

export const before = async () => {
    await setup()
}

export const after = async () => {
    await emulator.stop()
}