import {
    getContractAddress,
    executeScript,
    sendTransaction, getAccountAddress, mintFlow
} from "flow-js-testing";
import {
    after,
    alice,
    before,
    cleanup,
    delay,
    ExampleNFT,
    exampleNFTAdmin,
    exampleTokenAdmin, getEventFromTransaction,
    lostAndFoundAdmin
} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

// TODO: test for NonFungibleToken.Receiver being used instead of CollectionPublic
describe("lost-and-found NonFungibleToken tests", () => {
    beforeEach(async () => {
        await before()
    });

    afterEach(async () => {
        await after()
    });

    const depositExampleNFT = async (account) => {
        const exampleNFTAddress = await getContractAddress("ExampleNFT")

        const args = [account]
        const signers = [exampleNFTAddress]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_example_nft", args, signers});
        return [tx, err]
    }
})
