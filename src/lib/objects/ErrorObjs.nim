#Errors objects, providing easy access to ForceCheck and defining all our custom errors.

import json

import ForceCheck
export ForceCheck

import mc_lmdb
import mc_bls
export BLSError

import ../Hash/objects/HashObj

import ../../Database/Consensus/Elements/objects/ElementObj

type
  #lib Errors.
  SaltError*   = object of CatchableError #Used when a sketch salt causes a collision.

  #Database/common Statuses.
  DataMissing* = object of CatchableError #Used when data is missing. Also used by Network for the same reason.
  DataExists*  = object of CatchableError #Used when trying to add data which was already added.

  #Database/Filesystem Errors.
  DBError*     = LMDBError
  DBReadError* = object of DBError #Used when reading from the DB fails.

  #Database/Consensus Statuses.
  MaliciousMeritHolder* = object of CatchableError #Used when a MeritHolder commits a malicious act against the network.
    #This will be created with the qactual MR or the pair Element, depending on the circumstances.
    #These used to be the same field, until Merit Removals were made implicit, and no longer a descendant of Element.
    element*: Element
    removalRef*: MeritRemovalParent
  UnfinalizedParents* = object of CatchableError #Status used when we try to finalize a family which relies on another.

  #Database/Merit Statuses.
  NotInEpochs*   = object of CatchableError #Used when we try to add a Hash to Epochs and it's not already present in said Epochs.
  NotEnoughWork* = object of CatchableError #Used when we consider an alternate chain, yet decline it due to a lack of work required to trigger a reorg.

  #Network Errors.
  SocketError* = object of CatchableError #Used when a socket breaks.
  PeerError*   = object of CatchableError #Used when a Peer breaks protocol.

  #Network Statuses.
  Spam* = object of CatchableError #Used when a Send/Data doesn't beat the difficulty.
    #Hash of the Transaction.
    hash*: Hash[256]
    #Argon hash.
    argon*: Hash[256]
    #Difficulty the argon hash was multiplied by.
    difficulty*: uint32

  #Interfaces/RPC Errors.
  RPCAuthorizationError* = object of CatchableError #Used when a method which requires authorization is called without it.
  ParamError*            = object of CatchableError #Used when an invalid parameter is passed.
  JSONRPCError*          = object of CatchableError #Used when the RPC call errors.
    code*: int
    data*: JSONNode

  #Interfaces/GUI Errors.
  WebViewError* = object of CatchableError #Used when WebView fails.
  RPCError*     = object of CatchableError #Used when the GUI makes an invalid RPC call.

  #Interfaces Statuses.
  NotEnoughMeros* = object of CatchableError #Used when the RPC is instructed to create a Send for more Meros than it can.
