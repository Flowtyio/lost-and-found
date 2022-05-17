import FlowToken from "./standard/FlowToken.cdc"
import FlowStorageFees from "./standard/FlowStorageFees.cdc"
import FungibleToken from "./standard/FungibleToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"

// LostAndFound
// One big problem on the flow blockchain is how to handle accounts that are
// not configured to receive assets that you want to send. Currently, 
// Lots of platforms have to create their own escrow for people to redeem. IF not an
// escrow, accounts might instead be skipped on things like an airtdrop
// because they aren't able to reeive the assets they should have gotten.
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

    pub event TicketDeposited(redeemer: Address, ticketID: UInt64, type: Type)
    pub event TicketRedeemed(redeemer: Address, ticketID: UInt64, type: Type)

    // Placeholder receiver so that any resource can be supported, not just FT and NFT Receivers
    pub resource interface AnyResourceReceiver {
        pub fun deposit(resource: @AnyResource)
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
        // The address that it allowed to withdraw the item fromt this ticket
        pub let redeemer: Address
        // State maintained by LostAndFound
        pub var redeemed: Bool
        
        // flow token amount used to store this ticket is returned when the ticket is redeemed
        access(contract) let flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?

        init (item: @AnyResource, memo: String?, redeemer: Address, flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?) {
            self.item <- item
            self.memo = memo
            self.redeemer = redeemer
            self.redeemed = false

            self.flowTokenRepayment = flowTokenRepayment
        }

        pub fun borrowItem(): &AnyResource? {                
            if self.item == nil  {
                return nil
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
            }

            var redeemableItem <- self.item <- nil
            
            if redeemableItem.isInstance(Type<@NonFungibleToken.NFT>()) && receiver.check<&{NonFungibleToken.Receiver}>(){
                let target = receiver.borrow<&{NonFungibleToken.CollectionPublic}>()!
                let token <- redeemableItem  as! @NonFungibleToken.NFT
                self.redeemed = true
                emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: token.getType())
                target.deposit(token: <- token)
                return
            }    
            else if redeemableItem.isInstance(Type<@FungibleToken.Vault>()) && receiver.check<&{FungibleToken.Receiver}>(){
                let target = receiver.borrow<&{FungibleToken.Receiver}>()!
                let token <- redeemableItem as! @FungibleToken.Vault
                self.redeemed = true
                emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: token.getType())
                target.deposit(from: <- token)
                return
            }    
            else if receiver.check<&{LostAndFound.AnyResourceReceiver}>(){
                let target = receiver.borrow<&{LostAndFound.AnyResourceReceiver}>()!
                self.redeemed = true
                emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
                target.deposit(resource: <- redeemableItem)
                return
            }
            else{
                panic("cannot redeem resource to receiver")
            }    
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

        pub fun borrowTicket(id: UInt64): &LostAndFound.Ticket {
            return &self.tickets[id] as &LostAndFound.Ticket
        }

        // deposit a ticket to this bin. The item type must match this bin's item type.
        pub fun deposit(ticket: @LostAndFound.Ticket) {
            pre {
                ticket.item.getType() == self.type: "ticket and bin types must match"
            }

            let redeemer = ticket.redeemer
            let ticketID = ticket.uuid

            self.tickets[ticket.uuid] <-! ticket
            emit TicketDeposited(redeemer: redeemer, ticketID: ticketID, type: self.type)
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
                let t = self.identifierToType[k]
                if t != nil {
                    types.append(t!)
                }
            }
            return types
        }

        pub fun hasType(type: Type): Bool {
            return self.bins[type.identifier] != nil
        }

        pub fun borrowBin(type: Type): &LostAndFound.Bin? {
            return &self.bins[type.identifier] as &LostAndFound.Bin
        }

        pub fun deposit(ticket: @LostAndFound.Ticket) {
            // is there a bin for this yet?
            let type = ticket.item.getType()
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
            for key in self.borrowBin(type: type)!.getTicketIDs() {
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

            let bin = self.borrowBin(type: type)!
            let ticket <- bin.withdrawTicket(ticketID: ticketID)
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
        }
   
        destroy () {
            destroy <- self.bins
        }
    }

    access(contract) fun getFlowProvider(): &FlowToken.Vault{FungibleToken.Provider} {
        return self.account.borrow<&FlowToken.Vault{FungibleToken.Provider}>(from: /storage/flowTokenStorage)!
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
            storagePaymentProvider: Capability<&FlowToken.Vault{FungibleToken.Provider}>, 
            flowTokenRepayment: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?
        ) {
            pre {
                storagePaymentProvider.check(): "invalid storagePaymentProvider"
                flowTokenRepayment == nil || flowTokenRepayment!.check(): "flowTokenRepayment is not valid"
            }

            let balanceBefore = FlowStorageFees.defaultTokenAvailableBalance(LostAndFound.account.address)

            // check if there is a shelf for this user
            if !self.shelves.containsKey(redeemer) {
                let oldValue <- self.shelves.insert(key: redeemer, <- create Shelf(redeemer: redeemer))
                destroy oldValue
            }
            let ticket <- create Ticket(item: <-item, memo: memo, redeemer: redeemer, flowTokenRepayment: flowTokenRepayment)
            let shelf = self.borrowShelf(redeemer: redeemer)
            shelf.deposit(ticket: <-ticket)

            let balanceAfter = FlowStorageFees.defaultTokenAvailableBalance(LostAndFound.account.address)
            let balanceDiff = balanceBefore - balanceAfter
            let storagePaymentVault <- storagePaymentProvider.borrow()!.withdraw(amount: balanceDiff)
            LostAndFound.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()!
                .deposit(from: <-storagePaymentVault)
        }

        pub fun borrowShelf(redeemer: Address): &LostAndFound.Shelf {
            return &self.shelves[redeemer] as &LostAndFound.Shelf
        }

        destroy () {
            destroy <-self.shelves
        }
    }

    pub fun borrowShelfManager(): &LostAndFound.ShelfManager {
        return self.account.getCapability<&LostAndFound.ShelfManager>(LostAndFound.LostAndFoundPublicPath).borrow()!
    }

    init() {
        self.LostAndFoundPublicPath = /public/lostAndFound
        self.LostAndFoundStoragePath = /storage/lostAndFound

        let manager <- create ShelfManager()
        self.account.save(<-manager, to: self.LostAndFoundStoragePath)
        self.account.link<&LostAndFound.ShelfManager>(self.LostAndFoundPublicPath, target: self.LostAndFoundStoragePath)
    }
}