package test_main

import (
	"testing"

	. "github.com/bjartek/overflow"
)

func TestDepositor(t *testing.T) {

	otu := NewOverflowTest(t)

	t.Run("should initialize a depositor", func(t *testing.T) {

		otu.setupDepositor("account").
			assertDepositorBalance("account", 0.0)

	})

	t.Run("should update Depositor balance", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account").
			assertDepositorBalance("account", 0.0)

		otu.addFlowToDepositor("account", amount)

		otu.assertDepositorBalance("account", amount)

	})

	t.Run("should update Depositor balance from public account", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account").
			assertDepositorBalance("account", 0.0)

		otu.addFlowToDepositorPublic("user1", "account", amount)

		otu.assertDepositorBalance("account", amount)

	})

	t.Run("should send ExampleNFT with setup", func(t *testing.T) {

		amount := 100.0

		otu.setupDepositor("account").
			addFlowToDepositor("account", amount).
			assertDepositorBalance("account", amount)

		otu.cleanup("user1")

		otu.O.Tx(
			"ExampleNFT/setup_account_example_nft",
			WithSigner("user1"),
		).
			AssertSuccess(t)

		otu.assertExampleNFTLength("user1", 0)

	})

}
