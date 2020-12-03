include MainMerit

proc syncMeritRemovalTransactions(
  functions: GlobalFunctionBox,
  consensus: ref Consensus,
  network: Network,
  removal: SignedMeritRemoval
): Future[void] {.forceCheck: [
  ValueError
], async.} =
  #Sync the MeritRemoval's transactions, if we don't have them already.
  proc syncMeritRemovalTransaction(
    hash: Hash[256]
  ): Future[void] {.forceCheck: [
    ValueError
  ], async.} =
    try:
      discard functions.transactions.getTransaction(hash)
    except IndexError:
      try:
        var tx: Transaction = await syncAwait network.syncManager.syncTransaction(hash)
        case tx:
          of Claim as claim:
            functions.transactions.addClaim(claim, true)
          of Send as send:
            await functions.transactions.addSend(send, true)
          of Data as data:
            await functions.transactions.addData(data, true)
          else:
            panic("Tried to sync an unrecognized Transaction type used as the reason for a Merit Removal.")
      except ValueError as e:
        raise newLoggedException(ValueError, "Transaction used as the reason for a Merit Removal was invalid: " & e.msg)
      except DataMissing as e:
        raise newLoggedException(ValueError, "Couldn't sync a Transaction used as the reason for a Merit Removal: " & e.msg)
      #Happens when two async tasks execute at the same time.
      except DataExists:
        discard
      except Exception as e:
        panic("Syncing a MeritRemoval's Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

  try:
    if removal.element1 of Verification:
      await syncMeritRemovalTransaction(cast[Verification](removal.element1).hash)
      await syncMeritRemovalTransaction(cast[Verification](removal.element2).hash)
  except ValueError as e:
    raise e
  except Exception as e:
    panic("Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

proc mainConsensus(
  params: ChainParams,
  database: DB,
  functions: GlobalFunctionBox,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions,
  network: ref Network
) {.forceCheck: [].} =
  try:
    consensus[] = newConsensus(
      functions,
      database,
      merit.state,
      params.SEND_DIFFICULTY,
      params.DATA_DIFFICULTY
    )
  except ValueError:
    panic("Invalid initial Send/Data difficulty.")

  functions.consensus.getSendDifficulty = proc (): uint32 {.forceCheck: [].} =
    consensus.filters.send.difficulty
  functions.consensus.getDataDifficulty = proc (): uint32 {.forceCheck: [].} =
    consensus.filters.data.difficulty

  functions.consensus.isMalicious = proc (
    nick: uint16
  ): bool {.forceCheck: [].} =
    consensus.malicious.hasKey(nick)

  functions.consensus.getArchivedNonce = proc (
    holder: uint16
  ): int {.forceCheck: [].} =
    consensus[].getArchivedNonce(holder)

  #Returns true if the hash isn't recognized.
  #Will false positive if the Transaction doesn't exist.
  functions.consensus.hasArchivedPacket = proc (
    hash: Hash[256]
  ): bool {.forceCheck: [].} =
    return not consensus.unmentioned.contains(hash)

  functions.consensus.getStatus = proc (
    hash: Hash[256]
  ): TransactionStatus {.forceCheck: [
    IndexError
  ].} =
    try:
      result = consensus[].getStatus(hash)
    except IndexError:
      raise newLoggedException(IndexError, "Couldn't find a Status for that hash.")

  functions.consensus.getThreshold = proc (
    epoch: int
  ): int {.forceCheck: [].} =
    merit.state.nodeThresholdAt(epoch)

  functions.consensus.getElement = proc (
    holder: uint16,
    nonce: int
  ): BlockElement {.forceCheck: [
    IndexError
  ].} =
    try:
      result = consensus[].getElement(holder, nonce)
    except IndexError as e:
      raise e

  functions.consensus.getPending = proc (): tuple[
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
    aggregate: BLSSignature
  ] {.forceCheck: [].} =
    var pending: tuple[
      packets: seq[SignedVerificationPacket],
      elements: seq[BlockElement],
      aggregate: BLSSignature
    ] = consensus[].getPending()

    result = (cast[seq[VerificationPacket]](pending.packets), pending.elements, pending.aggregate)

  functions.consensus.addSignedVerification = proc (
    verif: SignedVerification
  ) {.forceCheck: [
    ValueError,
    DataExists
  ], async.} =
    logInfo "New Verification", holder = verif.holder, hash = verif.hash

    var mr: bool
    try:
      try:
        consensus[].add(merit.state, verif)
      except DataMissing:
        var tx: Transaction
        try:
          tx = await syncAwait network.syncManager.syncTransaction(verif.hash)
        except DataMissing:
          raise newException(ValueError, "Verification is of a non-existent Transaction.")
        except Exception as e:
          panic("syncTransaction threw an error despite catching all errors: " & e.msg)
        try:
          case tx:
            of Mint as _:
              panic("Synced a Mint. We should never have parsed it.")
            of Claim as claim:
              functions.transactions.addClaim(claim)
            of Send as send:
              if send.argon.overflows(send.getDifficultyFactor() * functions.consensus.getSendDifficulty()):
                raise newException(ValueError, "Send doesn't pass the spam check.")
              await functions.transactions.addSend(send)
            of Data as data:
              if data.argon.overflows(data.getDifficultyFactor() * functions.consensus.getDataDifficulty()):
                raise newException(ValueError, "Data doesn't pass the spam check.")
              await functions.transactions.addData(data)
        except ValueError as e:
          raise e
        #[
        Swallow DataExists errors.
        Stops this Transaction add from causing the signed verification to fail.
        While the Transaction didn't exist when we checked, it could've been added by another async process in this time.
        ]#
        except DataExists:
          discard
        except Exception as e:
          panic("addSend/addData raised an Exception despite catching all errors: " & e.msg)

        #Try again.
        try:
          consensus[].add(merit.state, verif)
        except DataMissing:
          panic("Transaction in a Verification was missing despite just syncing it.")
    #Invalid signature/transaction.
    except ValueError as e:
      raise e
    #Already added.
    except DataExists as e:
      raise e
    #MeritHolder committed a malicious act against the network.
    except MaliciousMeritHolder as e:
      #Set mr to true.
      mr = true

      #Flag the MeritRemoval.
      consensus[].flag(merit.blockchain, merit.state, e.removal.holder)

    if mr:
      try:
        #Broadcast the first MeritRemoval.
        functions.network.broadcast(
          MessageType.SignedMeritRemoval,
          consensus.malicious[verif.holder][0].serialize()
        )
      except KeyError as e:
        panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
      return

    logInfo "Added Verification", holder = verif.holder, hash = verif.hash

    #Broadcast the SignedVerification.
    functions.network.broadcast(
      MessageType.SignedVerification,
      verif.signedSerialize()
    )

  functions.consensus.addVerificationPacket = proc (
    packet: VerificationPacket
  ) {.forceCheck: [].} =
    logInfo "New Verification Packet from Block", hash = packet.hash, holders = packet.holders
    consensus[].add(merit.state, packet)
    logInfo "Added Verification Packet from Block", hash = packet.hash, holders = packet.holders

  functions.consensus.addSendDifficulty = proc (
    sendDiff: SendDifficulty
  ) {.forceCheck: [].} =
    logInfo "New Send Difficulty from Block", holder = sendDiff.holder, difficulty = sendDiff.difficulty
    consensus[].add(merit.state, sendDiff)
    logInfo "Added Send Difficulty from Block", holder = sendDiff.holder, difficulty = sendDiff.difficulty

  functions.consensus.addSignedSendDifficulty = proc (
    sendDiff: SignedSendDifficulty
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Send Difficulty", holder = sendDiff.holder, difficulty = sendDiff.difficulty

    var mr: bool
    try:
      consensus[].add(merit.state, sendDiff)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e
    except MaliciousMeritHolder as e:
      mr = true
      consensus[].flag(merit.blockchain, merit.state, e.removal.holder)

    if mr:
      try:
        #Broadcast the first MeritRemoval.
        functions.network.broadcast(
          MessageType.SignedMeritRemoval,
          consensus.malicious[sendDiff.holder][0].serialize()
        )
      except KeyError as e:
        panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
      return

    logInfo "Added Send Difficulty", holder = sendDiff.holder, difficulty = sendDiff.difficulty

    #Broadcast the SendDifficulty.
    functions.network.broadcast(
      MessageType.SignedSendDifficulty,
      sendDiff.signedSerialize()
    )

  functions.consensus.addDataDifficulty = proc (
    dataDiff: DataDifficulty
  ) {.forceCheck: [].} =
    logInfo "New Data Difficulty from Block", holder = dataDiff.holder, difficulty = dataDiff.difficulty
    consensus[].add(merit.state, dataDiff)
    logInfo "Added Data Difficulty from Block", holder = dataDiff.holder, difficulty = dataDiff.difficulty

  functions.consensus.addSignedDataDifficulty = proc (
    dataDiff: SignedDataDifficulty
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Data Difficulty", holder = dataDiff.holder, difficulty = dataDiff.difficulty

    var mr: bool = false
    try:
      consensus[].add(merit.state, dataDiff)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e
    except MaliciousMeritHolder as e:
      mr = true
      consensus[].flag(merit.blockchain, merit.state, e.removal.holder)

    if mr:
      try:
        #Broadcast the first MeritRemoval.
        functions.network.broadcast(
          MessageType.SignedMeritRemoval,
          consensus.malicious[dataDiff.holder][0].serialize()
        )
      except KeyError as e:
        panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
      return

    logInfo "Added Data Difficulty", holder = dataDiff.holder, difficulty = dataDiff.difficulty

    #Broadcast the DataDifficulty.
    functions.network.broadcast(
      MessageType.SignedDataDifficulty,
      dataDiff.signedSerialize()
    )

  functions.consensus.addSignedMeritRemoval = proc (
    mr: SignedMeritRemoval
  ): Future[void] {.forceCheck: [
    ValueError,
    DataExists
  ], async.} =
    logInfo "Found Merit Removal", holder = mr.holder

    try:
      await syncMeritRemovalTransactions(functions, consensus, network[], mr)
    except ValueError as e:
      raise e
    except Exception as e:
      panic("Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

    try:
      consensus[].add(merit.blockchain, merit.state, mr)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e

    logInfo "Added Merit Removal", holder = mr.holder

    #Broadcast the first MeritRemoval.
    try:
      functions.network.broadcast(
        MessageType.SignedMeritRemoval,
        consensus.malicious[mr.holder][0].serialize()
      )
    except KeyError as e:
      panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
