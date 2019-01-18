#Message/Network objects.
import objects/MessageObj
import objects/NetworkObj

#Events lib.
import mc_events

#Networking standard libs.
import asyncnet, asyncdispatch

#Listen on a port.
proc listen*(network: Network, port: uint) {.async.} =
    #Start listening.
    network.server.setSockOpt(OptReuseAddr, true)
    network.server.bindAddr(Port(port))
    network.server.listen()

    #Accept new connections infinitely.
    while not network.server.isClosed():
        #This is in a try/catch since ending the server while accepting a new Client will throw an Exception.
        try:
            #Tell the Network lib of the new client.
            network.subEvents.get(
                proc (client: tuple[address: string, client: AsyncSocket]),
                "client"
            )(
                await network.server.acceptAddr()
            )
        except:
            continue
