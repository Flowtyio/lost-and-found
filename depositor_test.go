package test_main

import (
	"testing"

	. "github.com/bjartek/overflow"
)

func TestDepositor(t *testing.T) {

	otu := NewOverflowTest(t)

	t.Run("should initialize a depositor", func(t *testing.T) {

		otu.setupDepositor("account", 0.0).
			assertDepositorBalance("account", 0.0)

	})

	t.Run("should update Depositor balance", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account", 0.0).
			assertDepositorBalance("account", 0.0)

		otu.addFlowToDepositor("account", amount)

		otu.assertDepositorBalance("account", amount)

	})

	t.Run("should update Depositor balance from public account", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account", 0.0).
			assertDepositorBalance("account", 0.0)

		otu.addFlowToDepositorPublic("user1", "account", amount)

		otu.assertDepositorBalance("account", amount)

	})

	t.Run("should send ExampleNFT with setup", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account", 0.0).
			addFlowToDepositor("account", amount).
			assertDepositorBalance("account", amount)

		otu.cleanup("user1")

		otu.O.Tx(
			"ExampleNFT/setup_account_example_nft",
			WithSigner("user1"),
		).
			AssertSuccess(t)

		otu.assertExampleNFTLength("user1", 0)

		otu.O.Tx("ExampleNFT/try_send_example_nft_with_depositor",
			WithSigner("account"),
			WithArg("recipient", "user1"),
		).
			AssertSuccess(t).
			AssertEvent(t, "Deposit", map[string]interface{}{
				"to": otu.O.Address("user1"),
			})

	})

	t.Run("should refund all fees when withdrawn", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account", 0.0).
			addFlowToDepositor("account", amount).
			assertDepositorBalance("account", amount)

		otu.cleanup("user1")

		event := otu.O.Tx(
			"ExampleNFT/mint_and_deposit_with_depositor",
			WithSigner("account"),
			WithArg("recipient", "user1"),
		).
			Print().
			AssertSuccess(t).
			AssertEvent(t, "TicketDeposited", map[string]interface{}{
				"type":     "A.f8d6e0586b0a20c7.ExampleNFT.NFT",
				"redeemer": otu.O.Address("user1"),
			})

		tokenSentIn := GetBalanceFromEvents(event)

		otu.O.Tx("ExampleNFT/redeem_example_nft_all",
			WithSigner("user1"),
		).
			AssertSuccess(t)

		otu.assertDepositorBalance("account", amount-tokenSentIn)

	})

	depThreshold := 100.0
	mintAmount := depThreshold - 1.0

	t.Run("DepositorBalanceLow event - emits on DEPOSIT if threshold is set and balance after is LESS", func(t *testing.T) {
		otu.cleanup("user1")

		otu.setupDepositor("account", depThreshold)

		// get depositor balance
		otu.O.Tx("Depositor/add_flow_tokens",
			WithSigner("account"),
			WithArg("amount", mintAmount),
		).
			AssertSuccess(t).
			AssertEvent(t, "DepositorTokensAdded", map[string]interface{}{
				"tokens": mintAmount,
			}).
			AssertEvent(t, "DepositorBalanceLow", map[string]interface{}{
				"balance":   mintAmount,
				"threshold": depThreshold,
			})

	})

	t.Run("DepositorBalanceLow event - emits on WITHDRAW if threshold is set and balance after is LESS", func(t *testing.T) {

		// get depositor balance
		otu.O.Tx("Depositor/withdraw_below_threshold",
			WithSigner("account"),
			WithArg("lowBalanceThreshold", depThreshold),
		).
			AssertSuccess(t).
			AssertEvent(t, "DepositorBalanceLow", map[string]interface{}{
				"balance":   depThreshold - 1.0,
				"threshold": depThreshold,
			})

	})

	t.Run("DepositorBalanceLow event - emits if threshold is set and balance after is EQUAL", func(t *testing.T) {

		// get depositor balance
		otu.O.Tx("Depositor/withdraw_to_threshold",
			WithSigner("account"),
			WithArg("lowBalanceThreshold", depThreshold),
		).
			AssertSuccess(t).
			AssertEvent(t, "DepositorBalanceLow", map[string]interface{}{
				"balance":   depThreshold,
				"threshold": depThreshold,
			})

	})

	t.Run("should not be emitted when no threshold is set", func(t *testing.T) {

		mintAmount = 1.0

		otu.setupDepositor("account", 0.0).
			addFlowToDepositor("account", mintAmount).
			assertDepositorBalance("account", mintAmount)

	})

	t.Run("should not be emitted when balance is not lower", func(t *testing.T) {

		threshold := 100.0
		mintAmount := 101.0

		otu.setupDepositor("account", threshold)

		otu.O.Tx("Depositor/add_flow_tokens",
			WithSigner("account"),
			WithArg("amount", mintAmount),
		).
			AssertSuccess(t).
			AssertEventCount(t, 3)

	})

	t.Run("should have a configurable threshold", func(t *testing.T) {

		startThreshold := 2.0
		mintAmount := 50.0

		otu.setupDepositor("account", startThreshold).
			addFlowToDepositor("account", startThreshold).
			assertDepositorBalance("account", startThreshold)

		otu.O.Tx("Depositor/add_flow_tokens",
			WithSigner("account"),
			WithArg("amount", mintAmount-startThreshold),
		).
			AssertSuccess(t).
			AssertEventCount(t, 3)

		endThreshold := mintAmount * 2

		otu.O.Tx("Depositor/set_threshold",
			WithSigner("account"),
			WithArg("newThreshold", endThreshold),
		).
			AssertSuccess(t)

		otu.O.Tx("Depositor/withdraw_tokens",
			WithSigner("account"),
			WithArg("amount", mintAmount),
		).
			AssertSuccess(t).
			AssertEvent(t, "DepositorBalanceLow", map[string]interface{}{
				"balance":   0.0,
				"threshold": endThreshold,
			})

	})

}
