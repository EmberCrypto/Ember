#Numerical libs.
import BN
import ../lib/Base

#Message/Network objects.
import objects/MessageObj
import objects/NetworkObj

#Events lib.
import ec_events

#Networking standard libs.
import asyncnet, asyncdispatch

#Listen on a port.
proc listen*(network: Network, port: int) {.async.} =
    #Start listening.
    network.server.setSockOpt(OptReuseAddr, true)
    network.server.bindAddr(Port(port))
    network.server.listen()

    #Accept new connections infinitely.
    while true:
        #Tell the network lib of the new client.
        network.subEvents.get(
            proc (client: AsyncSocket),
            "server"
        )(
            await network.server.accept()
        )
