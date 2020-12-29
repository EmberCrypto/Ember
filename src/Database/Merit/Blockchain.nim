import tables

import stint

import ../../lib/[Errors, Util, Hash]
import ../../Wallet/MinerWallet

import ../Consensus/Elements/objects/[VerificationPacketObj, MeritRemovalObj]

import ../../Network/Serialize/Consensus/SerializeElement

import ../Filesystem/DB/MeritDB

import Difficulty, BlockHeader, Block, State

import objects/BlockchainObj
export BlockchainObj

proc newBlockchain*(
  db: DB,
  genesis: string,
  blockTime: int,
  initialDifficulty: uint64
): Blockchain {.inline, forceCheck: [].} =
  newBlockchainObj(
    db,
    genesis,
    blockTime,
    initialDifficulty
  )

#Verify a Block Header.
#Takes in so many arguments so we don't have to create a fake chain with all this info when we test forks.
proc testBlockHeader*(
  miners: Table[BLSPublicKey, uint16],
  lookup: seq[BLSPublicKey],
  hasMR: set[uint16],
  previous: BlockHeader,
  difficultyArg: uint64,
  header: BlockHeader
) {.forceCheck: [
  ValueError
].} =
  var difficulty: uint64 = difficultyArg
  if header.newMiner:
    difficulty = difficulty * 11 div 10
  if header.hash.overflows(difficulty):
    raise newLoggedException(ValueError, "Block doesn't beat the difficulty.")

  if header.version != 0:
    raise newLoggedException(ValueError, "BlockHeader has an invalid version.")

  var key: BLSPublicKey
  if header.newMiner:
    #Check a miner with a nickname isn't being marked as new.
    if miners.hasKey(header.minerKey):
      raise newLoggedException(ValueError, "Header marks a miner with a nickname as new.")

    #Make sure the key isn't infinite.
    if header.minerKey.isInf:
      raise newLoggedException(ValueError, "Header has an infinite miner key.")

    #Grab the key.
    key = header.minerKey
  else:
    #Make sure the nick is valid.
    if header.minerNick >= uint16(lookup.len):
      raise newLoggedException(ValueError, "Header has an invalid nickname.")

    #Make sure they never had their Merit removed.
    if hasMR.contains(header.minerNick):
      raise newLoggedException(ValueError, "Header has a miner who had their Merit Removed.")

    key = lookup[header.minerNick]

  if (header.time <= previous.time) or (header.time > (getTime() + 300)):
    raise newLoggedException(ValueError, "Block has an invalid time.")

  try:
    if not header.signature.verify(newBLSAggregationInfo(key, header.interimHash)):
      raise newLoggedException(ValueError, "Block has an invalid signature.")
  except BLSError as e:
    panic("Failed to verify a BlockHeader's signature: " & e.msg)

proc processBlock*(
  blockchain: var Blockchain,
  newBlock: Block
) {.forceCheck: [].} =
  logDebug "Blockchain processing Block", hash = newBlock.header.hash

  blockchain.add(newBlock)

  #Calculate the next difficulty.
  var
    windowLength: int = calculateWindowLength(blockchain.height)
    time: uint32
  if windowLength != 0:
    try:
      time = blockchain.tail.header.time - blockchain[blockchain.height - windowLength].header.time
    except IndexError as e:
      panic("Couldn't get Block " & $(blockchain.height - windowLength) & " when the height is " & $blockchain.height & ": " & e.msg)

  blockchain.difficulties.add(calculateNextDifficulty(
    blockchain.blockTime,
    windowLength,
    blockchain.difficulties,
    time,
    newBlock.header.newMiner
  ))

  blockchain.db.save(newBlock.header.hash, blockchain.difficulties[^1])
  if blockchain.difficulties.len > 72:
    blockchain.difficulties.delete(0)

  #Update the chain work.
  blockchain.chainWork += stuint(blockchain.difficulties[^1], 128)
  blockchain.db.save(newBlock.header.hash, blockchain.chainWork)

#Set the cache key to what it was at a certain height.
proc setCacheKeyAtHeight*(
  blockchain: Blockchain,
  height: int
) {.forceCheck: [].} =
  var
    currentKeyHeight: int = height - 12
    blockUsedAsKey: int = (currentKeyHeight - (currentKeyHeight mod 384)) - 1
    blockUsedAsUpcomingKey: int = (height - (height mod 384)) - 1
    currentKey: string
  if blockUsedAsKey == -1:
    currentKey = blockchain.genesis.serialize()
  else:
    try:
      currentKey = blockchain[blockUsedAsKey].header.hash.serialize()
    except IndexError as e:
      panic("Couldn't grab the Block used as the current RandomX key: " & e.msg)

  #Rebuild the RandomX cache if needed.
  if currentKey != blockchain.rx.cacheKey:
    blockchain.rx.setCacheKey(currentKey)
    blockchain.db.saveKey(blockchain.rx.cacheKey)

  if blockUsedAsUpcomingKey == -1:
    #We don't need to do this since we don't load the upcoming key at Block 12.
    #The only reason we do is to ensure database equality between now and a historic moment.
    blockchain.db.deleteUpcomingKey()
  else:
    try:
      blockchain.db.saveUpcomingKey(blockchain[blockUsedAsUpcomingKey].header.hash.serialize())
    except IndexError as e:
      panic("Couldn't grab the Block used as the upcoming RandomX key: " & e.msg)

#Revert the Blockchain to a certain height.
proc revert*(
  blockchain: var Blockchain,
  state: var State,
  height: int
) {.forceCheck: [].} =
  var oldAmountOfHolders: int = state.holders.len
  state.revert(blockchain, height)
  state.pruneStatusesAndParticipations(oldAmountOfHolders)

  #Revert the Blocks.
  for b in countdown(blockchain.height - 1, height):
    try:
      #If this Block had a new miner, delete it.
      if blockchain[b].header.newMiner:
        blockchain.miners.del(blockchain[b].header.minerKey)
        blockchain.db.deleteHolder()
    except IndexError as e:
      panic("Couldn't grab the Block we're reverting past: " & e.msg)

    #Delete the Block.
    try:
      blockchain.db.deleteBlock(b, blockchain[b])
    except IndexError:
      panic("Couldn't get a Block's Elements before we deleted it.")

    #Rewind the cache.
    blockchain.rewindCache()

    #Decrement the height.
    dec(blockchain.height)

  #Save the reverted to tip.
  blockchain.db.saveTip(blockchain.tail.header.hash)

  #Save the reverted to height.
  blockchain.db.saveHeight(blockchain.height)

  #Load the reverted to difficulties.
  blockchain.difficulties = blockchain.db.calculateDifficulties(blockchain.genesis, blockchain.tail.header)
  #Load the chain work.
  blockchain.chainWork = blockchain.db.loadChainWork(blockchain.tail.header.hash)

  #Update the RandomX keys.
  blockchain.setCacheKeyAtHeight(blockchain.height)

  #[
  Flush Merit balances.
  As we did the above iteration, we used to keep track of the specific holders in a set.
  Although technically less efficient, this has no meaningful performance impact yet is much easier to maintain.
  Not to mention, this doesn't re-read any Blocks from the Database.
  The old setup is only more performant if done on the State side of things, and then iterated over here.
  ]#
  for holder in 0 ..< state.merit.len:
    blockchain.db.saveMerit(uint16(holder), state.merit[holder])
