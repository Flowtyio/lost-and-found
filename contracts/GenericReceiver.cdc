import "LostAndFound"

access(all) contract GenericReceiver {
    access(all) let ReceiverStoragePath: StoragePath

    access(all) resource Receiver: LostAndFound.AnyResourceReceiver {
        access(self) let items: @{UInt64: AnyResource}

        access(LostAndFound.Deposit) fun deposit(item: @AnyResource) {
            destroy self.items.insert(key: item.uuid, <-item)
        }

        init() {
            self.items <- {}
        }
    }

    access(all) fun createReceiver(): @Receiver {
        return <- create Receiver()
    }

    init() {
        self.ReceiverStoragePath = /storage/AnyResourceReceiver
    }
}