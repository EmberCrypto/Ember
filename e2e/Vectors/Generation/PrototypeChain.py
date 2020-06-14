#Simplified chain construction API.
#Automatically handles keeping Merit Holders' Merit Unlocked, unless told otherwise.

from typing import Union, List
from hashlib import blake2b

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty, SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty, SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Classes.Merit.Blockchain import BlockHeader, BlockBody, Block, Blockchain

class GenerationError(
  Exception
):
  pass

def signElement(
  key: PrivateKey,
  elem: Element
) -> Signature:
  if isinstance(elem, SendDifficulty):
    sendDiff: SignedSendDifficulty = SignedSendDifficulty(elem.difficulty, elem.nonce)
    sendDiff.sign(elem.holder, key)
    return sendDiff.signature

  if isinstance(elem, DataDifficulty):
    dataDiff: SignedDataDifficulty = SignedDataDifficulty(elem.difficulty, elem.nonce)
    dataDiff.sign(elem.holder, key)
    return dataDiff.signature

  if isinstance(elem, MeritRemoval):
    return Signature.aggregate([
      signElement(key, elem.e1),
      signElement(key, elem.e2)
    ])

  raise GenerationError("Tried to sign an Element in a Block we didn't recognize the type of.")

#pylint: disable=too-few-public-methods
class PrototypeBlock:
  def __init__(
    self,
    packets: List[VerificationPacket],
    elements: List[Element],
    significant: int,
    minerKey: PrivateKey,
    minerID: Union[bytes, int],
    time: int,
    privateKeys: List[PrivateKey]
  ) -> None:
    #Store all the arguments relevant to this specific Block.
    self.packets: List[VerificationPacket] = packets
    self.elements: List[Element] = elements
    self.significant: int = significant
    self.minerKey: PrivateKey = minerKey
    self.minerID: Union[bytes, int] = minerID
    self.time: int = time

    #Create the signatures for every packet/element.
    signatures: List[Signature] = []
    for packet in self.packets:
      for holder in packet.holders:
        verif: SignedVerification = SignedVerification(packet.hash, holder)
        verif.sign(holder, privateKeys[holder])
        signatures.append(verif.signature)
    for element in self.elements:
      signatures.append(signElement(privateKeys[element.holder], element))

    #Set the aggregate.
    self.aggregate: Signature = Signature.aggregate(signatures)

  def finish(
    self,
    keepUnlocked: bool,
    genesis: bytes,
    prev: BlockHeader,
    diff: int,
    privateKeys: List[PrivateKey]
  ) -> Block:
    #Only add the Data if:
    #1) We're supposed to make sure Merit Holders are always Unloocked
    #2) The last Block created a Data.
    if keepUnlocked and (prev.last != genesis):
      #Create the Data from the last Block.
      blockData: Data = Data(genesis, prev.hash)

      #Create Verifications for said Data with every Private Key.
      #Ensures no one has their Merit locked.
      #pylint: disable=unnecessary-comprehension
      self.packets.append(VerificationPacket(blockData.hash, [i for i in range(len(privateKeys))]))
      dataSigs: List[Signature] = [self.aggregate]
      for i, privKey in enumerate(privateKeys):
        verif: SignedVerification = SignedVerification(blockData.hash, i)
        verif.sign(i, privKey)
        dataSigs.append(verif.signature)

      #Don't use the latest miner if they don't have Merit.
      if isinstance(self.minerID, bytes):
        del self.packets[-1].holders[-1]
        del dataSigs[-1]

      #Recreate the aggregate.
      self.aggregate = Signature.aggregate(dataSigs)

    #Create the actual Block.
    result: Block = Block(
      BlockHeader(
        0,
        prev.hash,
        BlockHeader.createContents(self.packets, self.elements),
        self.significant,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), self.packets),
        self.minerID,
        self.time
      ),
      BlockBody(self.packets, self.elements, self.aggregate)
    )
    result.mine(self.minerKey, diff)
    return result

class PrototypeChain:
  timeOffset: int
  minerKeys: List[PrivateKey]
  blocks: List[PrototypeBlock]

  def add(
    self,
    nick: int = 0,
    packets: List[VerificationPacket] = [],
    elements: List[Element] = []
  ) -> None:
    #Determine if this is a new miner or not.
    miner: Union[bytes, int]
    if nick > len(self.minerKeys):
      raise GenerationError("Told to mine a Block with a miner nick which doesn't exist.")
    if nick == len(self.minerKeys):
      #If it is, generate the relevant key.
      self.minerKeys.append(PrivateKey(blake2b(nick.to_bytes(2, "big"), digest_size=32).digest()))
      miner = self.minerKeys[-1].toPublicKey().serialize()
    else:
      miner = nick

    timeBase: int
    if len(self.blocks) == 0:
      timeBase = Blockchain().blocks[0].header.time
    else:
      timeBase = self.blocks[-1].time

    #Create and add the PrototypeBlock.
    self.blocks.append(
      PrototypeBlock(
        #Create copies of the lists used as arguments to ensure we don't mutate the arguments.
        list(packets),
        list(elements),
        1,
        self.minerKeys[nick],
        miner,
        timeBase + self.timeOffset,
        self.minerKeys
      )
    )

  def __init__(
    self,
    blankBlocks: int = 0,
    keepUnlocked: bool = True,
    timeOffset: int = 1200
  ) -> None:
    self.keepUnlocked: bool = keepUnlocked
    self.timeOffset = timeOffset
    self.minerKeys = []
    self.blocks = []

    for _ in range(blankBlocks):
      self.add()

  def finish(
    self
  ) -> Blockchain:
    blockchain: Blockchain = Blockchain()

    for block in self.blocks:
      blockchain.add(
        block.finish(
          self.keepUnlocked,
          blockchain.genesis,
          blockchain.blocks[-1].header,
          blockchain.difficulty(),
          self.minerKeys
        )
      )

    return blockchain
