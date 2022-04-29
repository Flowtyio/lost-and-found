# LostAndFound
Giving items to users who are not configured for a given resource type
is challenging on flow. Many applications have to either not allow users 
to receive assets, or they have to come up with their own escrow 
solution.

LostAndFound is a contract meant to solve this issue so other 
applications do not need to. It organizes items that users can redeem based on the type of the asset. This should make it easy for apps to 
integrate with that they can own allowing users to claim their items in the LostAndFound. 

## Structure
This contract is organized into a few key components:

### Shelf
A shelf is our high-level organizer. There is one shelf per redeemable address.

A shelf has an array of Bins (covered later), and an associated address. Only that address can claim items on that shelf.
There is only one shelf allowed per address

### Bin
Bins exist on Shelf Resources. A bin consists of an array of Tickets (covered later) and an associated type.
All Items deposited to a shelf are routed to their type's bin. For instance, if I send an account USDC tokens, 
a bin corresponding to the USDC vault (FiatToken.Vault) would be made, and all subsequent deposits of FiatToken.Vault
types would be routed to that same bin. 

If a bin is emptied of all its Tickets, it can be destroyed and a new one would be made once that type is deposited again.

### Ticket
Tickets are the resource that contain our deposited items to be redeemed by other accounts. A ticket has an item which represents
the resource being deposited, a redeemer address, and a memo in case the depositer would like to send a message to the redeemer

### ShelfManager
The ShelfManager is a light wrapper around our stored shelves. It exposes a means to borrow shelves so that redeemers can withdraw
items that have been sent to them, and another helper to deposit items to a redeemer. 

## Usage

TODO: Put in example transactions here