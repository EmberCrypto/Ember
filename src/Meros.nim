#[
The Main files are an "include chain". They include each other sequentially, in the following order:
  MainImports
  MainChainParams
  MainDatabase
  MainReorganization
  MainMerit
  MainConsensus
  MainTransactions
  MainPersonal
  MainNetwork
  MainInterfaces

We could include all of them in this file, but then all the other files would throw errors.
IDEs can't, and shouldn't, detect that an external file includes that file, and the external file resolves the dependency requirements.
]#

#Include the last file in the chain.
include MainInterfaces

#Create the configuration.
let globalConfig: Config = newConfig()

#Start the logger.
if not (addr defaultChroniclesStream.output).open(globalConfig.dataDir / globalConfig.logFile, fmAppend):
  echo "Couldn't open the log file."
  quit(0)

#Enable running main on a thread since the GUI needs to run on the main thread under some OSs.
proc main() {.thread.} =
  var
    #Reload the Config due to the threading rules.
    config: Config = newConfig()
    params: ChainParams = newChainParams(config.network)
    functions: GlobalFunctionBox = newGlobalFunctionBox()

    database: DB
    wallet: WalletDB

    #Merit is already a ref object. That said, we need to assign to it, and `var ref`s are illegal.
    merit: ref Merit = new(ref Merit)
    blockLock: ref Lock = new(Lock)
    innerBlockLock: ref Lock = new(Lock)
    lockedBlock: ref Hash[256] = new(Hash[256])

    consensus: ref Consensus = new(Consensus)

    transactions: ref Transactions = new(Transactions)

    #Network is also already a ref object. Same case as Merit.
    network: ref Network = new(ref Network)

    rpc: RPC

  #Function to safely shut down all elements of the node.
  functions.system.quit = proc () {.forceCheck: [].} =
    #Shutdown the GUI.
    try:
      fromMain.send("shutdown")
    except DeadThreadError as e:
      echo "Couldn't shutdown the GUI due to a DeadThreadError: " & e.msg
    except Exception as e:
      echo "Couldn't shutdown the GUI due to an Exception: " & e.msg

    #Shutdown the RPC.
    rpc.shutdown()

    #Shut down the Network.
    network[].shutdown()

    #Shut down the databases.
    try:
      database.close()
      wallet.close()
    except DBError as e:
      echo "Couldn't shutdown the DB: " & e.msg

    #Quit.
    quit(0)

  initLock(blockLock[])
  initLock(innerBlockLock[])

  #Spawn everything.
  mainDatabase(config, database, wallet)
  mainMerit(params, database, wallet, functions, merit, consensus, transactions, network, blockLock, innerBlockLock, lockedBlock)
  mainConsensus(params, database, functions, merit[], consensus, transactions, network)
  mainTransactions(database, wallet, functions, merit[], consensus, transactions)
  mainPersonal(wallet, functions, transactions)
  mainNetwork(params, config, functions, network)
  mainRPC(config, functions, rpc)

  runForever()

#If we weren't compiled with a GUI, directly run main.
when defined(nogui):
  main()
#We were compiled with a GUI.
else:
  #The GUI is disabled by the config.
  if not globalConfig.gui:
    main()
  #Spawn the GUI.
  else:
    #Spawn main on a thread.
    spawn main()
    #Run the GUI on the main thread,
    mainGUI()
    #If WebView exits, perform a safe shutdown.
    toRPC.send(%* {
      "module": "system",
      "method": "quit",
      "args": []
    })
