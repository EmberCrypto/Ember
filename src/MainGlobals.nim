include MainChainParams

#Global variables used throughout Main.
var
    #Global Function Box.
    functions: GlobalFunctionBox = newGlobalFunctionBox()

    #Config.
    config: Config = newConfig()

    #Chain Parames.
    params: ChainParams

    #Consensus.
    consensus {.threadvar.}: Consensus
    smrLock: Lock

    #Merit.
    merit {.threadvar.}: Merit
    blockLock: ref Lock = new(Lock)
    innerBlockLock: ref Lock = new(Lock)
    lockedBlock: Hash[256]

    #Transactions.
    transactions {.threadvar.}: Transactions

    #DB.
    database {.threadvar.}: DB

    #WalletDB.
    wallet {.threadvar.}: WalletDB

    #Network.
    network {.threadvar.}: Network #Network.

    #Interfaces.
    fromMain: Channel[string] #Channel from the 'main' thread to the Interfaces thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

initLock(blockLock[])
initLock(innerBlockLock[])

case config.network:
    of "mainnet":
        echo "The mainnet has yet to launch."
        quit(0)

    of "testnet":
        params = ChainParams(
            GENESIS: "MEROS_DEVELOPER_TESTNET_2",

            BLOCK_TIME: 600,
            DEAD_MERIT: 1000,

            BLOCK_DIFFICULTY: 10000000,
            SEND_DIFFICULTY:  3,
            DATA_DIFFICULTY:  5,

            NETWORK_PROTOCOL: 0,
            NETWORK_ID: 0,

            SEEDS: @[
                (ip: "seed1.meroscrypto.io", port: 5132),
                (ip: "seed2.meroscrypto.io", port: 5132),
                (ip: "seed3.meroscrypto.io", port: 5132),
            ]
        )

    of "devnet":
        params = ChainParams(
            GENESIS: "MEROS_DEVELOPER_NETWORK",

            BLOCK_TIME: 60,
            DEAD_MERIT: 100,

            BLOCK_DIFFICULTY: 10000000,
            SEND_DIFFICULTY:  3,
            DATA_DIFFICULTY:  5,

            #By not using 255, we allow eventually extending these fields. If we read 255, we can also read an extra byte,
            NETWORK_PROTOCOL: 254,
            NETWORK_ID: 254,

            SEEDS: @[]
        )

    else:
        echo "Invalid network specified."
        quit(0)

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
    network.shutdown()

    #Shut down the databases.
    try:
        database.close()
        wallet.close()
    except DBError as e:
        echo "Couldn't shutdown the DB: " & e.msg

    #Quit.
    quit(0)

#Start the logger.
if not (addr defaultChroniclesStream.output).open(config.dataDir / config.logFile, fmAppend):
    echo "Couldn't open the log file."
    quit(0)
