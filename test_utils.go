package test_main

import (
	"fmt"
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

func (o *OverflowTestUtils) setupDepositor(user string) *OverflowTestUtils {

	// destroy Depositor if any
	o.O.Tx("Depositor/destroy",
		WithSigner(user),
	).
		AssertSuccess(o.T)

	// setup Depositor
	o.O.Tx("Depositor/setup",
		WithSigner(user),
		WithArg("lowBalanceThreshold", nil),
	).
		AssertSuccess(o.T).
		AssertEmitEventName(o.T, "DepositorCreated")

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
