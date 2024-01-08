import "FungibleToken"
import "ExampleToken"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&ExampleToken.Vault>(from: /storage/exampleTokenVault) == nil {
            acct.save(<-ExampleToken.createEmptyVault(), to: /storage/exampleTokenVault)
        }
        
        acct.link<&{FungibleToken.Receiver}>(
            /public/exampleTokenReceiver,
            target: /storage/exampleTokenVault
        )

        acct.link<&{FungibleToken.Balance}>(
            /public/exampleTokenBalance,
            target: /storage/exampleTokenVault
        )

        acct.link<&{FungibleToken.Provider, FungibleToken.Balance, FungibleToken.Receiver}>(/private/exampleTokenProvider, target: /storage/exampleTokenVault)
    }
}
 