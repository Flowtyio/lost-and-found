import {
    executeScript,
    getContractAddress,
    sendTransaction
} from "flow-js-testing";
import {after, alice, before, exampleTokenAdmin, getRedeemableTypes, lostAndFoundAdmin} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

const depositAmount = 1000

describe("lost-and-found FungibleToken tests", () => {
    beforeEach(async () => {
        await before()
    });

    // Stop emulator, so it could be restarted
    afterEach(async () => {
        await after()
    });

    const depositExampleToken = async (account, amount) => {
        const exampleTokenAddress = await getContractAddress("ExampleToken")

        const args = [account, amount]
        const signers = [exampleTokenAddress]
        let [tx, err] = await sendTransaction({name: "ExampleToken/deposit_example_token", args, signers});
        return [tx, err]
    }

    const configureExampleToken = async (account) => {
        const signers = [account]
        let [tx, err] = await sendTransaction({name: "ExampleToken/setup_vault", args: [], signers})
        return [tx, err]
    }

    test("deposit ExampleToken", async () => {
        const args = [alice, depositAmount]
        const signers = [exampleTokenAdmin]
        let [tx, err] = await sendTransaction({name: "ExampleToken/deposit_example_token", args, signers});
        expect(err).toBe(null)

        let result
        [result, err] = await getRedeemableTypes(alice)
        expect(err).toBe(null)
        let found = false
        result.forEach(val => {
            if (val.typeID === `A.${exampleTokenAdmin.substring(2)}.ExampleToken.Vault`) {
                found = true
            }
        })
        expect(found).toBe(true)

        const ticketID = tx.events[2].data.ticketID
        expect(ticketID).toBeGreaterThan(0)
        let [ticketDetail, ticketDetailErr] = await executeScript("ExampleToken/borrow_ticket", [alice, ticketID])
        expect(ticketDetailErr).toBe(null)
    })

    test("redeem ExampleToken", async () => {
        await depositExampleToken(alice, depositAmount)
        let [_, redeemErr] = await sendTransaction({
            name: "ExampleToken/redeem_example_token_all",
            args: [],
            signers: [alice],
            limit: 9999
        })
        expect(redeemErr).toBe(null)

        let [balance, balanceErr] = await executeScript("ExampleToken/get_example_token_balance", [alice])
        expect(balanceErr).toBe(null)
        expect(Number(balance)).toBeGreaterThanOrEqual(depositAmount)

        const [redeemableTypes, rtErr] = await getRedeemableTypes(alice)
        expect(rtErr).toBe(null)
        let found = false
        redeemableTypes.forEach(val => {
            if (val.typeID === `A.${exampleTokenAdmin.substring(2)}.ExampleToken.Vault`) {
                found = true
            }
        })
        expect(found).toBe(false)
    })

    test("send ExampleToken with setup", async() => {
        let [_, setupErr] = await sendTransaction({
            name: "ExampleToken/setup_account_ft",
            args: [],
            signers: [alice],
            limit: 999
        })
        expect(setupErr).toBe(null)

        let [balance, balanceErr] = await executeScript("ExampleToken/get_example_token_balance", [alice])
        expect(balanceErr).toBe(null)

        let [sendRes, sendErr] = await sendTransaction({
            name: "ExampleToken/try_send_example_token",
            args: [alice, depositAmount],
            signers: [exampleTokenAdmin],
            limit: 9999
        })
        expect(sendErr).toBe(null)
        expect(sendRes.events.length).toBe(3)
        expect(sendRes.events[2].type).toBe(`A.${exampleTokenAdmin.substring(2)}.ExampleToken.TokensDeposited`)
        expect(Number(sendRes.events[2].data.amount)).toBe(depositAmount)
        expect(sendRes.events[2].data.to).toBe(alice)

        let [balanceAfter, balanceAfterErr] = await executeScript("ExampleToken/get_example_token_balance", [alice])
        expect(balanceAfterErr).toBe(null)
        expect(Number(balanceAfter)).toBe(depositAmount + Number(balance))
    })

    test("send ExampleToken without setup", async() => {
        await sendTransaction({
            name: "ExampleToken/destroy_example_token_storage",
            signers: [alice],
            args: [],
            limit: 9999
        })

        let [balance, balanceErr] = await executeScript("ExampleToken/get_example_token_balance", [alice])
        expect(balanceErr.message.includes("unexpectedly found nil while forcing an Optional value")).toBe(true)

        let [sendRes, sendErr] = await sendTransaction({
            name: "ExampleToken/try_send_example_token",
            args: [alice, depositAmount],
            signers: [exampleTokenAdmin],
            limit: 9999
        })
        expect(sendErr).toBe(null)
        expect(sendRes.events.length).toBe(5)
        expect(sendRes.events[2].type).toBe(`A.${lostAndFoundAdmin.substring(2)}.LostAndFound.TicketDeposited`)
        expect(sendRes.events[2].data.type.typeID).toBe(`A.${exampleTokenAdmin.substring(2)}.ExampleToken.Vault`)
        expect(sendRes.events[2].data.redeemer).toBe(alice)
    })
})
