#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#Difficulty and Block objects.
import DifficultyObj
import BlockObj

#Finals lib.
import finals

#Lists standard lib.
import lists

#Blockchain object.
finalsd:
    type Blockchain* = object
        #DB Function Box.
        db*: DB

        #Block time (part of the chain params).
        blockTime* {.final.}: int
        #Starting Difficulty (part of the chain params).
        startDifficulty* {.final.}: Difficulty

        #Height.
        height*: int
        #Linked List of the last 10 Blocks.
        blocks: DoublyLinkedList[Block]

        #Current Difficulty.
        difficulty*: Difficulty

#Create a Blockchain object.
proc newBlockchainObj*(
    db: DB,
    genesisArg: string,
    blockTime: int,
    startDifficultyArg: Hash[384]
): Blockchain {.forceCheck: [].} =
    #Create the start difficulty.
    var startDifficulty: Difficulty
    try:
        startDifficulty = newDifficultyObj(
            0,
            2,
            startDifficultyArg
        )
    except ValueError:
        doAssert(false, "Couldn't create the Blockchain's starting difficulty.")

    #Create the Blockchain.
    result = Blockchain(
        db: db,

        blockTime: blockTime,
        startDifficulty: startDifficulty,

        height: 0,
        blocks: initDoublyLinkedList[Block](),

        difficulty: startDifficulty
    )
    result.ffinalizeBlockTime()
    result.ffinalizeStartDifficulty()

    #Craft the genesis.
    var genesis: ArgonHash
    try:
        genesis = genesisArg.pad(48).toArgonHash()
    except ValueError as e:
        doAssert(false, "Couldn't convert the genesis toa hash, despite being padded to 48 bytes: " & e.msg)

    #Grab the height and tip from the DB.
    var tip: Hash[384]
    try:
        result.height = result.db.loadHeight()
        tip = result.db.loadTip()
    #If the height and tip weren't defined, this is the first boot.
    except DBReadError as e:
        #Make sure we didn't get the height but not the tip.
        if result.height != 0:
            doAssert(false, "Loaded the height but not the tip: " & e.msg)
        result.height = 1

        #Create a Genesis Block.
        var genesisBlock: Block
        try:
            genesisBlock = newBlockObj(
                0,
                genesis,
                Hash[384](),
                Hash[384](),
                nil,
                @[],
                @[],
                nil,
                0,
                0,
                nil
            )
        except ValueError as e:
            doAssert(false, "Couldn't create the Genesis Block due to a ValueError: " & e.msg)
        #Grab the tip.
        tip = genesisBlock.hash

        #Save the height, tip, the Genesis Block, and the starting Difficulty.
        result.db.saveHeight(result.height)
        result.db.saveTip(tip)
        result.db.save(0, genesisBlock)
        result.db.save(result.difficulty)

    #Load the last 10 Blocks.
    var last: Block
    for i in 0 ..< 10:
        try:
            last = result.db.loadBlock(tip)
            result.blocks.prepend(last)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Block from the Database: " & e.msg)

        if last.header.last == genesis:
            break
        tip = last.hash

    #Load the Difficulty.
    try:
        result.difficulty = result.db.loadDifficulty()
    except DBReadError as e:
        doAssert(false, "Couldn't load the Difficulty from the Database: " & e.msg)

#Adds a Block.
proc add*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    #Add the Block to the cache.
    blockchain.blocks.append(newBlock)
    #Delete the Block we're no longer caching.
    if blockchain.height > 10:
        blockchain.blocks.remove(blockchain.blocks.head)

    #Save the Block to the database.
    blockchain.db.saveTip(newBlock.hash)
    blockchain.db.save(blockchain.height, newBlock)

    #Update the height.
    inc(blockchain.height)
    blockchain.db.saveHeight(blockchain.height)

#Check if a Block exists.
proc hasBlock*(
    blockchain: Blockchain,
    hash: Hash[384]
): bool {.forceCheck: [].} =
    blockchain.db.hasBlock(hash)

#Block getters.
proc `[]`*(
    blockchain: Blockchain,
    nonce: int
): Block {.forceCheck: [
    IndexError
].} =
    if nonce >= blockchain.height:
        raise newException(IndexError, "Specified nonce is greater than the Blockchain height.")
    elif nonce >= blockchain.height - 10:
        var res: DoublyLinkedNode[Block] = blockchain.blocks.head
        for _ in 0 ..< nonce - (blockchain.height - 10):
            res = res.next
        result = res.value
    else:
        try:
            result = blockchain.db.loadBlock(nonce)
        except DBReadError:
            raise newException(IndexError, "Specified hash doesn't match any Block.")

proc `[]`*(
    blockchain: Blockchain,
    hash: Hash[384]
): Block {.forceCheck: [
    IndexError
].} =
    try:
        result = blockchain.db.loadBlock(hash)
    except DBReadError:
        raise newException(IndexError, "Block not found.")

#Gets the last Block.
func tip*(
    blockchain: Blockchain
): Block {.inline, forceCheck: [].} =
    blockchain.blocks.tail.value
