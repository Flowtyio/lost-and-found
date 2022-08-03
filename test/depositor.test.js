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
    exampleNFTAdmin, getAccountBalances,
    getEventFromTransaction, getEventsFromTransaction,
    LostAndFound,
    lostAndFoundAdmin
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

    const triggerLowThresholdEvent = async (account, threshold) => {
        return sendTransaction({name: "Depositor/withdraw_below_threshold", args: [threshold], signers: [account]})
    }

    const withdrawToThreshold = async (account, threshold) => {
        return sendTransaction({name: "Depositor/withdraw_to_threshold", args: [threshold], signers: [account]})
    }

    const setLowBalanceThreshold = (account, newThreshold) => {
        return sendTransaction({name: "Depositor/set_threshold", args: [newThreshold], signers: [account]})
    }

    const destroyDepositor = (account) => {
        return sendTransaction({name: "Depositor/destroy", args: [], signers: [account]})
    }

    const getDepositorBalance = (account) => {
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

        const [balance, balanceErr] = await getDepositorBalance(exampleNFTAdmin)
        expect(balanceErr).toBe(null)
        expect(Number(balance)).toBe(0)
    })

    it("should update Depositor balance", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const [balanceBeforeRes, balanceBeforeErr] = await getDepositorBalance(exampleNFTAdmin)
        expect(balanceBeforeErr).toBe(null)
        const balanceBefore = Number(balanceBeforeRes)

        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)

        const [balanceAfterRes, balanceAfterErr] = await getDepositorBalance(exampleNFTAdmin)
        expect(balanceAfterErr).toBe(null)
        const balanceAfter = Number(balanceAfterRes)

        expect(balanceAfter - balanceBefore).toBe(mintAmount)
    })

    it("should update Depositor balance from public account", async () => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const [balanceBeforeRes, balanceBeforeErr] = await getDepositorBalance(exampleNFTAdmin)
        expect(balanceBeforeErr).toBe(null)
        const balanceBefore = Number(balanceBeforeRes)

        const mintAmount = 100
        await mintFlow(alice, mintAmount)
        await addFlowTokensToDepositorPublic(alice, mintAmount, exampleNFTAdmin)

        const [balanceAfterRes, balanceAfterErr] = await getDepositorBalance(exampleNFTAdmin)
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

        const depositorWithdrawEvents = getEventsFromTransaction(tx, composeLostAndFoundTypeIdentifier("DepositorTokensWithdrawn"))
        let tokensWithdrawn = 0.0
        depositorWithdrawEvents.forEach(event => {
            tokensWithdrawn += Number(event.data.tokens)
        })

        const balance = Number(depositorWithdrawEvents[depositorWithdrawEvents.length-1].data.balance)
        expect(tokensWithdrawn + balance).toBe(mintAmount)

        const depositEvent = getEventFromTransaction(tx, composeLostAndFoundTypeIdentifier("TicketDeposited"))
        expect(depositEvent.data.type.typeID).toBe(composeExampleNFTTypeIdentifier("NFT"))
        expect(depositEvent.data.redeemer).toBe(alice)
    })

    it("should send ExampleNFT with setup", async () => {
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

    it("should refund all fees when withdrawn", async() => {
        await ensureDepositorSetup(exampleNFTAdmin)
        const mintAmount = 100
        await mintFlow(exampleNFTAdmin, mintAmount)
        await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)
        let [flowBalanceBefore, fbbErr] = await executeScript("FlowToken/get_flow_token_balance", [exampleNFTAdmin])
        let [depositorBalanceBefore, dbbErr] = await getDepositorBalance(exampleNFTAdmin)
        let totalBalanceBefore = Number(flowBalanceBefore) + Number(depositorBalanceBefore)

        const args = [alice]
        const signers = [exampleNFTAdmin]
        let [tx, err] = await sendTransaction({name: "ExampleNFT/mint_and_deposit_with_depositor", args, signers});
        expect(err).toBe(null)

        const depositorWithdrawEvents = getEventsFromTransaction(tx, composeLostAndFoundTypeIdentifier("DepositorTokensWithdrawn"))
        let tokensWithdrawn = 0.0
        depositorWithdrawEvents.forEach(event => {
            tokensWithdrawn += Number(event.data.tokens)
        })

        const balance = Number(depositorWithdrawEvents[depositorWithdrawEvents.length-1].data.balance)
        expect(tokensWithdrawn + balance).toBe(mintAmount)

        const depositEvent = getEventFromTransaction(tx, composeLostAndFoundTypeIdentifier("TicketDeposited"))
        expect(depositEvent.data.type.typeID).toBe(composeExampleNFTTypeIdentifier("NFT"))
        expect(depositEvent.data.redeemer).toBe(alice)

        // redeem them and make sure the total balance of in depositor + depositor flow balance is the same as before
        // seems like events aren't paying back to the depositor for ticket redemption or bin destruction
        let [redeemTx, redeemErr] = await sendTransaction({
            name: "ExampleNFT/redeem_example_nft_all",
            args: [],
            signers: [alice],
            limit: 9999
        })
        expect(redeemErr).toBe(null)

        let [dBalance, dbErr] = await getDepositorBalance(exampleNFTAdmin)
        let [fBalance, fbErr] = await executeScript("FlowToken/get_flow_token_balance", [exampleNFTAdmin])
        let totalBalanceAfter = Number(dBalance) + Number(fBalance)
        // There is a very very small amount of loss here due to rounding errors on my machine.
        // assert that the difference is tiny to help protect against this
        expect(Math.abs(totalBalanceAfter - totalBalanceAfter) < .00000001).toBe(true)
    })

    describe("DepositorBalanceLow event", () => {
        const depThreshold = 100
        const mintAmount = depThreshold - 1

        // NB this describe block of tests share state
        describe("expected emissions",  () => {
            it("emits on DEPOSIT if threshold is set and balance after is LESS", async () => {
                await ensureDepositorSetup(exampleNFTAdmin, depThreshold)
                await mintFlow(exampleNFTAdmin, mintAmount)

                const [sendRes, sendErr] = await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)
                expect(sendErr).toBeNull()

                const balanceLowEvent = getEventFromTransaction(
                    sendRes,
                    composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
                )
                const {threshold: eventThreshold, balance} = balanceLowEvent.data
                expect(parseFloat(eventThreshold)).toEqual(depThreshold)
                expect(parseFloat(balance)).toEqual(mintAmount)
            })

            it("emits on WITHDRAW if threshold is set and balance after is LESS", async () => {
                await mintFlow(exampleNFTAdmin, depThreshold * 2)
                const [sendRes, sendErr] = await triggerLowThresholdEvent(exampleNFTAdmin, depThreshold)
                expect(sendErr).toBeNull()

                const balanceLowEvent = getEventFromTransaction(
                    sendRes,
                    composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
                )
                const {threshold, balance} = balanceLowEvent.data
                expect(parseFloat(threshold)).toEqual(depThreshold)
                expect(parseFloat(balance)).toEqual(depThreshold - 1)
            })

            it('emits if threshold is set and balance after is EQUAL', async () => {
                await mintFlow(exampleNFTAdmin, depThreshold * 2)
                const [sendRes, sendErr] = await withdrawToThreshold(exampleNFTAdmin, depThreshold)
                expect(sendErr).toBeNull()

                const balanceLowEvent = getEventFromTransaction(
                    sendRes,
                    composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
                )
                const {threshold, balance} = balanceLowEvent.data
                expect(parseFloat(threshold)).toEqual(depThreshold)
                expect(parseFloat(balance)).toEqual(depThreshold)
            })
        })

        it("should not be emitted when no threshold is set", async () => {
            const mintAmount = 1
            await ensureDepositorSetup(exampleNFTAdmin, null)
            await mintFlow(exampleNFTAdmin, mintAmount)

            const [sendRes, sendErr] = await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)
            expect(sendErr).toBeNull()

            const depositorTokensAddedEvent = getEventFromTransaction(
                sendRes,
                composeLostAndFoundTypeIdentifier("DepositorTokensAdded")
            )
            const { balance } = depositorTokensAddedEvent.data
            expect(parseFloat(balance)).toEqual(mintAmount)

            const balanceLowEvent = getEventFromTransaction(
                sendRes,
                composeLostAndFoundTypeIdentifier("DepositorBalanceLow"),
                false
            )
            expect(balanceLowEvent).not.toBeDefined()
        })

        it("should not be emitted when balance is not lower", async () => {
            const threshold = 100
            const mintAmount = 101
            await ensureDepositorSetup(exampleNFTAdmin, threshold)
            await mintFlow(exampleNFTAdmin, mintAmount)

            const [sendRes, sendErr] = await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount)
            expect(sendErr).toBeNull()

            const depositorTokensAddedEvent = getEventFromTransaction(
                sendRes,
                composeLostAndFoundTypeIdentifier("DepositorTokensAdded")
            )
            const { balance } = depositorTokensAddedEvent.data
            expect(parseFloat(balance)).toEqual(mintAmount)

            const balanceLowEvent = getEventFromTransaction(
                sendRes,
                composeLostAndFoundTypeIdentifier("DepositorBalanceLow"),
                false
            )
            expect(balanceLowEvent).not.toBeDefined()
        })


        it("should have a configurable threshold", async () => {
            const startThreshold = 2
            const mintAmount = 50
            await ensureDepositorSetup(exampleNFTAdmin, startThreshold)
            await mintFlow(exampleNFTAdmin, mintAmount)

            // init tokens added is same as init threshold - event should emit
            const [addRes, addErr] = await addFlowTokensToDepositor(exampleNFTAdmin, startThreshold)
            expect(addErr).toBe(null)
            const balanceLowEvent = getEventFromTransaction(
                addRes,
                composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
            )
            expect(parseFloat(balanceLowEvent.data.threshold)).toEqual(startThreshold)
            expect(parseFloat(balanceLowEvent.data.balance)).toEqual(startThreshold)

            // after adding tokens, balance is higher than threhsold - no emit
            const [add2Res, add2Err] = await addFlowTokensToDepositor(exampleNFTAdmin, mintAmount - startThreshold)
            expect(add2Err).toBe(null)
            const balanceLowEvent2 = getEventFromTransaction(
                add2Res,
                composeLostAndFoundTypeIdentifier("DepositorBalanceLow"),
                false
            )
            expect(balanceLowEvent2).not.toBeDefined()

            // set balance higher than total tokens minted
            const endThreshold = mintAmount * 2
            const [_, thresholdErr] = await setLowBalanceThreshold(exampleNFTAdmin, endThreshold)
            expect(thresholdErr).toBe(null)


            // after withdrawing events, balance is lower than threshold - emit
            const [withdrawRes, withdrawErr] = await withdrawFlowFromDepositor(exampleNFTAdmin, mintAmount)
            expect(withdrawErr).toBe(null)

            const balanceLowEvent3 = getEventFromTransaction(
                withdrawRes,
                composeLostAndFoundTypeIdentifier("DepositorBalanceLow")
            )
            expect(parseFloat(balanceLowEvent3.data.threshold)).toEqual(endThreshold)
            expect(parseFloat(balanceLowEvent3.data.balance)).toEqual(0)
        })
    })
})
