#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#VerificationPacket object.
import ../../Consensus/Elements/objects/VerificationPacketObj

#Blockchain lib.
import ../../Merit/Blockchain

#Transactions DB lib.
import ../../Filesystem/DB/TransactionsDB

#Transaction lib.
import ../Transaction as TransactionFile

#Sets standard lib.
import sets

#Tables standard library.
import tables

type Transactions* = object
  #DB Function Box.
  db: DB
  #Transactions which have yet to leave Epochs.
  transactions*: Table[Hash[256], Transaction]

#Get a Data's sender.
proc getSender*(
  transactions: var Transactions,
  data: Data
): EdPublicKey {.forceCheck: [
  DataMissing
].} =
  if data.isFirstData:
    try:
      if data.data.len != 32:
        raise newLoggedException(DataMissing, "Initial data wasn't provided a public key.")
      return newEdPublicKey(data.data)
    except ValueError as e:
      panic("Couldn't create an EdPublicKey from a Data's input: " & e.msg)
  else:
    try:
      return transactions.db.loadDataSender(data.inputs[0].hash)
    except DBReadError:
      raise newLoggedException(DataMissing, "Couldn't find the Data's input which was not its sender.")

#Add a Transaction to the DAG.
proc add*(
  transactions: var Transactions,
  tx: Transaction,
  save: bool = true
) {.forceCheck: [
  ValueError
].} =
  if save:
    #Verify every input doesn't have a spender out of Epochs.
    if not ((tx of Data) and (tx.inputs[0].hash == Hash[256]())):
      for input in tx.inputs:
        if transactions.db.isBeaten(input.hash):
          raise newLoggedException(ValueError, "Transaction spends a finalized Transaction which was beaten.")

        var spenders: seq[Hash[256]] = transactions.db.loadSpenders(input)
        if spenders.len == 0:
          continue
        if not transactions.transactions.hasKey(spenders[0]):
          raise newLoggedException(ValueError, "Transaction competes with a finalized Transaction.")

  if not (tx of Mint):
    #Add the Transaction to the cache.
    transactions.transactions[tx.hash] = tx

  if save:
    #Save the TX.
    transactions.db.save(tx)

    #If this is a Data, save the sender.
    if tx of Data:
      var data: Data = cast[Data](tx)
      try:
        transactions.db.saveDataSender(data, transactions.getSender(data))
      except DataMissing as e:
        panic("Added a Data we don't know the sender of: " & e.msg)

#Get a Transaction by its hash.
proc `[]`*(
  transactions: Transactions,
  hash: Hash[256]
): Transaction {.forceCheck: [
  IndexError
].} =
  #Check if the Transaction is in the cache.
  if transactions.transactions.hasKey(hash):
    #If it is, return it from the cache.
    try:
      return transactions.transactions[hash]
    except KeyError as e:
      panic("Couldn't grab a Transaction despite confirming the key exists: " & e.msg)

  #Load the hash from the DB.
  try:
    result = transactions.db.load(hash)
  except DBReadError:
    raise newLoggedException(IndexError, "Hash doesn't map to any Transaction.")

#Transactions constructor.
proc newTransactionsObj*(
  db: DB,
  blockchain: Blockchain
): Transactions {.forceCheck: [].} =
  #Create the object.
  result = Transactions(
    db: db,
    transactions: initTable[Hash[256], Transaction]()
  )

  #Load the Transactions from the DB.
  try:
    #Find which Transactions were mentioned before the last 5 blocks.
    var mentioned: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    for b in max(0, blockchain.height - 10) ..< blockchain.height - 5:
      for packet in blockchain[b].body.packets:
        mentioned.incl(packet.hash)

    #Load Transactions in the last 5 Blocks, as long as they aren't first mentioned in older Blocks.
    for b in max(0, blockchain.height - 5) ..< blockchain.height:
      for packet in blockchain[b].body.packets:
        if mentioned.contains(packet.hash):
          continue

        try:
          result.add(db.load(packet.hash), false)
        except ValueError as e:
          panic("Adding a reloaded Transaction raised a ValueError: " & e.msg)
        except DBReadError as e:
          panic("Couldn't load a Transaction from the Database: " & e.msg)
        mentioned.incl(packet.hash)

    #Load the unmentioned Transactions.
    for hash in db.loadUnmentioned():
      try:
        result.add(db.load(hash), false)
      except ValueError as e:
        panic("Adding a reloaded unmentioned Transaction raised a ValueError: " & e.msg)
      except DBReadError as e:
        panic("Couldn't load an unmentioned Transaction from the Database: " & e.msg)
  except IndexError as e:
    panic("Couldn't load hashes from the Blockchain while reloading Transactions: " & e.msg)

#Load a Public Key's UTXOs.
proc getUTXOs*(
  transactions: Transactions,
  key: EdPublicKey
): seq[FundedInput] {.forceCheck: [].} =
  try:
    result = transactions.db.loadSpendable(key)
  except DBReadError:
    result = @[]

#Mark a Transaction as mentioned.
proc mention*(
  transactions: Transactions,
  hash: Hash[256]
) {.inline, forceCheck: [].} =
  transactions.db.mention(hash)

#Mark a Transaction as verified, removing the outputs it spends from spendable.
proc verify*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  var tx: Transaction
  try:
    tx = transactions[hash]
  except IndexError as e:
    panic("Tried to mark a non-existent Transaction as verified: " & e.msg)

  transactions.db.verify(tx)

#Mark a Transaction as unverified, removing its outputs from spendable.
proc unverify*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  var tx: Transaction
  try:
    tx = transactions[hash]
  except IndexError as e:
    panic("Tried to mark a non-existent Transaction as verified: " & e.msg)

  transactions.db.unverify(tx)

#Mark a Transaction as beaten.
proc beat*(
  transactions: Transactions,
  hash: Hash[256]
) {.inline, forceCheck: [].} =
  transactions.db.beat(hash)

#Mark Transactions as unmentioned.
proc unmention*(
  transactions: Transactions,
  hashes: HashSet[Hash[256]]
) {.inline, forceCheck: [].} =
  transactions.db.unmention(hashes)

#Delete a hash from the cache.
func del*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  transactions.transactions.del(hash)

#Prune a Transactions.
proc prune*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  transactions.transactions.del(hash)
  transactions.db.prune(hash)

#Load a Mint Output.
proc loadMintOutput*(
  transactions: Transactions,
  input: FundedInput
): MintOutput {.forceCheck: [
  DBReadError
].} =
  try:
    result = transactions.db.loadMintOutput(input)
  except DBReadError as e:
    raise e

#Load a Claim or Send Output.
proc loadSendOutput*(
  transactions: Transactions,
  input: FundedInput
): SendOutput {.forceCheck: [
  DBReadError
].} =
  try:
    result = transactions.db.loadSendOutput(input)
  except DBReadError as e:
    raise e

proc loadSpenders*(
  transactions: Transactions,
  input: Input
): seq[Hash[256]] {.inline, forceCheck: [].} =
  transactions.db.loadSpenders(input)
