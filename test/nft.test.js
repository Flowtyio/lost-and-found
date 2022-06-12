import {
    getContractAddress,
    executeScript,
    sendTransaction
} from "flow-js-testing";
import {after, alice, before, delay, ExampleNFT} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

// TODO: test for NonFungibleToken.Receiver being used instead of CollectionPublic
describe("lost-and-found NonFungibleToken tests", () => {
    beforeEach(async () => {
        await before()
    });

    // Stop emulator, so it could be restarted
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

    test("deposit ExampleNFT", async () => {
        const exampleNFTAddress = await getContractAddress("ExampleNFT")

        await delay(1000)
        const args = [alice]
        const signers = [exampleNFTAddress]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_example_nft", args, signers});
        expect(err).toBe(null)

        const [redeemableTypes, redeemableTypesErr] = await executeScript("get_redeemable_types_for_addr", [alice])
        expect(redeemableTypesErr).toBe(null)
        let found = false
        redeemableTypes.forEach(val => {
            if (val.typeID === `A.${exampleNFTAddress.substring(2)}.ExampleNFT.NFT`) {
                found = true
            }
        })
        expect(found).toBe(true)
    })

    test("redeem ExampleNFT", async () => {
        await depositExampleNFT(alice)
        const signers = [alice]
        let [tx, redeemErr] = await sendTransaction({name: "ExampleNFT/redeem_example_nft_all", args: [], signers, limit: 9999})
        expect(redeemErr).toBe(null)
        let [result, err] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(result.length).toBe(1)
        expect(err).toBe(null)

        const [redeemableTypes, redeemableTypesErr] = await executeScript("get_redeemable_types_for_addr", [alice])
        expect(redeemableTypesErr).toBe(null)
        let found = false
        redeemableTypes.forEach(val => {
            if (val.typeID === `A.${exampleNFTAddress.substring(2)}.ExampleNFT.NFT`) {
                found = true
            }
        })
        expect(found).toBe(false)
    })
})
