import Test
import "test_helpers.cdc"

pub fun setup() {
    deployAll()
}

pub fun testImport() {
    scriptExecutor("import_contracts.cdc", [])
}

pub fun testEstimateDeposit() {
    
}

// TODO: estimate deposit
// TODO: estimate deposit nil shelf
// TODO: estimate deposit nil bin
// TODO: getRedeemableTypes
// TODO: deposit (happy path)
// TODO: deposit invalid repayment capability
// TODO: deposit invalid payment type
// TODO: try send resource (NFT) - valid collection public capability
// TODO: try send resource (NFT) - invalid collection public capability
// TODO: try send resource (NFT) - valid receiver capability
// TODO: try send resource (NFT) - invalid receiver capability
// TODO: try send resource (FT) - valid receiver capability
// TODO: send non nft/ft resource
// TODO: getAddress
// TODO: redeemAll - nft
// TODO: redeemAll - ft
// TODO: borrowAllTickets for address
// TODO: borrowAllTicketsByType - nft
// TODO: borrowAllTicketsByType - ft
// TODO: create depositor