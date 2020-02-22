#Consensus Revert Test.

#Test lib.
import unittest

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#Wallet libs.
import ../../../src/Wallet/Wallet
import ../../../src/Wallet/MinerWallet

#VerificationPacket lib.
import ../../../src/Database/Consensus/Elements/VerificationPacket

#Merit lib.
import ../../../src/Database/Merit/Merit

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Transactions lib.
import ../../../src/Database/Transactions/Transactions

#Test Database lib.
import ../TestDatabase

#Test Merit lib.
import ../Merit/TestMerit

#Compare Consensus lib.
import CompareConsensus

#Random standard lib.
import random

#Sets standard lib.
import sets

#Tables standard lib.
import tables

suite "ConsensusRevert":
    setup:
        #Seed Random via the time.
        randomize(int64(getTime()))

        var
            initialSendDifficulty: Hash[256]
            initialDataDifficulty: Hash[256]
        for b in 0 ..< 32:
            initialSendDifficulty.data[b] = uint8(rand(255))
            initialDataDifficulty.data[b] = uint8(rand(255))

        var
            #Database.
            db: DB = newTestDatabase()

            #Merit.
            merit: Merit = newMerit(
                db,
                "CONSENSUS_REVERT_TEST",
                30,
                "".pad(32),
                100
            )

            #Transactions.
            transactions: Transactions = newTransactions(
                db,
                merit.blockchain
            )

            #Functions.
            functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr merit.blockchain, addr transactions)

            #Consensus.
            consensus: Consensus = newConsensus(
                functions,
                db,
                merit.state,
                initialSendDifficulty,
                initialDataDifficulty
            )

            #Merit Holders.
            holders: seq[MinerWallet] = @[
                newMinerWallet()
            ]

            #Wallets.
            wallets: seq[Wallet] = @[]
            #Reverse lookup Table.
            walletsLookup: Table[EdPublicKey, int] = initTable[EdPublicKey, int]()

            #Planned Sends.
            plans: Table[int, seq[seq[SendOutput]]] = initTable[int, seq[seq[SendOutput]]]()
            #Amount of Meros needed for the planned Sends.
            needed: Table[int, int64] = initTable[int, int64]()

            #Copy of Transactions.
            txs: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()
            #Height the Transaction appeared at.
            appeared: Table[Hash[256], int] = initTable[Hash[256], int]()
            #UTXOs.
            utxos: Table[EdPublicKey, seq[FundedInput]] = initTable[EdPublicKey, seq[FundedInput]]()
            #Data Tips.
            dataTips: Table[EdPublicKey, Hash[256]] = initTable[EdPublicKey, Hash[256]]()

            #Epochs.
            epochs: Table[Hash[256], int] = initTable[Hash[256], int]()
            #Finalized statuses.
            finalizedStatuses: Table[Hash[256], TransactionStatus] = initTable[Hash[256], TransactionStatus]()

            #Copy of the SpamFilters at every step.
            sendFilters: seq[SpamFilter] = @[]
            dataFilters: seq[SpamFilter] = @[]

            #Packets.
            packets: seq[VerificationPacket] = @[]
            #Elements.
            elements: seq[BlockElement] = @[]
            #New Block.
            newBlock: Block
            #Blocks.
            blocks: seq[Block]

            #Rewards.
            rewards: Table[Hash[256], seq[Reward]] = initTable[Hash[256], seq[Reward]]()

            #Existing Merit Removals.
            malicious: Table[uint16, seq[SignedMeritRemoval]] = initTable[uint16, seq[SignedMeritRemoval]]()

        #Add a Transaction.
        proc add(
            tx: Transaction,
            requireVerification: bool = false
        ) =
            #Store a copy of the Transaction and update the Data tip.
            txs[tx.hash] = tx
            if tx of Data:
                dataTips[transactions.getSender(cast[Data](tx))] = tx.hash

            #Add the Transaction.
            case tx:
                of Claim as claim:
                    for o in 0 ..< claim.outputs.len:
                        utxos[cast[SendOutput](claim.outputs[o]).key].add(
                            newFundedInput(claim.hash, o)
                        )

                    transactions.add(
                        claim,
                        proc (
                            h: uint16
                        ): BLSPublicKey =
                            holders[h].publicKey
                    )
                of Send as send:
                    for rawInput in send.inputs:
                        var
                            input: FundedInput = cast[FundedInput](rawInput)
                            key: EdPublicKey = cast[SendOutput](txs[input.hash].outputs[input.nonce]).key
                        for i in 0 ..< utxos[key].len:
                            if (utxos[key][i].hash == input.hash) and (utxos[key][i].nonce == input.nonce):
                                utxos[key].del(i)
                                break

                    for o in 0 ..< send.outputs.len:
                        utxos[cast[SendOutput](send.outputs[o]).key].add(
                            newFundedInput(send.hash, o)
                        )

                    transactions.add(send)
                of Data as data:
                    transactions.add(data)
                else:
                    panic("Adding an unknown Transaction type.")
            consensus.register(merit.state, tx, merit.blockchain.height)

            #Set the height it appeared at, as well as the Epoch assigned.
            appeared[tx.hash] = merit.blockchain.height
            epochs[tx.hash] = consensus.getStatus(tx.hash).epoch

            #Create a VerificationPacket for the Transaction.
            packets.add(newVerificationPacketObj(tx.hash))
            packets[^1].holders.add(uint16(0))

        #Verify the reversion worked.
        proc verify() =
            #Iterate over the last 5 Blocks to see who has archived Verifications for what.
            #This is incredibly slow and should be optimized out.
            var verifiers: Table[Hash[256], HashSet[uint16]] = initTable[Hash[256], HashSet[uint16]]()
            for b in merit.blockchain.height - 5 ..< merit.blockchain.height:
                for packet in merit.blockchain[b].body.packets:
                    if not verifiers.hasKey(packet.hash):
                        verifiers[packet.hash] = initHashSet[uint16]()
                    for holder in packet.holders:
                        verifiers[packet.hash].incl(holder)

            #Verify every Transaction has a valid status.
            for tx in txs.keys():
                try:
                    #Check if the Transaction was pruned.
                    discard transactions[tx]

                    #If the Transaction is in the cache, make sure Consensus has the status cached with proper values.
                    if transactions.transactions.hasKey(tx):
                        check(consensus.statuses.hasKey(tx))
                        check(consensus.statuses[tx].epoch == min(epochs[tx], merit.blockchain.height + 7))

                        #Don't check competing since this test doesn't generate competing values.
                        discard """
                        status.verified
                        """
                        #Don't test beaten for the same reason as competing.

                        #Make sure there's a set for the verifiers.
                        if not verifiers.hasKey(tx):
                            verifiers[tx] = initHashSet[uint16]()

                        #If the Transaction was finalized, pending, packet, and signatures will be blank.
                        if finalizedStatuses.hasKey(tx):
                            check(consensus.statuses[tx].pending.len == 0)
                            check(consensus.statuses[tx].packet.hash == tx)
                            check(consensus.statuses[tx].packet.holders.len == 0)
                            check(consensus.statuses[tx].packet.signature.isInf)
                            check(consensus.statuses[tx].signatures.len == 0)
                        #Else, pending/packet/signatures should be untouched.
                        else:
                            discard """
                            pending
                            packet
                            signatures
                            """

                            verifiers[tx] = verifiers[tx] + consensus.statuses[tx].pending

                        #Check holders.
                        check(consensus.statuses[tx].holders == verifiers[tx])

                        #Check the Merit.
                        check(consensus.statuses[tx].merit == -1)
                    #If the Transaction was finalized and hasn't been reverted back to unfinalized, make sure the Consensus doesn't have it and its status is untouched.
                    else:
                        check(not consensus.statuses.hasKey(tx))
                        compare(consensus.getStatus(tx), finalizedStatuses[tx])
                #Transaction was pruned.
                except IndexError:
                    try:
                        #Verify the status was pruned.
                        discard consensus.getStatus(tx)
                        check(false)
                    except IndexError:
                        discard

            #Verify the malicious table is untouched.
            for holder in malicious.keys():
                check(malicious[holder].len == consensus.malicious[holder].len)
                for mr in 0 ..< malicious[holder].len:
                    compare(malicious[holder][mr], consensus.malicious[holder][mr])

            #Verify the SpamFilters were reverted.
            compare(consensus.filters.send, sendFilters[^1])
            compare(consensus.filters.data, dataFilters[^1])
            sendFilters.del(high(sendFilters))
            dataFilters.del(high(dataFilters))

            #Commit the database so reloading the Consensus works.
            db.commit(merit.blockchain.height)

            #Reload and compare the Consensus DAGs.
            compare(consensus, newConsensus(
                functions,
                db,
                merit.state,
                initialSendDifficulty,
                initialDataDifficulty
            ))

        #Replay from Block 10.
        proc replay() =
            #Reload Transactions to fix its cache.
            commit(merit.blockchain.height)
            transactions = newTransactions(db, merit.blockchain)

            #Add back each Block and its Transactions.
            for b in 9 ..< blocks.len:
                #Add back the Transactions.
                for packet in blocks[b].body.packets:
                    try:
                        discard transactions[packet.hash]
                        continue
                    except IndexError:
                        discard

                    var tx: Transaction = txs[packet.hash]
                    case tx:
                        of Claim as claim:
                            transactions.add(
                                claim,
                                proc (
                                    h: uint16
                                ): BLSPublicKey =
                                    holders[h].publicKey
                            )
                        of Send as send:
                            transactions.add(send)
                        of Data as data:
                            transactions.add(data)
                        else:
                            panic("Replaying an unknown Transaction type.")

                #Add back the Block.
                merit.processBlock(blocks[b])

                #Archive the Epoch.
                transactions.archive(newBlock, merit.postProcessBlock()[0])

                #Mint Meros.
                if b != blocks.len - 1:
                    transactions.mint(blocks[b].header.hash, rewards[blocks[b].header.hash])

                #Commit the DB.
                commit(merit.blockchain.height)

            #Add back the last Transactions.
            for packet in blocks[^1].body.packets:
                try:
                    discard transactions[packet.hash]
                    continue
                except IndexError:
                    discard

                var tx: Transaction = txs[packet.hash]
                case tx:
                    of Claim as claim:
                        transactions.add(
                            claim,
                            proc (
                                h: uint16
                            ): BLSPublicKey =
                                holders[h].publicKey
                        )
                    of Send as send:
                        transactions.add(send)
                    of Data as data:
                        transactions.add(data)
                    else:
                        panic("Replaying an unknown Transaction type.")

    test "Reverted Consensus.":
        for b in 1 .. 20:
            #Create a random amount of Wallets.
            for _ in 0 ..< rand(2) + 2:
                wallets.add(newWallet(""))
                walletsLookup[wallets[^1].publicKey] = wallets.len - 1
                utxos[wallets[^1].publicKey] = @[]

            #For each Wallet, create a random amount of Transactions.
            for w in 0 ..< wallets.len:
                #Reset the planned Sends/needed Meros.
                plans[w] = @[]
                needed[w] = 0

                #Calculate how much Meros is currently available.
                for utxo in utxos[wallets[w].publicKey]:
                    needed[w] -= int64(cast[SendOutput](transactions[utxo.hash].outputs[utxo.nonce]).amount)

                for t in 0 ..< rand(5):
                    #Plan a Send.
                    #The reason we only plan the Send is because we may need funds from the upcowming Mint for it.
                    if rand(1) == 0:
                        plans[w].add(@[])
                        for o in 0 ..< rand(3) + 1:
                            plans[w][^1].add(newSendOutput(wallets[rand(wallets.len - 1)].publicKey, uint64(rand(5000) + 1)))
                            needed[w] += int64(plans[w][^1][^1].amount)

                    #Create a Data.
                    else:
                        var
                            dataStr: string = newString(rand(254) + 1)
                            data: Data
                        for c in 0 ..< dataStr.len:
                            dataStr[c] = char(rand(255))

                        try:
                            discard dataTips[wallets[w].publicKey]
                        except KeyError:
                            data = newData(Hash[256](), wallets[w].publicKey.toString())
                            wallets[w].sign(data)
                            data.mine(Hash[256]())
                            add(data)

                        data = newData(dataTips[wallets[w].publicKey], dataStr)
                        wallets[w].sign(data)
                        data.mine(Hash[256]())
                        add(data)

                #Calculate the actual amount of needed Meros.
                needed[w] = max(needed[w], 0)

            #Create a Block.
            if merit.blockchain.height == 1:
                newBlock = newBlankBlock(
                    last = merit.blockchain.tail.header.hash,
                    miner = holders[rand(holders.len - 1)],
                    packets = packets
                )
            else:
                newBlock = newBlankBlock(
                    last = merit.blockchain.tail.header.hash,
                    miner = holders[rand(holders.len - 1)],
                    nick = uint16(0),
                    packets = packets
                )
            blocks.add(newBlock)

            #Clear packets.
            packets = @[]

            #Add every packet.
            for packet in newBlock.body.packets:
                consensus.add(merit.state, packet)

            #Check who has their Merit removed.
            var removed: Table[uint16, MeritRemoval] = initTable[uint16, MeritRemoval]()
            for elem in newBlock.body.elements:
                if elem of MeritRemoval:
                    consensus.flag(merit.blockchain, merit.state, cast[MeritRemoval](elem))
                    removed[elem.holder] = cast[MeritRemoval](elem)

            #Add the Block to the Blockchain.
            merit.processBlock(newBlock)

            #Copy the State.
            var rewardsState: State = merit.state

            #Add the Block to the Epochs and State.
            var
                epoch: Epoch
                incd: uint16
                decd: int
            (epoch, incd, decd) = merit.postProcessBlock()

            #Archive the Epochs.
            consensus.archive(merit.state, newBlock.body.packets, newBlock.body.elements, epoch, incd, decd)
            for tx in epoch.keys():
                finalizedStatuses[tx] = consensus.getStatus(tx)

            #Have the Consensus handle every person who suffered a MeritRemoval.
            for removee in removed.keys():
                consensus.remove(removed[removee], rewardsState[removee])

            #Add the elements.
            for elem in elements:
                case elem:
                    of SendDifficulty as sendDiff:
                        consensus.add(merit.state, sendDiff)
                    of DataDifficulty as dataDiff:
                        consensus.add(merit.state, dataDiff)
            elements = @[]

            #Archive the hashes handled by the popped Epoch.
            transactions.archive(newBlock, epoch)

            #Create a Mint/Claim to fund all planned Sends.
            var claims: seq[Claim] = @[]
            rewards[newBlock.header.hash] = @[]
            for w in 0 ..< wallets.len:
                if needed[w] == 0:
                    continue

                rewards[newBlock.header.hash].add(newReward(0, uint64(needed[w]) + uint64(rand(2000))))
                claims.add(newClaim(
                    @[newFundedInput(newBlock.header.hash, rewards[newBlock.header.hash].len - 1)],
                    wallets[w].publicKey
                ))
                holders[0].sign(claims[^1])
            transactions.mint(newBlock.header.hash, rewards[newBlock.header.hash])

            #Commit the DBs.
            commit(merit.blockchain.height)

            #Back up the filters.
            sendFilters.add(consensus.filters.send)
            dataFilters.add(consensus.filters.data)

            #Add the Claims.
            for claim in claims:
                add(claim, true)

            #Create the planned Sends.
            for w in 0 ..< wallets.len:
                for outputs in plans[w].mitems():
                    #Calculate the amount of needed Meros.
                    var amount: int64 = 0
                    for output in outputs:
                        amount += int64(output.amount)

                    #Grab the needed inputs.
                    var
                        i: int = 0
                        inputs: seq[FundedInput] = utxos[wallets[w].publicKey]
                    while amount > int64(0):
                        amount -= int64(cast[SendOutput](transactions[inputs[i].hash].outputs[inputs[i].nonce]).amount)
                        inc(i)
                    while i != inputs.len:
                        inputs.del(i)

                    #Add a change output, if necessary.
                    if amount != 0:
                        outputs.add(newSendOutput(wallets[w].publicKey, uint64(-amount)))

                    #Create and add the Send.
                    var send: Send = newSend(inputs, outputs)
                    wallets[w].sign(send)
                    send.mine(Hash[256]())
                    add(send)

        #Create one last Block for the latest Claims/Sends.
        newBlock = newBlankBlock(
            last = merit.blockchain.tail.header.hash,
            miner = holders[rand(holders.len - 1)],
            nick = uint16(0),
            packets = packets,
            time = merit.blockchain.tail.header.time + 1
        )
        blocks.add(newBlock)
        packets = @[]
        for packet in newBlock.body.packets:
            consensus.add(merit.state, packet)
        merit.processBlock(newBlock)
        var
            rewardsState: State = merit.state
            epoch: Epoch
            incd: uint16
            decd: int
        (epoch, incd, decd) = merit.postProcessBlock()
        consensus.archive(merit.state, newBlock.body.packets, newBlock.body.elements, epoch, incd, decd)
        for tx in epoch.keys():
            finalizedStatuses[tx] = consensus.getStatus(tx)
        transactions.archive(newBlock, epoch)
        commit(merit.blockchain.height)

        #Create a copy of the malicious table.
        malicious = consensus.malicious

        #Revert, block by block.
        while merit.blockchain.height != 10:
            consensus.revert(merit.blockchain, merit.state, transactions, merit.blockchain.height - 1)
            transactions.revert(merit.blockchain, merit.blockchain.height - 1)
            merit.revert(merit.blockchain.height - 1)
            db.commit(merit.blockchain.height)
            transactions = newTransactions(db, merit.blockchain)
            consensus.postRevert(merit.blockchain, merit.state, transactions)

            verify()

        discard """
        #Replay every Block/Transaction.
        replay()

        #Revert everything to Block 10 all at once.
        consensus.revert(merit.blockchain, merit.state, transactions, 10)
        transactions.revert(merit.blockchain, 10)
        merit.revert(10)
        db.commit(merit.blockchain.height)
        transactions = newTransactions(db, merit.blockchain)
        consensus.postRevert(merit.blockchain, merit.state, transactions)

        verify()

        #Replay every Block/Transaction again.
        replay()
        """
