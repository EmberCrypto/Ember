#Number lib.
import BN

#Merkle lib.
import ../../lib/Merkle

#Block/Blockchain/State libs.
import Block
import Blockchain
import State
#Export the Merkle and Block lib for miners.
export Merkle
export Block

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain: Blockchain
    state: State

#Creates A Merit object based on a Gensis string.
proc newMerit*(genesis: string): Merit {.raises: [ValueError].} =
    result = Merit(
        blockchain: newBlockchain(genesis),
        state: newState()
    )

#Add a block.
proc processBlock*(merit: Merit, newBlock: Block): bool {.raises: [Exception].} =
    result = true
    #Add the block to the Blockchain.
    if not merit.blockchain.addBlock(newBlock):
        #If that fails, return false.
        return false

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)

#Getters.
proc getHeight*(merit: Merit): BN {.raises: [].} =
    merit.blockchain.height
proc getBlocks*(merit: Merit): seq[Block] {.raises: [].} =
    merit.blockchain.blocks
proc getBalance*(merit: Merit, account: string): BN {.raises: [ValueError].} =
    merit.state.getBalance(account)
