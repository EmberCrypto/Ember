include MainMerit

#Creates and publishes a Verification.
proc verify(entry: Entry) {.raises: [
    KeyError,
    ValueError,
    AsyncError,
    FinalAttributeError
].} =
    #Make sure we're a Miner with Merit.
    if (miner) and (merit.state.getBalance(minerWallet.publicKey) > uint(0)):
        #Make sure we didn't already Verify an Entry at this position.
        if lattice.accounts[entry.sender].entries[int(entry.nonce)].len != 1:
            return

        #Verify the Entry.
        var verif: MemoryVerification = newMemoryVerification(entry.hash)
        minerWallet.sign(verif)

        #Discard lattice.verify because it is known to return true.
        discard lattice.verify(merit, verif)
        #Add the Verification to the unarchived set.
        lattice.unarchive(verif)

        #Broadcast the Verification.
        network.broadcast(
            newMessage(
                MessageType.Verification,
                verif.serialize()
            )
        )

proc mainLattice() {.raises: [
    ValueError,
    EventError,
    AsyncError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    {.gcsafe.}:
        #Create the Lattice.
        lattice = newLattice(
            TRANSACTION_DIFFICULTY,
            DATA_DIFFICULTY
        )

        #Handle requests for an account's height.
        events.on(
            "lattice.getHeight",
            proc (account: string): uint {.raises: [ValueError].} =
                lattice.getAccount(account).height
        )

        #Handle requests for an account's balance.
        events.on(
            "lattice.getBalance",
            proc (account: string): BN {.raises: [ValueError].} =
                lattice.getAccount(account).balance
        )

        #Handle requests for an Entry.
        events.on(
            "lattice.getEntryByHash",
            proc (hash: string): Entry {.raises: [KeyError, ValueError].} =
                lattice[hash]
        )
        events.on(
            "lattice.getEntryByIndex",
            proc (index: Index): Entry {.raises: [ValueError].} =
                lattice[index]
        )

        #Handle requests for the Unarchived Verifications.
        events.on(
            "lattice.getUnarchivedVerifications",
            proc (): seq[MemoryVerification] =
                lattice.unarchived
        )

        #Handle Claims.
        events.on(
            "lattice.claim",
            proc (claim: Claim): bool {.raises: [
                ValueError,
                AsyncError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Claim."

                #Add the Claim.
                if lattice.add(
                    merit,
                    claim
                ):
                    result = true
                    echo "Successfully added the Claim."

                    #Create a Verification.
                    verify(claim)
                else:
                    result = false
                    echo "Failed to add the Claim."
                echo ""
        )

        #Handle Sends.
        events.on(
            "lattice.send",
            proc (send: Send): bool {.raises: [
                ValueError,
                EventError,
                AsyncError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Send."

                #Add the Send.
                if lattice.add(
                    merit,
                    send
                ):
                    result = true
                    echo "Successfully added the Send."

                    #Create a Verification.
                    verify(send)

                    #If the Send is for us, Receive it.
                    if wallet != nil:
                        if send.output == wallet.address:
                            #Create the Receive.
                            var recv: Receive = newReceive(
                                newIndex(
                                    send.sender,
                                    send.nonce
                                ),
                                lattice.getAccount(wallet.address).height
                            )
                            #Sign it.
                            wallet.sign(recv)

                            try:
                                #Emit it.
                                if events.get(
                                    proc (recv: Receive): bool,
                                    "lattice.receive"
                                )(recv):
                                    #Broadcast it.
                                    network.broadcast(
                                        newMessage(
                                            MessageType.Receive,
                                            recv.serialize()
                                        )
                                    )
                            except:
                                raise newException(EventError, "Couldn't get and call lattice.receive.")
                else:
                    result = false
                    echo "Failed to add the Send."
                echo ""
        )

        #Handle Receives.
        events.on(
            "lattice.receive",
            proc (recv: Receive): bool {.raises: [
                ValueError,
                AsyncError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Receive."

                #Add the Receive.
                if lattice.add(
                    merit,
                    recv
                ):
                    result = true
                    echo "Successfully added the Receive."

                    #Create a Verification.
                    verify(recv)
                else:
                    result = false
                    echo "Failed to add the Receive."
                echo ""
        )

        #Handle Data.
        events.on(
            "lattice.data",
            proc (data: Data): bool {.raises: [
                ValueError,
                AsyncError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Data."

                #Add the Data.
                if lattice.add(
                    merit,
                    data
                ):
                    result = true
                    echo "Successfully added the Data."

                    #Create a Verification.
                    verify(data)
                else:
                    result = false
                    echo "Failed to add the Data."
                echo ""
        )
