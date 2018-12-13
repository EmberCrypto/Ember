include MainConstants

#Global variables used throughout Main.
var
    events: EventEmitter = newEventEmitter() #EventEmitter for queries and new data.

    #Merit.
    merit {.threadvar.}: Merit #Blockchain and state.

    #Lattice.
    lattice {.threadvar.}: Lattice  #Lattice.

    #Personal.
    miner: bool                  #Miner boolean.
    minerWallet: MinerWallet     #Miner Wallet.
    wallet {.threadvar.}: Wallet #Wallet.

    #Network.
    network {.threadvar.}: Network #Network.

    #UI.
    fromMain: Channel[string] #Channel from the 'main' thread to the UI thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

#If there are params...
if paramCount() > 0:
    #If the miner argument was passed...
    if paramStr(1) == "--miner":
        miner = true

        if paramCount() > 1:
            minerWallet = newMinerWallet(newBLSPrivateKeyFromBytes(paramStr(2)))
        else:
            raise newException(ValueError, "No BLS Private Key was passed with --miner.")

#Properly shutdown.
events.on(
    "system.quit",
    proc () {.raises: [ChannelError, AsyncError, SocketError].} =
        #Shutdown the GUI.
        try:
            fromMain.send("shutdown")
        except:
            raise newException(ChannelError, "Couldn't send shutdown to the GUI.")

        #Shutdown the RPC.
        rpc.shutdown()

        #Shut down the Network.
        network.shutdown()

        #Quit.
        quit(0)
)
