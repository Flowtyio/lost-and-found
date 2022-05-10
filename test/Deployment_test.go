package test

import (
	"testing"

	"github.com/bjartek/overflow/overflow"
	"github.com/stretchr/testify/assert"
)

func TestDeployment(t *testing.T) {
	f, err := overflow.NewTestingEmulator().StartE()
	assert.Nil(t, err)
	value := f.ScriptFromFile("import_lost_and_found").ScriptPath("./scripts/").RunReturnsInterface()
	assert.True(t, value.(bool))
}