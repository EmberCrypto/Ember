import tables

import chronos

import ../../lib/[Errors, Util, Hash]

import ../../objects/GlobalFunctionBoxObj

import ../../Database/Merit/objects/BlockHeaderObj
import ../../Database/Consensus/Elements/Elements
import ../../Database/Transactions/Transaction

import MessageObj
import SocketObj
import ../Peer as PeerFile

import ../Serialize/SerializeCommon
import ../Serialize/Merit/ParseBlockHeader
import ../Serialize/Consensus/[
  ParseVerification,
  ParseSendDifficulty,
  ParseDataDifficulty,
  ParseMeritRemoval
]
import ../Serialize/Transactions/[ParseClaim, ParseSend, ParseData]

type LiveManager* = ref object
  protocol*: int
  network*: int
  services*: char
  port*: int

  peers: TableRef[int, Peer]

  functions*: GlobalFunctionBox

func newLiveManager*(
  protocol: int,
  network: int,
  port: int,
  peers: TableRef[int, Peer],
  functions: GlobalFunctionBox
): LiveManager {.inline, forceCheck: [].} =
  LiveManager(
    protocol: protocol,
    network: network,
    port: port,

    peers: peers,

    functions: functions
  )

func updateServices*(
  manager: LiveManager,
  service: byte
) {.inline, forceCheck: [].} =
  manager.services = char(byte(manager.services) or service)

proc handle*(
  manager: LiveManager,
  peer: Peer,
  tAddy: TransportAddress,
  handshake: Message = newMessage(MessageType.End)
) {.forceCheck: [], async.} =
  #Send our Handshake and get their Handshake.
  try:
    await peer.sendLive(newMessage(
      MessageType.Handshake,
      char(manager.protocol) &
      char(manager.network) &
      manager.services &
      manager.port.toBinary(PORT_LEN) &
      manager.functions.merit.getTail().serialize()
    ))
  except SocketError:
    return
  except Exception as e:
    panic("Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

  var msg: Message = handshake
  if msg.content == MessageType.End:
    try:
      msg = await peer.recvLive()
    except SocketError:
      return
    except PeerError as e:
      peer.close(e.msg)
      return
    except Exception as e:
      panic("Handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

  if msg.content == MessageType.Busy:
    peer.live.safeClose("Server we connected to was busy.")
    try:
      for p in 0 ..< msg.message[0].fromBinary():
        var ip: string = msg.message[BYTE_LEN + (p * PEER_LEN) ..< BYTE_LEN + (p * PEER_LEN) + IP_LEN]
        asyncCheck manager.functions.network.connect(
          $(ip[0].fromBinary()) & "." & $(ip[1].fromBinary()) & "." & $(ip[2].fromBinary()) & "." & $(ip[3].fromBinary()),
          msg.message[BYTE_LEN + (p * PEER_LEN) + IP_LEN ..< BYTE_LEN + (p * PEER_LEN) + PEER_LEN].fromBinary()
        )
    except IndexError as e:
      panic("Extracting peers from a Busy message raised an IndexError: " & e.msg)
    except Exception as e:
      panic("Calling connect due to a Busy message raised despite not throwing anything: " & e.msg)
    return
  elif msg.content != MessageType.Handshake:
    peer.close("Peer didn't send a Handshake.")
    return

  if int(msg.message[0]) != manager.protocol:
    peer.close("Peer uses a different protocol.")
    return

  if int(msg.message[1]) != manager.network:
    peer.close("Peer uses a different network.")
    return

  if (
    ((byte(msg.message[2]) and SERVER_SERVICE) == SERVER_SERVICE) and
    (not tAddy.isLoopback()) and
    (not tAddy.isLinkLocal()) and
    (not tAddy.isSiteLocal())
  ):
    peer.server = true

  peer.port = msg.message[3 ..< 5].fromBinary()

  #We don't bother with the initial tail as we do that for the Sync socket.

  #Receive and handle messages forever.
  while true:
    try:
      msg = await peer.recvLive()
    except SocketError:
      return
    except PeerError as e:
      peer.close(e.msg)
      return
    except Exception as e:
      panic("Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)

    try:
      case msg.content:
        of MessageType.Handshake:
          try:
            await peer.sendLive(
              newMessage(
                MessageType.BlockchainTail,
                manager.functions.merit.getTail().serialize()
              )
            )
          except SocketError:
            return
          except Exception as e:
            panic("Replying `BlockchainTail` in response to a keep-alive `Handshake` threw an Exception despite catching all thrown Exceptions: " & e.msg)

          #Add the tail.
          var tail: Hash[256] = msg.message[5 ..< 37].toHash[:256]()

          try:
            await manager.functions.merit.addBlockByHash(peer, tail)
          except Exception as e:
            panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

        of MessageType.BlockchainTail:
          #Get the hash.
          var tail: Hash[256] = msg.message[0 ..< 32].toHash[:256]()

          #Add the Block.
          try:
            await manager.functions.merit.addBlockByHash(peer, tail)
          except Exception as e:
            panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

        of MessageType.Claim:
          var claim: Claim = msg.message.parseClaim()
          manager.functions.transactions.addClaim(claim)

        of MessageType.Send:
          var send: Send = msg.message.parseSend(manager.functions.consensus.getSendDifficulty())
          manager.functions.transactions.addSend(send)

        of MessageType.Data:
          var data: Data = msg.message.parseData(manager.functions.consensus.getDataDifficulty())
          manager.functions.transactions.addData(data)

        of MessageType.SignedVerification:
          var verif: SignedVerification = msg.message.parseSignedVerification()
          manager.functions.consensus.addSignedVerification(verif)

        of MessageType.SignedSendDifficulty:
          var sendDiff: SignedSendDifficulty = msg.message.parseSignedSendDifficulty()
          manager.functions.consensus.addSignedSendDifficulty(sendDiff)

        of MessageType.SignedDataDifficulty:
          var dataDiff: SignedDataDifficulty = msg.message.parseSignedDataDifficulty()
          manager.functions.consensus.addSignedDataDifficulty(dataDiff)

        of MessageType.SignedMeritRemoval:
          var mr: SignedMeritRemoval = msg.message.parseSignedMeritRemoval()

          try:
            await manager.functions.consensus.addSignedMeritRemoval(mr)
          except ValueError as e:
            peer.close(e.msg)
            return
          except DataExists:
            continue
          except Exception as e:
            panic("Adding a SignedMeritRemoval threw an Exception despite catching all thrown Exceptions: " & e.msg)

        of MessageType.BlockHeader:
          try:
            await manager.functions.merit.addBlockByHeader(
              parseBlockHeaderWithoutHashing(msg.message),
              false
            )
          except ValueError as e:
            peer.close(e.msg)
            return
          except DataMissing:
            continue
          except DataExists:
            continue
          except Exception as e:
            panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

        else:
          peer.close("Peer sent an invalid Message type.")
          return
    except ValueError as e:
      peer.close(e.msg)
      return
    except Spam, DataExists:
      continue
