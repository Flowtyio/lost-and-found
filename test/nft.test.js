import {
    getContractAddress,
    executeScript,
    sendTransaction
} from "flow-js-testing";
import {after, alice, before, ExampleNFT} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

// TODO: test for NonFungibleToken.Receiver being used instead of CollectionPublic
describe("lost-and-found NonFungibleToken tests", () => {
    const depositExampleNFT = async (account) => {
        const exampleNFTAddress = await getContractAddress("ExampleNFT")

        const args = [account]
        const signers = [exampleNFTAddress]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_example_nft", args, signers});
        return [tx, err]
    }

    beforeEach(before);

    afterEach(after);

    test("deposit ExampleNFT", async () => {
        const exampleNFTAddress = await getContractAddress("ExampleNFT")

        const args = [alice]
        const signers = [exampleNFTAddress]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_example_nft", args, signers});
        expect(err).toBe(null)

        let result
        [result, err] = await executeScript("get_redeemable_types_for_addr", [alice])
        expect(result.length).toBe(1)
        expect(result[0]).toBe('A.179b6b1cb6755e31.ExampleNFT.NFT')
    })

    test("redeem ExampleNFT", async () => {
        await depositExampleNFT(alice)
        const signers = [alice]
        let [tx, redeemErr] = await sendTransaction({name: "ExampleNFT/redeem_example_nft_all", args: [], signers})
        expect(redeemErr).toBe(null)
        let [result, err] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(result.length).toBe(1)
        expect(err).toBe(null)
    })
})
 