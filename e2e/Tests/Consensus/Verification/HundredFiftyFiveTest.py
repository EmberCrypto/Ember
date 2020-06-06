#https://github.com/MerosCrypto/Meros/issues/155

#Types.
from typing import Dict, List, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey

#Merit classes.
from e2e.Classes.Merit.Blockchain import BlockHeader
from e2e.Classes.Merit.Blockchain import BlockBody
from e2e.Classes.Merit.Blockchain import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Consensus classes.
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification

#Data class.
from e2e.Classes.Transactions.Data import Data

#TestError Exception.
from e2e.Tests.Errors import TestError

#Meros classes.
from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC

#Ed25519 lib.
import ed25519

#pylint: disable=too-many-locals,too-many-statements
def HundredFiftyFiveTest(
  rpc: RPC
) -> None:
  #Ed25519 keys.
  edPrivKeys: List[ed25519.SigningKey] = [
    ed25519.SigningKey(b'\0' * 32),
    ed25519.SigningKey(b'\1' * 32)
  ]
  edPubKeys: List[ed25519.VerifyingKey] = [
    edPrivKeys[0].get_verifying_key(),
    edPrivKeys[1].get_verifying_key()
  ]

  #BLS keys.
  blsPrivKey: PrivateKey = PrivateKey(bytes.fromhex(rpc.call("personal", "getMiner")))
  blsPubKey: bytes = blsPrivKey.toPublicKey().serialize()

  #Blockchain.
  blockchain: Blockchain = Blockchain()
  #Spam Filter.
  dataFilter: SpamFilter = SpamFilter(5)

  #Handshake with the node.
  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

  #Call getBlockTemplate just to get an ID.
  #Skips the need to write a sync loop for the BlockBody.
  template: Dict[str, Any] = rpc.call(
    "merit",
    "getBlockTemplate",
    [blsPubKey.hex()]
  )

  #Mine a Block.
  block = Block(
    BlockHeader(
      0,
      blockchain.blocks[0].header.hash,
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      blsPubKey,
      blockchain.blocks[0].header.time + 1200,
      0
    ),
    BlockBody()
  )
  block.mine(blsPrivKey, blockchain.difficulty())
  blockchain.add(block)

  #Publish it.
  rpc.call("merit", "publishBlock", [template["id"], block.serialize().hex()])

  if MessageType(rpc.meros.live.recv()[0]) != MessageType.BlockHeader:
    raise TestError("Meros didn't broadcast the Block we just published.")

  #Create the Datas.
  datas: List[Data] = [
    Data(bytes(32), edPubKeys[0].to_bytes()),
    Data(bytes(32), edPubKeys[1].to_bytes())
  ]

  for d in range(len(datas)):
    #Sign, and mine the Data.
    datas[d].sign(edPrivKeys[d])
    datas[d].beat(dataFilter)

    #Send the Data and verify Meros sends it back.
    if rpc.meros.liveTransaction(datas[d]) != rpc.meros.live.recv():
      raise TestError("Meros didn't send back the Data.")

    #Verify Meros sends back a Verification.
    res: bytes = rpc.meros.live.recv()
    if MessageType(res[0]) != MessageType.SignedVerification:
      raise TestError("Meros didn't send a SignedVerification.")

    verif: SignedVerification = SignedVerification(datas[d].hash)
    verif.sign(0, blsPrivKey)
    if res[1:] != verif.signedSerialize():
      raise TestError("Meros didn't send the correct SignedVerification.")
