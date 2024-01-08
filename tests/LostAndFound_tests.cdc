import Test
import "test_helpers.cdc"

pub fun setup() {
    deployAll()
}

pub fun testImport() {
    scriptExecutor("import_contracts.cdc", [])
}