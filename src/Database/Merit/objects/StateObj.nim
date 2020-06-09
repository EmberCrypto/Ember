import ../../../lib/[Errors, Util]
import ../../../Wallet/MinerWallet

import ../../Filesystem/DB/MeritDB

import BlockObj

type State* = object
  #DB.
  db: DB
  #Reverting/Catching up.
  oldData*: bool

  #Blocks until Merit is dead.
  deadBlocks*: int
  #Unlocked Merit.
  unlocked: int

  #Amount of Blocks processed.
  processedBlocks*: int

  #List of holders. Position on the list is their nickname.
  holders: seq[BLSPublicKey]
  #List of Merit balances.
  merit: seq[int]

  #Pending removals.
  pendingRemovals*: seq[int]

proc newStateObj*(
  db: DB,
  deadBlocks: int,
  blockchainHeight: int
): State {.forceCheck: [].} =
  result = State(
    db: db,
    oldData: false,

    deadBlocks: deadBlocks,
    unlocked: 0,

    processedBlocks: blockchainHeight,

    pendingRemovals: @[]
  )

  #Load the amount of Unlocked Merit.
  try:
    result.unlocked = result.db.loadUnlocked(result.processedBlocks - 1)
  except DBReadError:
    discard

  #Load the holders.
  result.holders = result.db.loadHolders()
  result.merit = newSeq[int](result.holders.len)
  for h in 0 ..< result.holders.len:
    try:
      result.merit[h] = result.db.loadMerit(uint16(h))
    except DBReadError as e:
      panic("Couldn't load a holder's Merit: " & e.msg)

proc saveUnlocked*(
  state: State
) {.inline, forceCheck: [].} =
  state.db.saveUnlocked(state.processedBlocks - 1, state.unlocked)

func unlocked*(
  state: State
): int {.inline, forceCheck: [].} =
  state.unlocked

proc loadUnlocked*(
  state: State,
  height: int,
): int {.forceCheck: [].} =
  #If the Block is in the future, return the amount it will be (without Merit Removals).
  if height >= state.processedBlocks:
    result = min(
      (height - state.processedBlocks) + state.unlocked,
      state.deadBlocks
    )
  #Load the amount of Unlocked Merit at the specified Block.
  else:
    try:
      result = state.db.loadUnlocked(height - 1)
    except DBReadError:
      panic("Couldn't load the Unlocked Merit for a Block below the `processedBlocks`.")

#Register a new Merit Holder.
proc newHolder*(
  state: var State,
  holder: BLSPublicKey
): uint16 {.forceCheck: [].} =
  result = uint16(state.holders.len)
  state.merit.add(0)
  state.holders.add(holder)
  state.db.saveHolder(holder)

#Get a Merit Holder's Merit.
proc `[]`*(
  state: State,
  nick: uint16,
  height: int
): int {.forceCheck: [].} =
  #Throw a fatal error if the nickname is invalid.
  if nick < 0:
    panic("Asking for the Merit of an invalid nickname.")

  #If the nick is out of bounds, yet still positive, return 0.
  if nick >= uint16(state.holders.len):
    return 0

  #Set the Merit to the result.
  result = state.merit[int(nick)]

  #Iterate over the pending removal cache, seeing if we need to decrement at all.
  for r in 0 ..< height - state.processedBlocks:
    if state.pendingRemovals[r] == int(nick):
      dec(result)

proc loadBlockRemovals*(
  state: State,
  blockNum: int
): seq[tuple[nick: uint16, merit: int]] {.inline, forceCheck: [].} =
  state.db.loadBlockRemovals(blockNum)

proc loadHolderRemovals*(
  state: State,
  nick: uint16
): seq[int] {.inline, forceCheck: [].} =
  state.db.loadHolderRemovals(nick)

proc holders*(
  state: State
): seq[BLSPublicKey] {.inline, forceCheck: [].} =
  state.holders

#Set a holder's Merit.
proc `[]=`*(
  state: var State,
  nick: uint16,
  value: int
) {.inline, forceCheck: [].} =
  #Get the current value.
  var current: int = state[nick, state.processedBlocks]
  #Set their new value.
  state.merit[int(nick)] = value
  #Update unlocked accrodingly.
  if value > current:
    state.unlocked += value - current
  else:
    state.unlocked -= current - value

  #Save the updated values.
  if not state.oldData:
    state.db.saveMerit(nick, value)

#Remove a MeritHolder's Merit.
proc remove*(
  state: var State,
  nick: uint16,
  nonce: int
) {.forceCheck: [].} =
  state.db.remove(nick, state[nick, state.processedBlocks], nonce)
  state[nick] = 0
  state.db.saveUnlocked(state.processedBlocks, state.unlocked)

  for p in 0 ..< state.pendingRemovals.len:
    if state.pendingRemovals[p] == int(nick):
      state.pendingRemovals[p] = -1

#Delete the last nickname from RAM.
proc deleteLastNickname*(
  state: var State
) {.inline, forceCheck: [].} =
  state.holders.del(high(state.holders))

#Reverse lookup for a key to nickname.
proc reverseLookup*(
  state: State,
  key: BLSPublicKey
): uint16 {.forceCheck: [
  IndexError
].} =
  try:
    result = state.db.loadNickname(key)
  except DBReadError:
    raise newLoggedException(IndexError, $key & " does not have a nickname.")
