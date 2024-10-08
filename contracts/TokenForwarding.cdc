/**

# Fungible Token Forwarding Contract

This contract shows how an account could set up a custom FungibleToken Receiver
to allow them to forward tokens to a different account whenever they receive tokens.

They can publish this Forwarder resource as a Receiver capability just like a Vault,
and the sender doesn't even need to know it is different.

When an account wants to create a Forwarder, they call the createNewForwarder
function and provide it with the Receiver reference that they want to forward
their tokens to.

*/

import "FungibleToken"

access(all) contract TokenForwarding {

    // Event that is emitted when tokens are deposited to the target receiver
    access(all) event ForwardedDeposit(amount: UFix64, from: Address?)

    access(all) resource interface ForwarderPublic {
        access(all) fun check(): Bool
        access(all) fun safeBorrow(): &{FungibleToken.Receiver}?
    }

    access(all) resource Forwarder: FungibleToken.Receiver, ForwarderPublic {

        // This is where the deposited tokens will be sent.
        // The type indicates that it is a reference to a receiver
        //
        access(self) var recipient: Capability

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {}
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return true
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and forwards
        // it to the recipient's Vault using the stored reference
        //
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let receiverRef = self.recipient.borrow<&{FungibleToken.Receiver}>()!

            let balance = from.balance

            receiverRef.deposit(from: <-from)

            emit ForwardedDeposit(amount: balance, from: self.owner?.address)
        }

        access(all) fun check(): Bool {
            return self.recipient.check<&{FungibleToken.Receiver}>()
        }

        access(all) fun safeBorrow(): &{FungibleToken.Receiver}? {
            return self.recipient.borrow<&{FungibleToken.Receiver}>()
        }

        // changeRecipient changes the recipient of the forwarder to the provided recipient
        //
        access(all) fun changeRecipient(_ newRecipient: Capability) {
            pre {
                newRecipient.borrow<&{FungibleToken.Receiver}>() != nil: "Could not borrow Receiver reference from the Capability"
            }
            self.recipient = newRecipient
        }

        init(recipient: Capability) {
            pre {
                recipient.borrow<&{FungibleToken.Receiver}>() != nil: "Could not borrow Receiver reference from the Capability"
            }
            self.recipient = recipient
        }
    }

    // createNewForwarder creates a new Forwarder reference with the provided recipient
    //
    access(all) fun createNewForwarder(recipient: Capability): @Forwarder {
        return <-create Forwarder(recipient: recipient)
    }
}
 