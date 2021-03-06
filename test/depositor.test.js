import {
    executeScript,
    sendTransaction,
    mintFlow
} from "flow-js-testing";
import {
    after,
    alice,
    before,
    cleanup,
    delay,
    ExampleNFT,
    exampleNFTAdmin,
    exampleTokenAdmin, getEventFromTransaction, LostAndFound,
    lostAndFoundAdmin
} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("lost-and-found NonFungibleToken tests", () => {
    beforeEach(async () => {
        await before()
    });

    afterEach(async () => {
        await after()
        await destroyDepositor(ExampleNFT)
    });

    const setupDepositor = async (account) => {
        return await sendTransaction({name: "Depositor/setup", args: [], signers: [account]})
    }

    const addFlowTokensToDepositor = async (account, amount) => {
        return await sendTransaction({name: "Depositor/add_flow_tokens", args: [amount], signers: [account]})
    }

    const destroyDepositor = async (account) => {
        return await sendTransaction({name: "Depositor/destroy", args: [], signers: [account]})
    }

    const getBalance = async (account) => {
        return await executeScript("Depositor/get_balance", [account])
    }

    const ensureDepositorSetup = async (account) => {
        await destroyDepositor(account)
        const [tx, err] = await setupDepositor(account)
        expect(err).toBe(null)
        expect(tx.events[0].type).toBe(`A.${lostAndFoundAdmin.substring(2)}.LostAndFound.DepositorCreated`)
    }


    it("should initialize a depositor", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)

        const [balance, balanceErr] = await getBalance(exampleNFTAdmin)
        expect(balanceErr).toBe(null)
        expect(Number(balance)).toBe(0)
    })

    it("should update Depositor balance", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const [balanceBeforeRes, balanceBeforeErr] = await getBalance(exampleNFTAdmin)
        expect(balanceBeforeErr).toBe(null)
        const balanceBefore = Number(balanceBeforeRes)

        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await sendTransaction({name: "Depositor/add_flow_tokens", args: [mintAmount], signers: [exampleNFTAdmin]})

        const [balanceAfterRes, balanceAfterErr] = await getBalance(exampleNFTAdmin)
        expect(balanceAfterErr).toBe(null)
        const balanceAfter = Number(balanceAfterRes)

        expect(balanceAfter - balanceBefore).toBe(mintAmount)
    })

    it("should update Depositor balance from public account", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const [balanceBeforeRes, balanceBeforeErr] = await getBalance(exampleNFTAdmin)
        expect(balanceBeforeErr).toBe(null)
        const balanceBefore = Number(balanceBeforeRes)

        const mintAmount = 100
        await mintFlow(alice, mintAmount)
        await sendTransaction({name: "Depositor/add_flow_tokens_public", args: [exampleNFTAdmin, mintAmount], signers: [alice]})

        const [balanceAfterRes, balanceAfterErr] = await getBalance(exampleNFTAdmin)
        expect(balanceAfterErr).toBe(null)
        const balanceAfter = Number(balanceAfterRes)

        expect(balanceAfter - balanceBefore).toBe(mintAmount)
    })

    it("should deposit to LostAndFound through the Depositor", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await sendTransaction({name: "Depositor/add_flow_tokens", args: [mintAmount], signers: [exampleNFTAdmin]})

        const args = [alice]
        const signers = [exampleNFTAdmin]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_with_depositor", args, signers});
        expect(err).toBe(null)

        const depositorWithdrawEvent = getEventFromTransaction(tx, `A.${lostAndFoundAdmin.substring(2)}.LostAndFound.DepositorTokensWithdrawn`)
        const tokens = Number(depositorWithdrawEvent.data.tokens)
        const balance = Number(depositorWithdrawEvent.data.balance)
        expect(tokens + balance).toBe(mintAmount)

        const depositEvent = getEventFromTransaction(tx, `A.${lostAndFoundAdmin.substring(2)}.LostAndFound.TicketDeposited`)
        expect(depositEvent.data.type.typeID).toBe(`A.${exampleNFTAdmin.substring(2)}.ExampleNFT.NFT`)
        expect(depositEvent.data.redeemer).toBe(alice)
    })


    it("send ExampleNFT with setup", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await sendTransaction({name: "Depositor/add_flow_tokens", args: [mintAmount], signers: [exampleNFTAdmin]})

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
            name: "ExampleNFT/try_send_example_nft_with_depositor",
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
})
