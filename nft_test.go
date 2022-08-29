package test_main

import (
	"testing"

	. "github.com/bjartek/overflow"
	"github.com/hexops/autogold"
	"github.com/stretchr/testify/assert"
)

func TestNonFungibleToken(t *testing.T) {

	otu := NewOverflowTest(t)
	// depositAmount := 1000.0
	user := "user1"

	t.Run("deposit ExampleToken", func(t *testing.T) {

		otu.depositExampleNFT(user)

		otu.O.Script("get_redeemable_types_for_addr",
			WithArg("addr", user),
		).
			AssertWithPointerWant(t, "/0", autogold.Want("should be with Example NFT Type",
				"A.f8d6e0586b0a20c7.ExampleNFT.NFT",
			))

	})

	t.Run("redeem ExampleNFT", func(t *testing.T) {

		otu.depositExampleNFT(user)

		otu.O.Tx("ExampleNFT/redeem_example_nft_all",
			WithSigner(user),
		).
			AssertSuccess(t)

		otu.O.Script("ExampleNFT/get_account_ids",
			WithArg("addr", user),
		).
			AssertWithPointerWant(t, "/0", autogold.Want("should be with ID 0",
				uint64(0),
			))

		otu.O.Script("get_redeemable_types_for_addr",
			WithArg("addr", user),
		).
			AssertWant(t, autogold.Want("should be nil",
				nil,
			))

	})

	t.Run("send ExampleNFT with setup", func(t *testing.T) {

		otu.cleanup(user)

		otu.O.Tx("ExampleNFT/setup_account_example_nft",
			WithSigner(user),
		).
			AssertSuccess(t)

		otu.O.Script("ExampleNFT/get_account_ids",
			WithArg("addr", user),
		).
			AssertWant(t, autogold.Want("should be nil in nft id",
				nil,
			))

		otu.O.Tx("ExampleNFT/try_send_example_nft",
			WithSigner("account"),
			WithArg("recipient", user),
		).
			AssertSuccess(t).
			AssertEvent(t, "ExampleNFT.Deposit", map[string]interface{}{
				"to": otu.O.Address(user),
			})

		otu.O.Script("ExampleNFT/get_account_ids",
			WithArg("addr", user),
		).
			AssertWithPointerWant(t, "/0", autogold.Want("should be with ID 0",
				uint64(0),
			))

	})

	t.Run("send ExampleNFT without setup", func(t *testing.T) {

		otu.cleanup(user)

		_, err := otu.O.Script("ExampleNFT/get_account_ids",
			WithArg("addr", user),
		).
			GetAsInterface()

		assert.Error(t, err)
		if err != nil {
			assert.Contains(t, err.Error(), "unexpectedly found nil while forcing an Optional value")
		}

		otu.O.Tx("ExampleNFT/mint_and_deposit_example_nft",
			WithSigner("account"),
			WithArg("recipient", user),
		).
			AssertSuccess(t).
			AssertEvent(t, "LostAndFound.TicketDeposited", map[string]interface{}{
				"redeemer":    otu.O.Address(user),
				"type":        "A.f8d6e0586b0a20c7.ExampleNFT.NFT",
				"name":        "testname",
				"description": "descr",
				"thumbnail":   "image.html",
			})

	})

	t.Run("borrow all ExampleNFT tickets", func(t *testing.T) {

		otu.cleanup(user)

		otu.depositExampleNFT(user)
		otu.depositExampleNFT(user)
		otu.depositExampleNFT(user)

		res, err := otu.O.Script("ExampleNFT/borrow_all_tickets_as_struct",
			WithArg("addr", user),
		).
			GetAsInterface()

		assert.NoError(t, err)
		assert.Equal(t, len(res.([]interface{})), 3)

	})

	t.Run("should return all storage fees after redemption", func(t *testing.T) {

		otu.cleanup(user)

		otu.O.Tx("ExampleNFT/destroy_example_nft_storage",
			WithSigner(user),
		).
			AssertSuccess(t)

		beforeBalance, err := otu.O.Script("FlowToken/get_flow_token_balance",
			WithArg("addr", user),
		).
			GetAsInterface()

		assert.NoError(t, err)

		otu.depositExampleNFTs(user, 10)

		otu.O.Tx("ExampleNFT/redeem_example_nft_all",
			WithSigner(user),
		).
			AssertSuccess(t)

		afterBalance, err := otu.O.Script("FlowToken/get_flow_token_balance",
			WithArg("addr", user),
		).
			GetAsInterface()

		assert.NoError(t, err)

		assert.Greater(t, afterBalance.(float64)+float64(0.0001), beforeBalance.(float64))

	})

	t.Run("should return all ids of a specific NFT type in Bin", func(t *testing.T) {

		otu.cleanup(user)

		otu.depositExampleNFTs(user, 100)

		res, err := otu.O.Script("ExampleNFT/get_bin_nft_id",
			WithArg("addr", user),
			WithArg("type", "A.f8d6e0586b0a20c7.ExampleNFT.NFT"),
		).
			GetAsInterface()

		assert.NoError(t, err)
		assert.Equal(t, len(res.([]interface{})), 100)
	})

}
