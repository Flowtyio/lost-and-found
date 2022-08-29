package test_main

import (
	"fmt"
	"strings"
	"testing"

	. "github.com/bjartek/overflow"
	"github.com/hexops/autogold"
	"github.com/stretchr/testify/assert"
)

type OverflowTestUtils struct {
	T *testing.T
	O *OverflowState
}

func NewOverflowTest(t *testing.T) *OverflowTestUtils {
	o := Overflow(
		WithNetwork("testing"),
		WithFlowForNewUsers(1000.0),
		WithBasePath("cadence"),
	)
	return &OverflowTestUtils{
		T: t,
		O: o,
	}
}

func GetBalanceFromEvents(o OverflowResult) float64 {
	var balance float64
	for name, events := range o.Events {
		if strings.HasSuffix(name, "TokensWithdrawn") {
			for _, event := range events {
				balance = balance + event.Fields["amount"].(float64)
			}
		}
	}
	return balance
}

func (o *OverflowTestUtils) setupDepositor(user string, lowBalanceThreshold float64) *OverflowTestUtils {

	// destroy Depositor if any
	o.O.Tx("Depositor/destroy",
		WithSigner(user),
	).
		AssertSuccess(o.T)

	if lowBalanceThreshold == 0.0 {
		// setup Depositor
		o.O.Tx("Depositor/setup",
			WithSigner(user),
			WithArg("lowBalanceThreshold", nil),
		).
			AssertSuccess(o.T).
			AssertEmitEventName(o.T, "DepositorCreated")
	} else {
		// setup Depositor
		o.O.Tx("Depositor/setup",
			WithSigner(user),
			WithArg("lowBalanceThreshold", lowBalanceThreshold),
		).
			AssertSuccess(o.T).
			AssertEmitEventName(o.T, "DepositorCreated")
	}

	return o
}

func (o *OverflowTestUtils) assertDepositorBalance(user string, expectedBalance float64) *OverflowTestUtils {

	// get depositor balance
	o.O.Script("Depositor/get_balance",
		WithArg("addr", user),
	).
		AssertWant(o.T, autogold.Want("get_balance", expectedBalance))

	return o
}

func (o *OverflowTestUtils) addFlowToDepositor(user string, amount float64) *OverflowTestUtils {

	// get depositor balance
	o.O.Tx("Depositor/add_flow_tokens",
		WithSigner(user),
		WithArg("amount", amount),
	).
		AssertSuccess(o.T).
		AssertEvent(o.T, "DepositorTokensAdded", map[string]interface{}{
			"tokens": amount,
		})

	return o
}

func (o *OverflowTestUtils) addFlowToDepositorPublic(user, receiver string, amount float64) *OverflowTestUtils {

	// get depositor balance
	o.O.Tx("Depositor/add_flow_tokens_public",
		WithSigner(user),
		WithArg("addr", receiver),
		WithArg("amount", amount),
	).
		AssertSuccess(o.T).
		AssertEvent(o.T, "DepositorTokensAdded", map[string]interface{}{
			"tokens": amount,
		})

	return o
}

func (o *OverflowTestUtils) cleanup(user string) *OverflowTestUtils {

	SignWithUser := o.O.TxFN(
		WithSigner(user),
	)

	SignWithUser("clear_all_tickets").AssertSuccess(o.T)
	SignWithUser("ExampleToken/destroy_example_token_storage").AssertSuccess(o.T)
	SignWithUser("ExampleNFT/destroy_example_nft_storage").AssertSuccess(o.T)

	return o
}

func (o *OverflowTestUtils) assertExampleNFTLength(user string, length uint64) *OverflowTestUtils {

	res, err := o.O.Script("ExampleNFT/get_account_ids",
		WithArg("addr", user),
	).
		GetAsInterface()

	if err != nil {
		panic(err)
	}

	if length == 0 {
		assert.Equal(o.T, res, nil)
		return o
	}

	result, ok := res.([]interface{})

	if !ok {
		fmt.Print(res)
		panic(ok)
	}

	assert.Equal(o.T, len(result), length)

	return o
}

func (o *OverflowTestUtils) depositExampleToken(user string, amount float64) *OverflowTestUtils {

	o.O.Tx("ExampleToken/deposit_example_token",
		WithSigner("account"),
		WithArg("redeemer", user),
		WithArg("amount", amount),
	).
		AssertSuccess(o.T)

	return o
}

func (o *OverflowTestUtils) configureExampleToken(user string) *OverflowTestUtils {

	o.O.Tx("ExampleToken/setup_vault",
		WithSigner(user),
	).
		AssertSuccess(o.T)

	return o
}

func (o *OverflowTestUtils) depositExampleNFT(user string) *OverflowTestUtils {

	o.O.Tx("ExampleNFT/mint_and_deposit_example_nft",
		WithSigner("account"),
		WithArg("recipient", user),
	).
		AssertSuccess(o.T)

	return o
}

func (o *OverflowTestUtils) depositExampleNFTs(user string, amount uint64) *OverflowTestUtils {

	o.O.Tx("ExampleNFT/mint_and_deposit_example_nfts",
		WithSigner("account"),
		WithArg("recipient", user),
		WithArg("numToMint", amount),
	).
		AssertSuccess(o.T)

	return o
}

func (o *OverflowTestUtils) depositExampleNFTandGetID(user string) uint64 {

	res, err := o.O.Tx("ExampleNFT/mint_and_deposit_example_nft",
		WithSigner("account"),
		WithArg("recipient", user),
	).
		AssertSuccess(o.T).
		GetIdFromEvent("LostAndFound.TicketDeposited", "ticketID")

	if err != nil {
		panic(err)
	}

	return res

}
