#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Verifications library.
import ../Verifications

#Difficulty and Block objects.
import DifficultyObj
import BlockObj

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Blockchain object.
finalsd:
    type Blockchain* = ref object of RootObj
        #Block time (part of the chain params).
        blockTime* {.final.}: uint

        #Height.
        height*: uint
        #seq of all the blocks.
        blocks*: seq[Block]
        #seq of all the difficulties.
        difficulties*: seq[Difficulty]

#Create a Blockchain object.
proc newBlockchainObj*(
    genesis: string,
    blockTime: uint,
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError, BLSError].} =
    var verifs: Verifications = newVerificationsObj()
    verifs.calculateSig()

    result = Blockchain(
        blockTime: blockTime,

        height: 1,
        blocks: @[
            newBlockObj(
                0,
                genesis.pad(64).toArgonHash(),
                verifs,
                @[],
                0,
                0
            )
        ],

        difficulties: @[
            newDifficultyObj(
                0,
                1,
                startDifficulty
            )
        ]
    )
    result.ffinalizeBlockTime()

func add*(blockchain: Blockchain, newBlock: Block) {.raises: [].} =
    inc(blockchain.height)
    blockchain.blocks.add(newBlock)

func add*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulties.add(difficulty)
