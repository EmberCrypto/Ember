include MainTransactions

proc mainPersonal(
  db: WalletDB,
  functions: GlobalFunctionBox,
  transactions: ref Transactions
) {.forceCheck: [].} =
  functions.personal.getMinerWallet = proc (): MinerWallet {.forceCheck: [
    ValueError
  ].} =
    if db.miner.isNil:
      raise newException(ValueError, "Meros is running as a WatchWallet and has no Merit Holder.")
    result = db.miner

  functions.personal.getMnemonic = proc (): string {.forceCheck: [
    ValueError
  ].} =
    try:
      result = db.getMnemonic()
    except ValueError as e:
      raise e

  functions.personal.setAccount = proc (
    key: EdPublicKey,
    chainCode: Hash[256],
    clear: bool = false
  ) {.forceCheck: [].} =
    if clear:
      db.clearPrivateKeys()

    var datas: seq[Data]
    block handleDatas:
      #Start with the initial data, discovering spenders until the tip.
      var initial: Data
      try:
        initial = newData(Hash[256](), key.serialize())
      except ValueError as e:
        panic("Couldn't create an initial Data to discover a Data tip: " & e.msg)
      try:
        discard transactions[][initial.hash]
      #No Datas.
      except IndexError:
        break handleDatas

      var
        last: Hash[256] = initial.hash
        spenders: seq[Hash[256]] = transactions[].loadSpenders(newInput(last))
      while spenders.len != 0:
        last = spenders[0]
        spenders = transactions[].loadSpenders(newInput(last))

      #Grab the chain.
      try:
        datas = @[cast[Data](transactions[][last])]
        while datas[^1].inputs[0].hash != Hash[256]():
          datas.add(cast[Data](transactions[][datas[^1].inputs[0].hash]))
      except IndexError as e:
        panic("Couldn't get a Data chain from a discovered tip: " & e.msg)

    db.setAccount(
      key,
      chainCode,
      datas,
      proc (
        key: EdPublicKey
      ): bool {.gcsafe, forceCheck: [].} =
        transactions[].loadIfKeyWasUsed(key)
    )

  functions.personal.setWallet = proc (
    mnemonic: string,
    password: string
  ) {.forceCheck: [
    ValueError
  ].} =
    var wallet: InsecureWallet
    if mnemonic.len == 0:
      wallet = newWallet(password)
    else:
      try:
        wallet = newWallet(mnemonic, password)
      except ValueError as e:
        raise e

    db.setMinerAndMnemonic(wallet)

    try:
      let account: HDWallet = wallet.hd[0]
      functions.personal.setAccount(account.publicKey, account.chainCode)
    except ValueError as e:
      panic("Account zero wasn't usable despite the above newWallet call making sure it was usable: " & e.msg)

  functions.personal.getAccount = proc (): tuple[key: EdPublicKey, chainCode: Hash[256]] {.forceCheck: [].} =
    (key: db.accountZero, chainCode: db.chainCode)

  functions.personal.getAddress = proc (
    index: Option[uint32]
  ): string {.gcsafe, forceCheck: [
    ValueError
  ].} =
    try:
      result = db.getAddress(
        index,
        proc (
          key: EdPublicKey
        ): bool {.gcsafe, forceCheck: [].} =
          transactions[].loadIfKeyWasUsed(key)
      )
    except ValueError as e:
      raise e

  functions.personal.getChangeKey = proc (): EdPublicKey {.gcsafe, forceCheck: [].} =
    db.getChangeKey(
      proc (
        key: EdPublicKey
      ): bool {.gcsafe, forceCheck: [].} =
        transactions[].loadIfKeyWasUsed(key)
    )

  functions.personal.getKeyIndex = proc (
    key: EdPublicKey
  ): KeyIndex {.gcsafe, forceCheck: [
    IndexError
  ].} =
    try:
      result = db.getKeyIndex(key)
    except IndexError as e:
      raise e

  functions.personal.sign = proc (
    send: Send,
    keys: seq[KeyIndex],
    password: string
  ) {.gcsafe, forceCheck: [
    IndexError,
    ValueError
  ].} =
    try:
      db.getAggregateKey(keys, password).sign(send)
    except IndexError as e:
      raise e
    except ValueError as e:
      raise e

  functions.personal.data = proc (
    dataStr: string,
    password: string
  ): Future[Hash[256]] {.forceCheck: [
    ValueError
  ], async.} =
    #Create the Data.
    try:
      db.stepData(password, dataStr, functions.consensus.getDataDifficulty())
    except ValueError as e:
      raise e

    #[
    We now need to add this Data.
    That said, we may need to add Datas before it if either:
    A) We didn't have an initial Data.
    B) We created a Data and then rebooted before the Transactions DB was saved to disk.
    Because of that, the following iterative approach is used to add all 'new' Datas.
    ]#
    var toAdd: seq[Data] = @[]
    for data in db.loadDatasFromTip():
      toAdd.add(data)

      #We have the Data it relies on.
      try:
        discard transactions[][data.inputs[0].hash]
        break
      except IndexError:
        discard

    for d in countdown(high(toAdd), 0):
      try:
        await functions.transactions.addData(toAdd[d])
      except ValueError as e:
        panic("Data from the WalletDB was invalid: " & e.msg)
      #Another async process, AKA the network, added it.
      #There is concern about a race condition where we create multiple Datas sharing an input.
      #Due to the synchronous outsourcing to the WalletDB, this is negated.
      except DataExists:
        continue
      except Exception as e:
        panic("addData threw an Exception despite catching every Exception: " & e.msg)

    result = toAdd[0].hash

  functions.personal.getUTXOs = proc (): seq[UsableInput] {.forceCheck: [].} =
    db.getUTXOs(transactions)
