import FungibleToken from "./FungibleToken.cdc"
import FlowStorageFees from "./FlowStorageFees.cdc"
import FlowToken from "./FlowToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"

// LostAndFound
// One big problem on the flow blockchain is how to handle accounts that are
// not configured to receive assets that you want to send. Currently,
// lots of platforms have to create their own escrow for people to redeem. If not an
// escrow, accounts might instead be skipped for things like an airtdrop
// because they aren't able to receive the assets they should have gotten.
// LostAndFound is meant to solve that problem, giving a central easy to use place to send
// and redeem items
//
// The LostAndFound is split into a few key components:
// Ticket  - Tickets contain the resource which can be redeemed by a user. Everything else is organization around them.
// Bin     - Bins sort tickets by their type. If two ExampleNFT.NFT items are deposited, there would be two tickets made.
//           Those two tickets would be put in the same Bin because they are the same type
// Shelf   - Shelves organize bins by address. When a resource is deposited into the LostAndFound, its receiver shelf is
//           located, then the appropriate bin is picked for the item to go to. If the bin doesn't exist yet, a new one is made.
//
// In order for an account to redeem an item, they have to supply a receiver which matches the address of the ticket's redeemer
// For ease of use, there are three supported receivers:
// - NonFunigibleToken.Receiver
// - FungibleToken.Receiver
// - LostAndFound.ResourceReceiver (This is a placeholder so that non NFT and FT resources can be utilized here)
pub contract LostAndFound {
    pub let LostAndFoundPublicPath: PublicPath
    pub let LostAndFoundStoragePath: StoragePath
    pub let DepositerPublicPath: PublicPath
    pub let DepositerStoragePath: StoragePath

    pub event TicketDeposited(redeemer: Address, ticketID: UInt64, type: Type, memo: String?, name: String?, description: String?, thumbnail: String?)
    pub event TicketRedeemed(redeemer: Address, ticketID: UInt64, type: Type)

    pub event DepositerCreated(uuid: UInt64)
    pub event DepositerTokensAdded(uuid: UInt64, tokens: UFix64, balance: UFix64)
    pub event DepositerTokensWithdrawn(uuid: UInt64, tokens: UFix64, balance: UFix64)

    // Placeholder receiver so that any resource can be supported, not just FT and NFT Receivers
    pub resource interface AnyResourceReceiver {
        pub fun deposit(resource: @AnyResource)
    }

    pub resource DepositEstimate {
        pub var item: @AnyResource?
        pub let storageFee: UFix64

        init(item: @AnyResource, storageFee: UFix64) {
            self.item <- item
            self.storageFee = storageFee
        }

        pub fun withdraw(): @AnyResource {
            let resource <- self.item <- nil
            return <-resource!
        }

        destroy() {
            pre {
                self.item == nil: "cannot destroy with non-null item"
            }

            destroy self.item
        }
    }

    // Tickets are the resource that hold items to be redeemed. They carry with them:
    // - item: The Resource which has been deposited to be withdrawn/redeemed
    // - memo: An optional message to attach to this ticket
    // - redeemer: The address which is allowed to withdraw the item from this ticket
    // - redeemed: Whether the ticket has been redeemed. This can only be set by the LostAndFound contract
    pub resource Ticket {
        // The item to be redeemed
        access(contract) var item: @AnyResource?
        // An optional message to attach to this item.
        pub let memo: String?
        // an optional Display view so that frontend's that borrow this ticket know how to show it
        pub let display: MetadataViews.Display?
        // The address that it allowed to withdraw the item fromt this ticket
        pub let redeemer: Address
        //The type of the resource (non-optional) so that bins can represent the true type of an item
        pub let type: Type
        // State maintained by LostAndFound
        pub var redeemed: Bool

        // flow token amount used to store this ticket is returned when the ticket is redeemed
        access(contract) let flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?

        init (item: @AnyResource, memo: String?, display: MetadataViews.Display?, redeemer: Address, flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?) {
            self.type = item.getType()
            self.item <- item
            self.memo = memo
            self.display = display
            self.redeemer = redeemer
            self.redeemed = false

            self.flowTokenRepayment = flowTokenRepayment
        }

        pub fun itemType(): Type {
            return self.type
        }

        pub fun checkItem(): Bool {
            return self.item != nil
        }

        pub fun borrowItem(): &AnyResource {
            pre {
                self.checkItem(): "nil item"
            }

            var currentItem: @AnyResource <- self.item <- nil
            var ref = &currentItem as &AnyResource
            var dummy <- self.item <- currentItem
            destroy dummy
            return ref
        }

        pub fun withdraw(receiver: Capability) {
            pre {
                receiver.address == self.redeemer: "receiver address and redeemer must match"
                !self.redeemed: "already redeemed"
            }

            var redeemableItem <- self.item <- nil
            let cap = receiver.borrow<&AnyResource>()!

            if cap.isInstance(Type<@NonFungibleToken.Collection>()) {
                let target = receiver.borrow<&AnyResource{NonFungibleToken.CollectionPublic}>()!
                let token <- redeemableItem  as! @NonFungibleToken.NFT?
                self.redeemed = true
                emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: token.getType())
                target.deposit(token: <- token!)
                return
            } else if cap.isInstance(Type<@FungibleToken.Vault>()) {
                let target = receiver.borrow<&AnyResource{FungibleToken.Receiver}>()!
                let token <- redeemableItem as! @FungibleToken.Vault?
                self.redeemed = true
                emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: token.getType())
                target.deposit(from: <- token!)
                return
            } else if cap.isInstance(Type<@AnyResource{LostAndFound.AnyResourceReceiver}>()) {
                let target = receiver.borrow<&{LostAndFound.AnyResourceReceiver}>()!
                self.redeemed = true
                emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
                target.deposit(resource: <- redeemableItem)
                return
            } else{
                panic("cannot redeem resource to receiver")
            }
        }

        // we need to be able to take our item back for storage cost estimation
        // otherwise we can't actually deposit a ticket
        access(account) fun takeItem(): @AnyResource {
            self.redeemed = true
            var redeemableItem <- self.item <- nil
            return <-redeemableItem!
        }

        // destructon is only allowed if the ticket has been redeemed and the underlying item is a our dummy resource
        destroy () {
            pre {
                self.redeemed: "Ticket has not been redeemed"
                self.item == nil: "can only destroy if not holding any item"
            }

            destroy <-self.item
        }
    }


    // A Bin is a resource that gathers tickets whos item have the same type.
    // For instance, if two TopShot Moments are deposited to the same redeemer, only one bin
    // will be made which will contain both tickets to redeem each individual moment.
    pub resource Bin {
        access(contract) let tickets: @{UInt64:Ticket}
        access(contract) let type: Type

        init (type: Type) {
            self.tickets <- {}
            self.type = type
        }

        pub fun borrowTicket(id: UInt64): &LostAndFound.Ticket? {
            return &self.tickets[id] as &LostAndFound.Ticket?
        }

        pub fun borrowAllTicketsByType(): [&LostAndFound.Ticket] {
            let tickets: [&LostAndFound.Ticket] = []
            let ids = self.tickets.keys
            for id in ids {
                tickets.append(self.borrowTicket(id: id)!)
            }

            return tickets
        }

        // deposit a ticket to this bin. The item type must match this bin's item type.
        pub fun deposit(ticket: @LostAndFound.Ticket) {
            pre {
                ticket.itemType() == self.type: "ticket and bin types must match"
                ticket.item != nil: "nil item not allowed"
            }

            let redeemer = ticket.redeemer
            let ticketID = ticket.uuid
            let memo = ticket.memo

            let name = ticket.display?.name
            let description = ticket.display?.description
            let thumbnail = ticket.display?.thumbnail?.uri()

            self.tickets[ticket.uuid] <-! ticket
            emit TicketDeposited(redeemer: redeemer, ticketID: ticketID, type: self.type, memo: memo, name: name, description: description, thumbnail: thumbnail)
        }

        pub fun getTicketIDs(): [UInt64] {
            return self.tickets.keys
        }

        access(contract) fun withdrawTicket(ticketID: UInt64): @LostAndFound.Ticket {
            let ticket <- self.tickets.remove(key: ticketID)
            return <- ticket!
        }

        destroy () {
            destroy <-self.tickets
        }
    }

    // A shelf is our top-level organization resource.
    // It groups bins by type to help make discovery of the assets that a
    // redeeming address can claim.
    pub resource Shelf {
        //TODO: soon Type can be used as key, get rid of identifierToType
        access(self) let bins: @{String: Bin}
        access(self) let identifierToType: {String: Type}
        access(self) let redeemer: Address

        init (redeemer: Address) {
            self.bins <- {}
            self.identifierToType = {}
            self.redeemer = redeemer
        }

        pub fun getOwner(): Address {
            return self.owner!.address
        }

        pub fun getRedeemableTypes(): [Type] {
            let types: [Type] = []
            for k in self.bins.keys {
                let t = self.identifierToType[k]!
                if t != nil {
                    types.append(t)
                }
            }
            return types
        }

        pub fun hasType(type: Type): Bool {
            return self.bins[type.identifier] != nil
        }

        pub fun borrowBin(type: Type): &LostAndFound.Bin? {
            return &self.bins[type.identifier] as &LostAndFound.Bin?
        }

        pub fun deposit(ticket: @LostAndFound.Ticket) {
            // is there a bin for this yet?
            let type = ticket.itemType()
            if !self.bins.containsKey(type.identifier) {
                // no bin, make a new one and insert it
                let oldValue <- self.bins.insert(key: type.identifier, <- create Bin(type: type))
                destroy oldValue
                // add this mapping of type to identifier
                self.identifierToType[type.identifier] = type
            }

            let bin = self.borrowBin(type: type)!
            bin.deposit(ticket: <-ticket)
        }


        // Redeem all the tickets of a given type. This is just a convenience function
        // so that a redeemer doesn't have to coordinate redeeming each ticket individually
        // Only one of the three receiver options can be specified, and an optional maximum number of tickets
        // to redeem can be picked to prevent gas issues in case there are large numbers of tickets to be
        // redeemed at once.
        pub fun redeemAll(type: Type, max: Int?, receiver: Capability) {
            pre {
                receiver.address == self.redeemer: "receiver must match the redeemer of this shelf"
                self.bins.containsKey(type.identifier): "no bin for provided type"
            }

            var count = 0
            let borrowedBin = self.borrowBin(type: type)!
            for key in borrowedBin.getTicketIDs() {
                if max != nil && max == count {
                    return
                }

                self.redeem(type: type, ticketID: key, receiver: receiver)
                count = count + 1
            }
        }

        // Redeem a specific ticket instead of all of a certain type.
        pub fun redeem(type: Type, ticketID: UInt64, receiver: Capability) {
            pre {
                receiver.address == self.redeemer: "receiver must match the redeemer of this shelf"
                self.bins.containsKey(type.identifier): "no bin for provided type"
            }

            let balanceBefore = FlowStorageFees.defaultTokenAvailableBalance(LostAndFound.account.address)

            let borrowedBin = self.borrowBin(type: type)!
            let ticket <- borrowedBin.withdrawTicket(ticketID: ticketID)
            ticket.withdraw(receiver: receiver)
            let refundCap = ticket.flowTokenRepayment
            destroy ticket

            if refundCap != nil && refundCap!.check() {
                let balanceAfter = FlowStorageFees.defaultTokenAvailableBalance(LostAndFound.account.address)
                let balanceDiff = balanceAfter - balanceBefore
                let refundProvider = LostAndFound.getFlowProvider()
                let repaymentVault <- refundProvider.withdraw(amount: balanceDiff)
                refundCap!.borrow()!.deposit(from: <-repaymentVault)
            }

            if borrowedBin.getTicketIDs().length == 0 {
                let bin <-! self.bins.remove(key: type.identifier)
                destroy bin
            }
        }

        destroy () {
            destroy <- self.bins
        }
    }

    access(contract) fun getFlowProvider(): &FlowToken.Vault{FungibleToken.Provider} {
        return self.account.borrow<&FlowToken.Vault{FungibleToken.Provider}>(from: /storage/flowTokenVault)!
    }

    // ShelfManager is a light-weight wrapper to get our shelves into storage.
    pub resource ShelfManager {
        access(self) let shelves: @{Address: Shelf}

        init() {
            self.shelves <- {}
        }

        pub fun deposit(
            redeemer: Address,
            item: @AnyResource,
            memo: String?,
            display: MetadataViews.Display?,
            storagePayment: @FungibleToken.Vault,
            flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?
        ) {
            pre {
                flowTokenRepayment == nil || flowTokenRepayment!.check(): "flowTokenRepayment is not valid"
            }

            let balanceBefore = FlowStorageFees.defaultTokenAvailableBalance(LostAndFound.account.address)

            // check if there is a shelf for this user
            if !self.shelves.containsKey(redeemer) {
                let oldValue <- self.shelves.insert(key: redeemer, <- create Shelf(redeemer: redeemer))
                destroy oldValue
            }
            let ticket <- create Ticket(item: <-item, memo: memo, display: display, redeemer: redeemer, flowTokenRepayment: flowTokenRepayment)
            let shelf = self.borrowShelf(redeemer: redeemer)
            shelf!.deposit(ticket: <-ticket)

            let balanceAfter = FlowStorageFees.defaultTokenAvailableBalance(LostAndFound.account.address)
            let balanceDiff = balanceBefore - balanceAfter
            let storagePaymentVault <- storagePayment.withdraw(amount: balanceDiff)
            let receiver = LostAndFound.account
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()!
            
            receiver.deposit(from: <-storagePaymentVault)

            if storagePayment.balance > 0.0 {
                if flowTokenRepayment != nil {
                    flowTokenRepayment!.borrow()!.deposit(from: <-storagePayment)
                } else {
                    receiver.deposit(from: <-storagePayment)
                }
            } else {
                destroy storagePayment
            }
        }

        pub fun borrowShelf(redeemer: Address): &LostAndFound.Shelf? {
            return &self.shelves[redeemer] as &LostAndFound.Shelf?
        }

        // deleteShelf
        //
        // delete a shelf if it has no redeemable types
        pub fun deleteShelf(_ addr: Address) {
            assert(self.shelves.containsKey(addr), message: "shelf does not exist")            
            let shelf <- self.shelves[addr] <- nil

            assert(shelf?.getRedeemableTypes()?.length! == 0, message: "shelf still has redeemable types")
            destroy shelf
        }

        destroy () {
            destroy <-self.shelves
        }
    }

    pub resource interface DepositerPublic {
        pub fun balance(): UFix64
        pub fun addFlowTokens(vault: @FlowToken.Vault)
    }

    pub resource Depositer: DepositerPublic {
        access(self) let flowTokenVault: @FlowToken.Vault
        pub let flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

        pub fun deposit(
            redeemer: Address,
            item: @AnyResource,
            memo: String?,
            display: MetadataViews.Display?
        ) {
            let depositEstimate <- LostAndFound.estimateDeposit(redeemer: redeemer, item: <-item, memo: memo, display: display)
            let storagePayment <- self.withdrawTokens(amount: depositEstimate.storageFee)
            let resource <- depositEstimate.withdraw()

            let shelfManager = LostAndFound.borrowShelfManager()
            shelfManager.deposit(redeemer: redeemer, item: <-resource, memo: memo, display: display, storagePayment: <-storagePayment, flowTokenRepayment: self.flowTokenRepayment)

            destroy depositEstimate
        }

            pub fun trySendResource(
                item: @AnyResource,
                cap: Capability,
                memo: String?,
                display: MetadataViews.Display?
        ) {
            let depositEstimate <- LostAndFound.estimateDeposit(redeemer: cap.address, item: <-item, memo: memo, display: display)
            let storagePayment <- self.withdrawTokens(amount: depositEstimate.storageFee)
            let resource <- depositEstimate.withdraw()

            LostAndFound.trySendResource(
                resource: <-resource,
                cap: cap,
                memo: memo,
                display: display,
                storagePayment: <-storagePayment,
                flowTokenRepayment: self.flowTokenRepayment
            )

            destroy depositEstimate
        }

        pub fun withdrawTokens(amount: UFix64): @FungibleToken.Vault {
            let tokens <-self.flowTokenVault.withdraw(amount: amount)
            emit DepositerTokensWithdrawn(uuid: self.uuid, tokens: amount, balance: self.flowTokenVault.balance)
            return <-tokens
        }

        pub fun addFlowTokens(vault: @FlowToken.Vault) {
            let tokensAdded = vault.balance
            self.flowTokenVault.deposit(from: <-vault)
            emit DepositerTokensAdded(uuid: self.uuid, tokens: tokensAdded, balance: self.flowTokenVault.balance)
        }

        pub fun balance(): UFix64 {
            return self.flowTokenVault.balance
        }

        init(_ flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
            self.flowTokenRepayment = flowTokenRepayment

            let vault <- FlowToken.createEmptyVault()
            self.flowTokenVault <- vault as! @FlowToken.Vault
        }

        destroy() {
            self.flowTokenRepayment.borrow()!.deposit(from: <-self.flowTokenVault)
        }
    }

    pub fun createDepositer(_ flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>): @Depositer {
        let depositer <- create Depositer(flowTokenRepayment)
        emit DepositerCreated(uuid: depositer.uuid)
        return <- depositer
    }

    pub fun borrowShelfManager(): &LostAndFound.ShelfManager {
        return self.account.getCapability<&LostAndFound.ShelfManager>(LostAndFound.LostAndFoundPublicPath).borrow()!
    }

    pub fun borrowAllTicketsByType(addr: Address, type: Type): [&LostAndFound.Ticket] {
        let manager = LostAndFound.borrowShelfManager()
        let shelf = manager.borrowShelf(redeemer: addr)
        if shelf == nil {
            return []
        }

        let bin = shelf!.borrowBin(type: type)
        if bin == nil {
            return []
        }

        return bin!.borrowAllTicketsByType()
    }

    pub fun borrowAllTickets(addr: Address): [&LostAndFound.Ticket] {
        let manager = LostAndFound.borrowShelfManager()
        let shelf = manager.borrowShelf(redeemer: addr)
        if shelf == nil {
            return []
        }

        let types = shelf!.getRedeemableTypes()
        let allTickets = [] as [&LostAndFound.Ticket]

        for type in types {
            let tickets = LostAndFound.borrowAllTicketsByType(addr: addr, type: type)
            allTickets.appendAll(tickets)
        }

        return allTickets
    }

    pub fun redeemAll(type: Type, max: Int?, receiver: Capability) {
        let manager = LostAndFound.borrowShelfManager()
        let shelf = manager.borrowShelf(redeemer: receiver.address)
        assert(shelf != nil, message: "shelf not found")

        shelf!.redeemAll(type: type, max: max, receiver: receiver)
        let remainingTypes = shelf!.getRedeemableTypes()
        if remainingTypes.length == 0 {
            manager.deleteShelf(receiver.address)
        }
    }

    pub fun estimateDeposit(
        redeemer: Address,
        item: @AnyResource,
        memo: String?,
        display: MetadataViews.Display?
    ): @DepositEstimate {
        // is there already a shelf?
        let manager = LostAndFound.borrowShelfManager()
        let shelf = manager.borrowShelf(redeemer: redeemer)
        var shelfFee = 0.0
        var binFee = 0.0
        if shelf == nil {
            shelfFee = 0.00001
            binFee = 0.00001
        } else {
            let bin = shelf!.borrowBin(type: item.getType())
            if bin == nil {
                binFee = 0.00001
            }
        }
        

        let balanceBefore = FlowStorageFees.defaultTokenAvailableBalance(redeemer)
        let ftReceiver = LostAndFound.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let ticket <- create LostAndFound.Ticket(item: <-item, memo: memo, display: display, redeemer: redeemer, flowTokenRepayment: ftReceiver)
        LostAndFound.account.save(<-ticket, to: /storage/temp)
        let balanceAfter = FlowStorageFees.defaultTokenAvailableBalance(redeemer)
        
         // add a small buffer because storage fees can vary
        let storageFee = ((balanceBefore - balanceAfter) + shelfFee + binFee) * 1.01
        let loadedTicket <- LostAndFound.account.load<@AnyResource>(from: /storage/temp)! as! @LostAndFound.Ticket
        let resource <- loadedTicket.takeItem()
        destroy loadedTicket
        let estimate <- create DepositEstimate(item: <-resource, storageFee: storageFee)
        return <- estimate
    }

    pub fun getRedeemableTypes(_ addr: Address): [Type] {
        let manager = LostAndFound.borrowShelfManager()
        let shelf = manager.borrowShelf(redeemer: addr)
        if shelf == nil {
            return []
        }

        return shelf!.getRedeemableTypes()
    }

    pub fun deposit(
        redeemer: Address,
        item: @AnyResource,
        memo: String?,
        display: MetadataViews.Display?,
        storagePayment: @FungibleToken.Vault,
        flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?
    ) {
        pre {
            flowTokenRepayment == nil || flowTokenRepayment!.check(): "flowTokenRepayment is not valid"
        }

        let shelfManager = LostAndFound.borrowShelfManager()
        shelfManager.deposit(redeemer: redeemer, item: <-item, memo: memo, display: display, storagePayment: <-storagePayment, flowTokenRepayment: flowTokenRepayment)
    }

    pub fun trySendResource(
        resource: @AnyResource,
        cap: Capability,
        memo: String?,
        display: MetadataViews.Display?,
        storagePayment: @FungibleToken.Vault,
        flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    ) {
        if cap.check<&{NonFungibleToken.CollectionPublic}>() {
            let nft <- resource as! @NonFungibleToken.NFT
            cap.borrow<&{NonFungibleToken.CollectionPublic}>()!.deposit(token: <-nft)
            flowTokenRepayment.borrow()!.deposit(from: <-storagePayment)
        } else if cap.check<&{NonFungibleToken.Receiver}>() {
            let nft <- resource as! @NonFungibleToken.NFT
            cap.borrow<&{NonFungibleToken.Receiver}>()!.deposit(token: <-nft)
            flowTokenRepayment.borrow()!.deposit(from: <-storagePayment)
        } else if cap.check<&{FungibleToken.Receiver}>() {
            let vault <- resource as! @FungibleToken.Vault
            cap.borrow<&{FungibleToken.Receiver}>()!.deposit(from: <-vault)
            flowTokenRepayment.borrow()!.deposit(from: <-storagePayment)
        } else {
            LostAndFound.deposit(redeemer: cap.address, item: <-resource, memo: memo, display: display, storagePayment: <-storagePayment, flowTokenRepayment: flowTokenRepayment)
        }
    }

    init() {
        self.LostAndFoundPublicPath = /public/lostAndFound
        self.LostAndFoundStoragePath = /storage/lostAndFound
        self.DepositerPublicPath = /public/lostAndFoundDepositer
        self.DepositerStoragePath = /storage/lostAndFoundDepositer

        let manager <- create ShelfManager()
        self.account.save(<-manager, to: self.LostAndFoundStoragePath)
        self.account.link<&LostAndFound.ShelfManager>(self.LostAndFoundPublicPath, target: self.LostAndFoundStoragePath)
    }
}
