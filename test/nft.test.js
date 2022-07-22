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
jest.setTimeout(100000);

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

    it("deposit ExampleNFT", async () => {
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

    it("redeem ExampleNFT", async () => {
        await depositExampleNFT(alice)
        const signers = [alice]
        let [tx, redeemErr] = await sendTransaction({
            name: "ExampleNFT/redeem_example_nft_all",
            args: [],
            signers,
            limit: 9999
        })
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

    it("send ExampleNFT with setup", async () => {
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

    it("send ExampleNFT without setup", async () => {
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
        expect(event.data.name).toBe("testname")
        expect(event.data.description).toBe("descr")
        expect(event.data.thumbnail).toBe("image.html")
    })

    it("borrow all ExampleNFT tickets", async () => {
        await cleanup(alice)

        const [mint1, mint1Err] = await depositExampleNFT(alice)
        const [mint2, mint2Err] = await depositExampleNFT(alice)
        const [mint3, mint3Err] = await depositExampleNFT(alice)

        const depositEvent1 = getEventFromTransaction(mint1, `A.${lostAndFoundAdmin.substring(2)}.LostAndFound.TicketDeposited`)
        const depositEvent2 = getEventFromTransaction(mint2, `A.${lostAndFoundAdmin.substring(2)}.LostAndFound.TicketDeposited`)
        const depositEvent3 = getEventFromTransaction(mint3, `A.${lostAndFoundAdmin.substring(2)}.LostAndFound.TicketDeposited`)

        const ticket1 = depositEvent1.data.ticketID
        const ticket2 = depositEvent2.data.ticketID
        const ticket3 = depositEvent3.data.ticketID

        const [res, err] = await executeScript("ExampleNFT/borrow_all_tickets", [alice])
        expect(err).toBe(null)
        expect(res.length).toBe(3)

        let [found1, found2, found3] = [false, false, false]
        res.forEach(val => {
            switch (val.uuid) {
                case ticket1:
                    expect(found1).toBe(false)
                    found1 = true
                    break
                case ticket2:
                    expect(found2).toBe(false)
                    found2 = true
                    break
                case ticket3:
                    expect(found3).toBe(false)
                    found3 = true
                    break
                default:
                    throw Error("should never reach this")
            }
        })

        expect(found1).toBe(true)
        expect(found2).toBe(true)
        expect(found3).toBe(true)
    })

    it("should return all storage fees after redemption", async () => {
        await cleanup(alice)
        await sendTransaction({
            name: "ExampleToken/destroy_example_token_storage",
            signers: [alice],
            args: [],
            limit: 9999
        })

        let [beforeBalance, bErr] = await executeScript("FlowToken/get_flow_token_balance", [exampleNFTAdmin])
        expect(bErr).toBe(null)

        for (let i = 0; i < 10; i++) {
            let [sendRes, sendErr] = await sendTransaction({
                name: "ExampleNFT/try_send_multiple_example_nft",
                args: [alice, 10],
                signers: [exampleNFTAdmin],
                limit: 9999
            })
            if(sendErr !== null) {break}
        }

        let [balance, balanceErr] = await executeScript("FlowToken/get_flow_token_balance", [exampleNFTAdmin])
        expect(balanceErr).toBe(null)

        let [tx, redeemErr] = await sendTransaction({
            name: "ExampleNFT/redeem_example_nft_all",
            args: [],
            signers: [alice],
            limit: 9999
        })
        expect(redeemErr).toBe(null)

        let [afterBalance, aErr] = await executeScript("FlowToken/get_flow_token_balance", [exampleNFTAdmin])
        expect(aErr).toBe(null)
        expect(beforeBalance).toBe(afterBalance)
    })
})
