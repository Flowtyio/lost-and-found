import {
    executeScript,
    getContractAddress, mintFlow,
    sendTransaction
} from "flow-js-testing";
import {after, alice, before, exampleTokenAdmin} from "./common";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("lost-and-found FungibleToken tests", () => {
    const depositExampleToken = async (account) => {
        const exampleTokenAddress = await getContractAddress("ExampleToken")

        const args = [account]
        const signers = [exampleTokenAddress]
        let [tx, err] = await sendTransaction({name: "ExampleToken/mint_and_deposit", args, signers});
        return [tx, err]
    }

    const configureExampleToken = async (account) => {
        const signers = [account]
        let [tx, err] = await sendTransaction({name: "ExampleToken/setup_vault", args: [], signers})
        return [tx, err]
    }

    beforeEach(before);

    afterEach(after);

    test("deposit ExampleToken", async () => {
        const exampleTokenAddress = await getContractAddress("ExampleToken")
        const args = [alice, 1000]
        const signers = [exampleTokenAddress]
        let [tx, err] = await sendTransaction({name: "ExampleToken/deposit_example_token", args, signers});
        expect(err).toBe(null)
        console.log({tx, err})

        let result
        [result, err] = await executeScript("get_redeemable_types_for_addr", [alice])
        expect(result.includes('A.f3fcd2c1a78f5eee.ExampleToken.Vault')).toBe(true)

        const ticketID = tx.events[2].data.ticketID
        expect(ticketID).toBeGreaterThan(0)
        let [ticketDetail, ticketDetailErr] = await executeScript("ExampleToken/borrow_ticket", [alice, ticketID])

        let [redeemTx, redeemErr] = await sendTransaction({
            name: "ExampleToken/redeem_example_token_all",
            args: [],
            signers: [alice]
        })
        console.log({redeemTx, redeemErr})
        expect(redeemErr).toBe(null)

        let [balance, balanceErr] = await executeScript("ExampleToken/get_example_token_balance", [alice])
        console.log({balance, balanceErr})
    })

    test("redeem ExampleToken", async () => {
        await depositExampleNFT(alice)
        const signers = [alice]
        let [tx, redeemErr] = await sendTransaction({name: "ExampleNFT/redeem_example_nft_all", args: [], signers})
        expect(redeemErr).toBe(null)
        let [result, err] = await executeScript("ExampleNFT/get_account_ids", [alice])
        expect(result.length).toBe(1)
        expect(err).toBe(null)
    })

    test("redeem FlowToken", async() => {
        const depositAmount = 100.0
        await mintFlow(exampleTokenAdmin, depositAmount)

        let [depTx, depErr] = await sendTransaction({name: "FlowToken/deposit", args: [alice, depositAmount], signers: [exampleTokenAdmin]})
        console.log({depTx, depErr})

        let [redeemTx, redErr] = await sendTransaction({name: "FlowToken/redeem", args: [], signers: [alice]})
        console.log({redeemTx, redErr})
    })
})
