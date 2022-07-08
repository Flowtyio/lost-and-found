import {
    getContractAddress,
    executeScript,
    sendTransaction
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
            if (val.typeID === `A.${exampleNFTAdmin.substring(2)}.ExampleNFT.NFT`) {
                found = true
            }
        })
        expect(found).toBe(false)
    })

    test("send ExampleNFT with setup", async () => {
        await cleanup(alice)
        let [setupRes, setupErr] = await sendTransaction({
            name: "ExampleNFT/setup_account_example_nft",
            args: [],
            signers: [alice],
            limit: 999
        })
        expect(setupErr).toBe(null)

        let [ids, idsErr] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(idsErr).toBe(null)
        expect(ids.length).toBe(0)

        const [sendRes, sendErr] = await sendTransaction({
            name: "ExampleNFT/try_send_example_nft",
            args: [alice],
            signers: [exampleNFTAdmin],
            limit: 9999
        })
        const eventType = `A.${exampleNFTAdmin.substring(2)}.ExampleNFT.Deposit`
        const event = getEventFromTransaction(sendRes, eventType)
        expect(sendErr).toBe(null)
        expect(event.type).toBe(eventType)
        expect(event.data.to).toBe(alice)

        let [idsAfter, idsAfterErr] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(idsAfterErr).toBe(null)
        expect(idsAfter.length).toBe(1)
    })

    test("send ExampleNFT without setup", async () => {
        await cleanup(alice)
        let [_, idsErr] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(idsErr.message.includes("unexpectedly found nil while forcing an Optional value")).toBe(true)

        let [sendRes, sendErr] = await sendTransaction({
            name: "ExampleNFT/try_send_example_nft",
            args: [alice],
            signers: [exampleNFTAdmin],
            limit: 9999
        })
        const eventType = `A.${lostAndFoundAdmin.substring(2)}.LostAndFound.TicketDeposited`
        const event = getEventFromTransaction(sendRes, eventType)
        expect(sendErr).toBe(null)
        expect(event.type).toBe(eventType)
        expect(event.data.redeemer).toBe(alice)
        expect(event.data.type.typeID).toBe(`A.${exampleNFTAdmin.substring(2)}.ExampleNFT.NFT`)
    })
})
