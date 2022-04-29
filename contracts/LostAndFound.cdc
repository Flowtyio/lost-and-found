import FlowToken from "./standard/FlowToken.cdc"
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

    // Empty resource so we can unwrap ticket items for deposits to their corresponding receiver.
    pub resource DummyResource {
        init() { }
    }

    // TicketPublic - Helper functions to redeem tickets and get information about them
    pub resource interface TicketPublic {
        // Borrow the underlying item in a ticket
        pub fun borrowItem(): &AnyResource?
        // Return the address that is approved to redeem this ticket
        pub fun getRedeemer(): Address
        // A ticket can onlyl be redeemed once
        pub fun isRedeemed(): Bool
        // Cast this ticket's item into NonFungibleToken.NFT and deposit it into an NFT Receiver
        pub fun withdrawToNFTReceiver(receiver: Capability<&{NonFungibleToken.CollectionPublic}>)
        // Cast this ticket's item into FungibleToken.Vault and deposit it into an FungibleToken Receiver
        pub fun withdrawToFTReceiver(receiver: Capability<&{FungibleToken.Receiver}>)
        // Deposit the ticker's item as it into a receiver that accepts AnyResource
        pub fun withdrawToAnyResourceReceiver(receiver: Capability<&{LostAndFound.AnyResourceReceiver}>)
    }

    // Tickets are the resource that hold items to be redeemed. They carry with them:
    // - item: The Resource which has been deposited to be withdrawn/redeemed
    // - memo: An optional message to attach to this ticket
    // - redeemer: The address which is allowed to withdraw the item from this ticket
    // - redeemed: Whether the ticket has been redeemed. This can only be set by the LostAndFound contract
    pub resource Ticket: TicketPublic {
        // The item to be redeemed
        pub var item: @AnyResource
        // An optional message to attach to this item.
        pub let memo: String?
        // The address that it allowed to withdraw the item fromt this ticket
        pub let redeemer: Address

        // State maintained by LostAndFound
        pub var redeemed: Bool

        init (item: @AnyResource, memo: String?, redeemer: Address) {
            self.item <- item
            self.memo = memo
            self.redeemer = redeemer

            self.redeemed = false
        }

        // used when an item is withdrawn, ensures that the ticket is only redeemed one time
        access(contract) fun setIsRedeemed() {
            self.redeemed = true
        }
        
        pub fun getRedeemer(): Address {
            return self.redeemer
        }

        pub fun borrowItem(): &AnyResource? {            
            if self.item == nil {
                return nil
            }
            
            return &self.item as! &AnyResource
        }

        pub fun isRedeemed(): Bool {
            return self.redeemed
        }


        pub fun withdrawToNFTReceiver(receiver: Capability<&{NonFungibleToken.CollectionPublic}>) {
            pre {
                receiver.address == self.redeemer: "receiver address and redeemer must match"
                receiver.check(): "receiver check failed"
            }


            // Indiana Jones swap the item in our ticket so we can deposit it
            var redeemableItem <- create LostAndFound.DummyResource() as @AnyResource
            redeemableItem <-> self.item
            
            emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
            let token <- redeemableItem as! @NonFungibleToken.NFT
            receiver.borrow()!.deposit(token: <- token)
            self.setIsRedeemed()
        }

        pub fun withdrawToFTReceiver(receiver: Capability<&{FungibleToken.Receiver}>) {
            pre {
                receiver.address == self.redeemer: "receiver address and redeemer must match"
                receiver.check(): "receiver check failed"
            }

            // Indiana Jones swap the item in our ticket so we can deposit it
            var redeemableItem <- create LostAndFound.DummyResource() as @AnyResource
            redeemableItem <-> self.item

            emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
            let token <- redeemableItem as! @FungibleToken.Vault
            receiver.borrow()!.deposit(from: <-token)
            self.setIsRedeemed()
        }

        pub fun withdrawToAnyResourceReceiver(receiver: Capability<&{LostAndFound.AnyResourceReceiver}>) {
            pre {
                receiver.address == self.redeemer: "receiver address and redeemer must match"
                receiver.check(): "receiver check failed"
            }

            // Indiana Jones swap the item in our ticket so we can deposit it
            var redeemableItem <- create LostAndFound.DummyResource() as @AnyResource
            redeemableItem <-> self.item

            emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
            receiver.borrow()!.deposit(resource: <-redeemableItem)
            self.setIsRedeemed()
        }

        // destricton is only allowed if the ticket has been redeemed and the underlying item is a our dummy resource
        destroy () {
            pre {
                self.redeemed: "Ticket has not been redeemed"
                self.item.isInstance(Type<@LostAndFound.DummyResource>()): "can only destroy if dummy resource"
            }

            destroy <-self.item
        }
    }

    pub resource interface BinPublic {
        pub fun borrowTicket(id: UInt64): &LostAndFound.Ticket{LostAndFound.TicketPublic}
        pub fun getTicketIDs(): [UInt64]
        pub fun destroyTicket(ticketID: UInt64)
    }

    // A Bin is a resource that gathers tickets whos item have the same type.
    // For instance, if two TopShot Moments are deposited to the same redeemer, only one bin
    // will be made which will contain both tickets to redeem each individual moment.
    pub resource Bin {
        pub let tickets: @{UInt64:Ticket}
        pub let type: Type

        init (type: Type) {
            self.tickets <- {}
            self.type = type
        }

        pub fun borrowTicket(id: UInt64): &LostAndFound.Ticket{LostAndFound.TicketPublic} {
            return &self.tickets[id] as &LostAndFound.Ticket{LostAndFound.TicketPublic}
        }

        // deposit a ticket to this bin. The item type must match this bin's item type.
        pub fun deposit(ticket: @LostAndFound.Ticket) {
            pre {
                ticket.item.getType() == self.type: "ticket and bin types must match"
            }

            let redeemer = ticket.getRedeemer()
            let ticketID = ticket.uuid

            self.tickets[ticket.uuid] <-! ticket
            emit TicketDeposited(redeemer: redeemer, ticketID: ticketID, type: self.type)
        }

        pub fun getTicketIDs(): [UInt64] {
            return self.tickets.keys
        }

        pub fun destroyTicket(ticketID: UInt64) {
            let ticket <- self.tickets.remove(key: ticketID)
            destroy ticket
        }

        destroy () {
            destroy <-self.tickets
        }
    }

    pub resource interface ShelfPublic {
        pub fun getOwner(): Address
        pub fun getRedeemableTypes(): [Type]
        pub fun hasType(type: Type): Bool
        pub fun deposit(ticket: @LostAndFound.Ticket)
        pub fun borrowBin(type: Type): &LostAndFound.Bin?

        pub fun redeemAll(
            type: Type,
            max: Int?,
            nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        )
        pub fun redeem(
            type: Type,
            ticketID: UInt64,
            nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        )
    }

    // A shelf is our top-level organization resource.
    // It groups bins by redeemer to help make discovery of the assets that a
    // redeeming address can claim. 
    pub resource Shelf: ShelfPublic {
        pub let bins: @{String: Bin}
        pub let identifierToType: {String: Type}
        pub let redeemer: Address

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

            let binPublic = self.borrowBin(type: type)!
            binPublic.deposit(ticket: <-ticket)
        }

        // Redeem all the tickets of a given type. This is just a convenience function
        // so that a redeemer doesn't have to coordinate redeeming each ticket individually
        // Only one of the three receiver options can be specified, and an optional maximum number of tickets
        // to redeem can be picked to prevent gas issues in case there are large numbers of tickets to be
        // redeemed at once.
        pub fun redeemAll(
            type: Type,
            max: Int?,
            nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?,
        ) {
            pre {
                (nftReceiver != nil && ftReceiver == nil && anyResourceReceiver == nil) || 
                (nftReceiver == nil && ftReceiver != nil && anyResourceReceiver == nil) || 
                (nftReceiver == nil && ftReceiver == nil && anyResourceReceiver != nil): "Can only provide one receiver"
                nftReceiver == nil || nftReceiver!.address == self.redeemer: "receiver must match the redeemer of this shelf"
                ftReceiver == nil || ftReceiver!.address == self.redeemer: "receiver must match the redeemer of this shelf"
                anyResourceReceiver == nil || anyResourceReceiver!.address == self.redeemer: "receiver must match the redeemer of this shelf"
                self.bins.containsKey(type.identifier): "no bin for provided type"
            }

            var count = 0
            for key in self.borrowBin(type: type)!.getTicketIDs() {
                if max != nil && max == count {
                    return 
                }

                self._redeemTicket(type: type, ticketID: key, nftReceiver: nftReceiver, ftReceiver: ftReceiver, anyResourceReceiver: anyResourceReceiver)
                count = count + 1
            }
        }

        // Redeem a specific ticket instead of all of a certain type.
        pub fun redeem(
            type: Type,
            ticketID: UInt64,
            nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        ) {
            pre {
                nftReceiver != nil && ftReceiver == nil && anyResourceReceiver == nil: "Can only provide one receiver"
                nftReceiver == nil || nftReceiver!.address == self.redeemer: "receiver must match the redeemer of this shelf"
                ftReceiver == nil || ftReceiver!.address == self.redeemer: "receiver must match the redeemer of this shelf"
                anyResourceReceiver == nil || anyResourceReceiver!.address == self.redeemer: "receiver must match the redeemer of this shelf"
                self.bins.containsKey(type.identifier): "no bin for provided type"
            }
            
            self._redeemTicket(type: type, ticketID: ticketID, nftReceiver: nftReceiver, ftReceiver: ftReceiver, anyResourceReceiver: anyResourceReceiver)
        }


        // the internal redmption mechanic to join together the two different ways of redeeming (all of them or by ticketID)
        access(self) fun _redeemTicket(
            type: Type,
            ticketID: UInt64,
            nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        ) {
            let binPublic = self.borrowBin(type: type)!
            let ticket = binPublic.borrowTicket(id: ticketID)
            if ticket.getType() == Type<@LostAndFound.DummyResource>() {
                binPublic.destroyTicket(ticketID: ticketID)
                return 
            }

            if nftReceiver != nil {
                ticket.withdrawToNFTReceiver(receiver: nftReceiver!)
            }
            
            if ftReceiver != nil {
                ticket.withdrawToFTReceiver(receiver: ftReceiver!)
            }
            
            if anyResourceReceiver != nil {
                ticket.withdrawToAnyResourceReceiver(receiver: anyResourceReceiver!)
            }

            binPublic.destroyTicket(ticketID: ticketID)
        }

        destroy () {
            destroy <- self.bins
        }
    }

    pub resource interface ShelfManagerPublic {
        pub fun deposit(redeemer: Address, item: @AnyResource, memo: String?)
        pub fun borrowShelf(redeemer: Address): &LostAndFound.Shelf
    }

    // ShelfManager is a light-weight wrapper to get our shelves into storage.
    pub resource ShelfManager: ShelfManagerPublic {
        access(self) let shelves: @{Address: Shelf}

        init() {
            self.shelves <- {}
        }

        pub fun deposit(redeemer: Address, item: @AnyResource, memo: String?) {
            // check if there is a shelf for this user
            if !self.shelves.containsKey(redeemer) {
                let oldValue <- self.shelves.insert(key: redeemer, <- create Shelf(redeemer: redeemer))
                destroy oldValue
            }

            let ticket <- create Ticket(item: <-item, memo: memo, redeemer: redeemer)

            let shelfPublic = self.borrowShelf(redeemer: redeemer)
            shelfPublic.deposit(ticket: <-ticket)
        }

        pub fun borrowShelf(redeemer: Address): &LostAndFound.Shelf {
            return &self.shelves[redeemer] as &LostAndFound.Shelf
        }

        destroy () {
            destroy <-self.shelves
        }
    }

    pub fun borrowShelfManagerPublic(): &LostAndFound.ShelfManager{LostAndFound.ShelfManagerPublic} {
        return self.account.getCapability<&LostAndFound.ShelfManager{LostAndFound.ShelfManagerPublic}>(LostAndFound.LostAndFoundPublicPath).borrow()!
    }

    init() {
        self.LostAndFoundPublicPath = /public/lostAndFound
        self.LostAndFoundStoragePath = /storage/lostAndFound

        let manager <- create ShelfManager()
        self.account.save(<-manager, to: self.LostAndFoundStoragePath)
        self.account.link<&LostAndFound.ShelfManager{LostAndFound.ShelfManagerPublic}>(self.LostAndFoundPublicPath, target: self.LostAndFoundStoragePath)
    }
}