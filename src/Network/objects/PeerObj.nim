import random
import locks
import tables

import ../../lib/[Errors, Util]

import SocketObj

#[
Handshakes include service bytes, which are used to declare supported... services.
Right now, these are just used to say a peer is accepting connections as a server.
In the future, it can be used for protocol extensions which allow optimizations without a hardfork.
Or building a second layer communication network on top of the existing Meros network, through nodes who allow it.
]#
const SERVER_SERVICE*: byte = 0b10000000

type Peer* = ref object
  id*: int
  ip*: string

  #Whether or not the server service bit has been set.
  server*: bool
  #Port of their server, if one exists.
  port*: int

  #Time of their last message.
  last*: uint32

  #Lock used to append to the pending sync requests.
  syncLock*: Lock
  #Pending sync requests. The int refers to an ID in the SyncManager's table.
  #This seq is used to handle sync responses from this peer, specifically.
  #Verifying they're ordered and knowing how to hand them off.
  requests*: seq[int]

  live*: Socket
  sync*: Socket

proc newPeer*(
  ip: string,
): Peer {.forceCheck: [].} =
  result = Peer(
    ip: ip,
    last: getTime()
  )
  initLock(result.syncLock)

#Check if a Peer is closed.
func isClosed*(
  peer: Peer
): bool {.inline, forceCheck: [].} =
  (
    peer.live.isNil or peer.live.closed
  ) and (
    peer.sync.isNil or peer.sync.closed
  )

proc close*(
  peer: Peer,
  reason: string
) {.forceCheck: [].} =
  peer.live.safeClose("")
  peer.sync.safeClose("")

  logDebug "Closing peer", id = peer.id, reason = reason

#Get random peers which meet the specified criteria.
proc getPeers*(
  peers: TableRef[int, Peer],
  reqArg: int,
  #Peer to skip. Used when rebroadcasting and we don't want to rebroadcast back to the source.
  skip: int = 0,
  #Only get peers with a live socket.
  live: bool = false,
  #Only get peers who are servers. Used when asked for peers to connect to.
  server: bool = false
): seq[Peer] {.forceCheck: [].} =
  if peers.len == 0:
    return

  var
    #Copied so we can mutate req.
    req: int = reqArg
    peersLeft: int = peers.len

  for peer in peers.values():
    if rand(peersLeft - 1) < req:
      dec(peersLeft)
      if server and (not peer.server):
        continue

      if live and (peer.live.isNil or peer.live.closed):
        continue

      if peer.id == skip:
        continue

      #Add the peer to the result and lower the amount of requested peers.
      result.add(peer)
      dec(req)
