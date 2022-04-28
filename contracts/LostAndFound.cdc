import FlowToken from "./standard/FlowToken.cdc"
import FungibleToken from "./standard/FungibleToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"

pub contract LostAndFound {
    // TODO: move shelves to storage instead of being on the contract itself
    access(contract) let shelves: @{Address: Shelf}

    pub event TicketDeposited(redeemer: Address, ticketID: UInt64, type: Type)
    pub event TicketRedeemed(redeemer: Address, ticketID: UInt64, type: Type)

    pub resource interface AnyResourceReceiver {
        pub fun deposit(resource: @AnyResource)
    }

    pub resource DummyResource {
        init() { }
    }

    pub resource interface TicketPublic {
        pub fun borrowItem(): &AnyResource?
        pub fun getRedeemer(): Address
        pub fun isRedeemed(): Bool
        pub fun withdrawToNFTReceiver(receiver: Capability<&{NonFungibleToken.Receiver}>)
        pub fun withdrawToFTReceiver(receiver: Capability<&{FungibleToken.Receiver}>)
        pub fun withdrawToAnyResourceReceiver(receiver: Capability<&{LostAndFound.AnyResourceReceiver}>)
    }

    pub resource Ticket: TicketPublic {
        pub var item: @AnyResource
        pub let memo: String?
        pub let redeemer: Address

        // State maintained by LostAndFound
        pub var redeemed: Bool

        init (item: @AnyResource, memo: String?, redeemer: Address) {
            self.item <- item
            self.memo = memo
            self.redeemer = redeemer

            self.redeemed = false
        }

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


        pub fun withdrawToNFTReceiver(receiver: Capability<&{NonFungibleToken.Receiver}>) {
            pre {
                receiver.address == self.redeemer: "receiver address and redeemer must match"
                receiver.check(): "receiver check failed"
            }


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

            var redeemableItem <- create LostAndFound.DummyResource() as @AnyResource
            redeemableItem <-> self.item

            emit TicketRedeemed(redeemer: self.redeemer, ticketID: self.uuid, type: redeemableItem.getType())
            receiver.borrow()!.deposit(resource: <-redeemableItem)
            self.setIsRedeemed()
        }

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
            nftReceiver: Capability<&{NonFungibleToken.Receiver}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        )
        pub fun redeem(
            type: Type,
            ticketID: UInt64,
            nftReceiver: Capability<&{NonFungibleToken.Receiver}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        )
    }

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

        pub fun redeemAll(
            type: Type,
            max: Int?,
            nftReceiver: Capability<&{NonFungibleToken.Receiver}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?,
        ) {
            pre {
                nftReceiver != nil && ftReceiver == nil && anyResourceReceiver == nil: "Can only provide one receiver"
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

        pub fun redeem(
            type: Type,
            ticketID: UInt64,
            nftReceiver: Capability<&{NonFungibleToken.Receiver}>?, 
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


        access(self) fun _redeemTicket(
            type: Type,
            ticketID: UInt64,
            nftReceiver: Capability<&{NonFungibleToken.Receiver}>?, 
            ftReceiver: Capability<&{FungibleToken.Receiver}>?, 
            anyResourceReceiver:Capability<&{LostAndFound.AnyResourceReceiver}>?
        ) {
            let binPublic = self.borrowBin(type: type)!
            let ticket = binPublic.borrowTicket(id: ticketID)

            if nftReceiver != nil {
                ticket.withdrawToNFTReceiver(receiver: nftReceiver!)
            }
            
            if ftReceiver != nil {
                ticket.withdrawToFTReceiver(receiver: ftReceiver!)
            }
            
            if anyResourceReceiver != nil {
                ticket.withdrawToAnyResourceReceiver(receiver: anyResourceReceiver!)
            }
        }

        destroy () {
            destroy <- self.bins
        }
    }

    pub fun deposit(redeemer: Address, item: @AnyResource, memo: String?) {
        // check if there is a shelf for this user
        if !LostAndFound.shelves.containsKey(redeemer) {
            let oldValue <- LostAndFound.shelves.insert(key: redeemer, <- create Shelf(redeemer: redeemer))
            destroy oldValue
        }

        let ticket <- create Ticket(item: <-item, memo: memo, redeemer: redeemer)

        let shelfPublic = LostAndFound.borrowShelf(redeemer: redeemer)
        shelfPublic.deposit(ticket: <-ticket)
    }

    pub fun borrowShelf(redeemer: Address): &LostAndFound.Shelf {
        return &self.shelves[redeemer] as &LostAndFound.Shelf
    }

    init() {
        self.shelves <- {}

    }
}