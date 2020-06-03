import math
import strutils
import tables

import chronos

import ../lib/[Errors, Util]

import ../Database/Merit/objects/BlockObj
import ../Database/Consensus/Elements/Elements

import objects/[MessageObj, SocketObj, SketchyBlockObj, LiveManagerObj, NetworkObj]
export MessageObj, SketchyBlockObj, NetworkObj

import FileLimitTracker, Peer, SyncManager
export Peer, SyncManager

import Serialize/SerializeCommon

#Verify the validity of an address.
#If the address isn't IPv4, it's invalid (unfortunately).
#If the IP is ours, it's invalid. We check later if it's our public IP.
#If the IP already has both sockets, it's invalid.
proc verifyAddress(
  network: Network,
  address: TransportAddress,
  handshake: MessageType
): tuple[
  ip: string,
  valid: bool,
  hasLive: bool,
  hasSync: bool
] {.forceCheck: [].} =
  if address.family != AddressFamily.IPv4:
    result.valid = false
    return

  result.ip = char(address.address_v4[0]) & char(address.address_v4[1]) & char(address.address_v4[2]) & char(address.address_v4[3])
  if address.address_v4 == [127'u8, 0, 0, 1]:
    #Append the port to support multiple connections from localhost.
    result.ip &= uint16(address.port).toBinary(PORT_LEN)

    #If there's already a local peer missing this type of socket, use that IP.
    #Mostly, yet sometimes inaccurate, attempt at linking live/sync sockets.
    if (
      (not network.lastLocalPeer.isNil) and
      (
        ((handshake == MessageType.Handshake) and (network.lastLocalPeer.live.isNil or network.lastLocalPeer.live.closed)) or
        ((handshake == MessageType.Syncing) and (network.lastLocalPeer.sync.isNil or network.lastLocalPeer.sync.closed))
      )
    ):
      result.ip = network.lastLocalPeer.ip
  result.hasLive = network.live.hasKey(result.ip)
  result.hasSync = network.sync.hasKey(result.ip)

  result.valid = not (
    #Most common cases.
    (result.hasLive and (handshake == MessageType.Handshake)) or
    (result.hasSync and (handshake == MessageType.Syncing)) or
    (result.hasLive and result.hasSync) or
    #A malicious case.
    address.isMulticast() or
    #Invalid address.
    address.isZero() or
    #This should never happen.
    address.isUnspecified()
  )

  #If the result is valid, we still need to check if it's a loopback.
  #This will be the most malicious case.
  #Loopbacks are allowed IF it's 127.0.0.1 AND to a different node.
  #This could be merged with the above result.valid declaration statement yet isn't for readability.
  if (
    result.valid and
    address.isLoopback() and
    (
      #If the address isn't 127.0.0.1, this result isn't valid.
      (address.address_v4 != [127'u8, 0, 0, 1]) or
      #If we're listening and this is our port, this address isn't valid.
      (
        ((not network.server.isNil) and (network.server.status == ServerStatus.Running)) and
        #This works for client connections as well because the source port will never equal the listening port.
        (address.port == Port(network.liveManager.port))
      )
    )
  ):
    result.valid = false

proc isOurPublicIP(
  socket: SocketObj.Socket
): bool {.forceCheck: [].} =
  try:
    result = (
      (socket.localAddress.address_v4 == socket.remoteAddress.address_v4) and
      (socket.localAddress.address_v4 != [127'u8, 0, 0, 1])
    )
  #If we couldn't get the local or peer address, we can either panic or shut down this socket.
  #The safe way to shut down the socket is to return that's invalid.
  #That said, this can have side effects when we implement peer karma.
  except TransportOSError:
    result = true

proc connect*(
  network: Network,
  address: string,
  port: int
) {.forceCheck: [], async.} =
  logDebug "Connecting", address = address, port = port

  #Lock the IP to stop multiple connections from happening at once.
  #We unlock the IP where we call connect.
  #If it's already locked, don't bother trying to connect.
  try:
    if not await network.lockIP(address):
      return
  except Exception as e:
    panic("Locking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

  #Create a TransportAddress and verify it.
  var
    tAddy: TransportAddress
    verified: tuple[
      ip: string,
      valid: bool,
      hasLive: bool,
      hasSync: bool
    ]
  try:
    tAddy = initTAddress(address, port)
  except TransportAddressError:
    return
  verified = network.verifyAddress(tAddy, MessageType.End)
  if not verified.valid:
    try:
      await network.unlockIP(address)
    except Exception as e:
      panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
    return

  #Create a socket.
  var socket: SocketObj.Socket
  try:
    #Make sure we have the file for that.
    if network.fileTracker.allocateSocket() == PeerStatus.Busy:
      raise newException(Exception, "")

    socket = await newSocket(tAddy)
    if socket.isOurPublicIP():
      raise newException(Exception, "")
  except Exception:
    socket.safeClose("Either couldn't connect or connected to ourself.")
    try:
      await network.unlockIP(address)
    except Exception as e:
      panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
    return

  #Variable for the peer.
  var peer: Peer

  #If we already have a live connection, set the sync socket.
  if verified.hasLive:
    try:
      peer = network.peers[network.live[verified.ip]]
      network.sync[verified.ip] = network.live[verified.ip]
    except KeyError:
      panic("Peer has a live socket but either not an entry in the live table or the peers table.")
    peer.sync = socket
  #If we already have a sync socket, set the live socket.
  elif verified.hasSync:
    try:
      peer = network.peers[network.sync[verified.ip]]
      network.live[verified.ip] = network.sync[verified.ip]
    except KeyError:
      panic("Peer has a sync socket but either not an entry in the sync table or the peers table.")
    peer.live = socket
  #If we don't have a peer, create one and set both sockets.
  else:
    peer = newPeer(verified.ip)
    peer.sync = socket

    try:
      #Make sure we have the file for the new socket.
      if network.fileTracker.allocateSocket() == PeerStatus.Busy:
        raise newException(Exception, "")
      peer.live = await newSocket(tAddy)
    except Exception:
      discard

    #Add it to the network.
    network.add(peer)
    network.live[verified.ip] = peer.id
    network.sync[verified.ip] = peer.id

  try:
    await network.unlockIP(address)
  except Exception as e:
    panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

  #Handle the connections.
  logDebug "Handling Client connection", id = peer.id, address = address, port = port

  try:
    if not verified.hasSync:
      asyncCheck network.syncManager.handle(peer, socket.remoteAddress)
    if not verified.hasLive:
      asyncCheck network.liveManager.handle(peer, socket.remoteAddress)
  except TransportOSError as e:
    panic("Couldn't get the remote address of a socket we've already gotten the remote address of: " & e.msg)
  except Exception as e:
    panic("Handling a new connection raised an Exception despite not throwing any Exceptions: " & e.msg)

#Create a function to handle a new connection.
proc handle(
  network: Network
): proc (
  server: StreamServer,
  rawSocket: StreamTransport
): Future[void] {.gcsafe.} {.inline, gcsafe, forceCheck: [].} =
  result = proc (
    server: StreamServer,
    rawSocket: StreamTransport
  ) {.forceCheck: [], async.} =
    #Wrap the StreamTransport.
    var socket: SocketObj.Socket = newSocket(rawSocket)

    #Check if we have the file to handle this socket.
    if network.fileTracker.allocateSocket() == PeerStatus.Busy:
      var
        peers: seq[Peer] = network.peers.getPeers(
          min(network.peers.len, 4),
          0,
          server = true
        )
        busy: Message = newMessage(MessageType.Busy, peers.len.toBinary(BYTE_LEN))
      for peer in peers:
        busy.message &= peer.ip[0 ..< IP_LEN] & peer.port.toBinary(PORT_LEN)
      try:
        await socket.send(busy.serialize())
      except Exception:
        discard
      socket.safeClose("We are busy.")
      return

    #Get their address.
    var address: string
    try:
      address = $IpAddress(
        family: IpAddressFamily.IPv4,
        address_v4: socket.remoteAddress.address_v4
      )
    except TransportOSError as e:
      socket.safeClose("Couldn't get the socket's remote address: " & e.msg)
      return
    logDebug "Accepting ", address = address

    #Receive the Handshake.
    var handshake: Message
    try:
      handshake = await recv(0, socket, HANDSHAKE_LENS)
    except SocketError:
      return
    except PeerError as e:
      socket.safeClose("Invalid handshake: " & e.msg)
      return
    except Exception as e:
      panic("Couldn't receive from a socket despite catching all errors recv throws: " & e.msg)
    if handshake.content == MessageType.Busy:
      socket.safeClose("Client who connected to us claimed to be busy.")
      return

    #Lock the IP, passing the type of the Handshake.
    #Since up to two client connections can exist, it's fine if there's already one, as long as they're of different types.
    var lock: byte = if handshake.content == MessageType.Handshake: LIVE_IP_LOCK else: SYNC_IP_LOCK
    try:
      if not await network.lockIP(address, lock):
        socket.safeClose("Already handling a socket of this type from this IP.")
        return
    except Exception as e:
      panic("Locking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    var verified: tuple[
      ip: string,
      valid: bool,
      hasLive: bool,
      hasSync: bool
    ]
    try:
      verified = network.verifyAddress(socket.remoteAddress, handshake.content)
    except TransportOSError:
      verified.valid = false
    if (not verified.valid) or socket.isOurPublicIP():
      socket.safeClose("Invalid address or our own address.")
      try:
        await network.unlockIP(address, lock)
      except Exception as e:
        panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)
      return

    var peer: Peer
    #If there's a sync socket, this is a live socket.
    if verified.hasSync:
      try:
        peer = network.peers[network.sync[verified.ip]]
      except KeyError as e:
        panic("Couldn't get a Peer who has a sync socket via the sync table: " & e.msg)

      peer.live = socket
      network.live[verified.ip] = peer.id
    #If there's a live socket, this is a sync socket.
    elif verified.hasLive:
      try:
        peer = network.peers[network.live[verified.ip]]
      except KeyError as e:
        panic("Couldn't get a Peer who has a live socket via the live table: " & e.msg)

      peer.sync = socket
      network.sync[verified.ip] = peer.id
    #If there's no socket, we need to switch off of the handshake.
    else:
      peer = newPeer(verified.ip)
      network.add(peer)
      if handshake.content == MessageType.Handshake:
        peer.live = socket
        network.live[verified.ip] = peer.id
      else:
        peer.sync = socket
        network.sync[verified.ip] = peer.id

    #Unlock the IP.
    try:
      await network.unlockIP(address, lock)
    except Exception as e:
      panic("Unlocking an IP raised an Exception despite not raising any Exceptions: " & e.msg)

    try:
      if handshake.content == MessageType.Handshake:
        logDebug "Handling Live Server connection", id = peer.id, address = address
        asyncCheck network.liveManager.handle(peer, socket.remoteAddress, handshake)
      else:
        logDebug "Handling Sync Server connection", id = peer.id, address = address
        asyncCheck network.syncManager.handle(peer, socket.remoteAddress, handshake)
    except TransportOSError as e:
      panic("Couldn't get the remote address of a socket we've already gotten the remote address of: " & e.msg)
    except PeerError:
      network.disconnect(peer)
    except Exception as e:
      panic("Handling a socket threw an Exception despite catching all Exceptions: " & e.msg)

#Listen for new connections.
proc listen*(
  network: Network
) {.forceCheck: [], async.} =
  logDebug "Listening", port = network.liveManager.port

  #Update the services byte.
  network.liveManager.updateServices(SERVER_SERVICE)
  network.syncManager.updateServices(SERVER_SERVICE)

  #Create the server.
  try:
    network.server = createStreamServer(initTAddress("0.0.0.0", network.liveManager.port), handle(network), {ReuseAddr})
  except OSError as e:
    panic("Couldn't create the server due to an OSError: " & e.msg)
  except TransportAddressError as e:
    panic("Couldn't create the server due to an invalid address to listen on: " & e.msg)
  except Exception as e:
    panic("Couldn't create the server due to an Exception: " & e.msg)

  #Start listening.
  try:
    network.server.start()
  except OSError as e:
    panic("Couldn't start listening due to an OSError: " & e.msg)
  except TransportOSError as e:
    panic("Couldn't start listening due to an TransportOSError: " & e.msg)
  except Exception as e:
    panic("Couldn't start listening due to an Exception: " & e.msg)

  #Update the file limit tracker.
  network.fileTracker.update()

  #Don't return until the server closes.
  #This function should be called with asynccheck so this should mean nothing.
  #That said, the original function that was here (before we moved to chronos), had this behavior.
  #This is to limit potential side effects.
  try:
    await network.server.join()
  except Exception as e:
    panic("Couldn't join the server with this async function: " & e.msg)

proc broadcast*(
  network: Network,
  msg: Message
) {.forceCheck: [], async.} =
  #Peers we're broadcasting to.
  var recipients: seq[Peer] = network.peers.getPeers(
    max(
      min(network.peers.len, 3),
      int(ceil(sqrt(float(network.peers.len))))
    ),
    -1,
    live = true
  )

  for recipient in recipients:
    try:
      await recipient.sendLive(msg)
    except SocketError:
      discard
    except Exception as e:
      panic("Sending over a Live socket raised an Exception despite catching every Exception: " & e.msg)
