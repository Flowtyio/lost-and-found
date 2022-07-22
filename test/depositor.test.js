import {
    executeScript,
    sendTransaction,
    mintFlow
} from "flow-js-testing";
import {
    after,
    alice,
    before,
    cadenceTypeIdentifierGenerator,
    cleanup,
    ExampleNFT,
    exampleNFTAdmin,
    getEventFromTransaction,
    lostAndFoundAdmin,
} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("lost-and-found Depositor tests", () => {
    let composeLostAndFoundTypeIdentifier, composeExampleNFTTypeIdentifier

    beforeEach(async () => {
        await before()
        // addresses aren't initialized until here
        composeLostAndFoundTypeIdentifier = cadenceTypeIdentifierGenerator(lostAndFoundAdmin, "LostAndFound")
        composeExampleNFTTypeIdentifier = cadenceTypeIdentifierGenerator(exampleNFTAdmin, "ExampleNFT")
    });

    afterEach(async () => {
        await after()
        await destroyDepositor(ExampleNFT)
    });

    const setupDepositor = (account, lowBalanceThreshold) => {
        return sendTransaction({name: "Depositor/setup", args: [lowBalanceThreshold], signers: [account]})
    }

    const addFlowTokensToDepositor = (account, amount) => {
        return sendTransaction({name: "Depositor/add_flow_tokens", args: [amount], signers: [account]})
    }

    const addFlowTokensToDepositorPublic = (account, amount, depositorOwnerAddr) => {
        return sendTransaction({name: "Depositor/add_flow_tokens_public", args: [depositorOwnerAddr, amount], signers: [account]})
    }

    const withdrawFlowFromDepositor = (account, amount) => {
        return sendTransaction({name: "Depositor/withdraw_tokens", args: [amount], signers: [account]})
    }

    const destroyDepositor = (account) => {
        return sendTransaction({name: "Depositor/destroy", args: [], signers: [account]})
    }

    const getBalance = (account) => {
        return executeScript("Depositor/get_balance", [account])
    }

    const ensureDepositorSetup = async (account, lowBalanceThreshold = null) => {
        await destroyDepositor(account)
        const [tx, err] = await setupDepositor(account, lowBalanceThreshold)
        expect(err).toBe(null)
        expect(tx.events[0].type).toBe(composeLostAndFoundTypeIdentifier("DepositorCreated"))
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
        await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)

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
        await addFlowTokensToDepositorPublic(alice, mintAmount, exampleNFTAdmin)

        const [balanceAfterRes, balanceAfterErr] = await getBalance(exampleNFTAdmin)
        expect(balanceAfterErr).toBe(null)
        const balanceAfter = Number(balanceAfterRes)

        expect(balanceAfter - balanceBefore).toBe(mintAmount)
    })

    it("should deposit to LostAndFound through the Depositor", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)

        const args = [alice]
        const signers = [exampleNFTAdmin]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_with_depositor", args, signers});
        expect(err).toBe(null)

        const depositorWithdrawEvent = getEventFromTransaction(tx, composeLostAndFoundTypeIdentifier("DepositorTokensWithdrawn"))
        const tokens = Number(depositorWithdrawEvent.data.tokens)
        const balance = Number(depositorWithdrawEvent.data.balance)
        expect(tokens + balance).toBe(mintAmount)

        const depositEvent = getEventFromTransaction(tx, composeLostAndFoundTypeIdentifier("TicketDeposited"))
        expect(depositEvent.data.type.typeID).toBe(composeExampleNFTTypeIdentifier("NFT"))
        expect(depositEvent.data.redeemer).toBe(alice)
    })


    it("send ExampleNFT with setup", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)

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
        const eventType = composeExampleNFTTypeIdentifier("Deposit")
        const event = getEventFromTransaction(sendRes, eventType)
        expect(sendErr).toBe(null)
        expect(event.type).toBe(eventType)
        expect(event.data.to).toBe(alice)

        let [idsAfter, idsAfterErr] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(idsAfterErr).toBe(null)
        expect(idsAfter.length).toBe(1)
    })

    describe("DepositorBalanceLow event", () => {
        // NB this describe block of tests share state
        describe("expected emissions",  () => {
            it("emits on DEPOSIT if threshold is set and balance after withdraw is below it", async () => {
                const threshold = 100
                const mintAmount = threshold - 1
                await ensureDepositorSetup(exampleNFTAdmin, threshold)
                await mintFlow(exampleNFTAdmin, mintAmount)
                
                const [sendRes, sendErr] = await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)
                expect(sendErr).toBe(null)

                const balanceLowEvent = getEventFromTransaction(
                    sendRes,
                    composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
                )
                expect(balanceLowEvent).not.toBe(null)

                const {threshold: eventThreshold, balance} = balanceLowEvent.data
                expect(parseFloat(eventThreshold)).toEqual(threshold)
                expect(parseFloat(balance)).toEqual(mintAmount)
            })

            it("emits on WITHDRAW if threshold is set and balance after withdraw is below it", async () => {
                const withdrawAmount = 50
                const [sendRes, sendErr] = await withdrawFlowFromDepositor(exampleNFTAdmin, withdrawAmount)
                expect(sendErr).toBe(null)

                const balanceLowEvent = getEventFromTransaction(
                    sendRes,
                    composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
                )
                expect(balanceLowEvent).not.toBe(null)

                const {threshold, balance} = balanceLowEvent.data
                expect(parseFloat(threshold)).toEqual(100)
                expect(parseFloat(balance)).toEqual(49)
            })
        })

        // it("should not be emitted when no threshold is set", () => {})
        // it("should not be emitted when balance is not lower", () => {})
        // it("should have a configurable threshold", () => {})
    })
})
