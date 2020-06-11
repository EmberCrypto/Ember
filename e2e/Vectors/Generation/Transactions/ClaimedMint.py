from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Merit

bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blankBlocks: List[Dict[str, Any]] = json.loads(bbFile.read())
bbFile.close()

transactions: Transactions = Transactions()
merit: Merit = Merit()
dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

for i in range(5):
  merit.add(Block.fromJSON(blankBlocks[i]))

#Create the Data.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(dataFilter)
transactions.add(data)

#Verify it.
verif: SignedVerification = SignedVerification(data.hash)
verif.sign(0, blsPrivKey)

#Generate another 6 Blocks.
#Next block should have a packet.
block: Block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    BlockHeader.createContents([VerificationPacket(verif.hash, [0])]),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), [VerificationPacket(verif.hash, [0])]),
    0,
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([VerificationPacket(verif.hash, [0])], [], verif.signature)
)
for _ in range(6):
  block.mine(blsPrivKey, merit.blockchain.difficulty())
  merit.add(block)
  print("Generated Claimed Mint Block " + str(len(merit.blockchain.blocks) - 1) + ".")

  block = Block(
    BlockHeader(
      0,
      merit.blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      merit.blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

#Claim the new Mint.
claim: Claim = Claim([(merit.mints[0].hash, 0)], edPubKey.to_bytes())
claim.amount = merit.mints[0].outputs[0][1]
claim.sign([blsPrivKey])
transactions.add(claim)

#Verify the Claim.
verif = SignedVerification(claim.hash)
verif.sign(0, blsPrivKey)

#Mine one more Block.
block = Block(
  BlockHeader(
    0,
    merit.blockchain.last(),
    BlockHeader.createContents([VerificationPacket(verif.hash, [0])]),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), [VerificationPacket(verif.hash, [0])]),
    0,
    merit.blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([VerificationPacket(verif.hash, [0])], [], verif.signature)
)
block.mine(blsPrivKey, merit.blockchain.difficulty())
merit.add(block)
print("Generated Claimed Mint Block " + str(len(merit.blockchain.blocks) - 1) + ".")

result: Dict[str, Any] = {
  "blockchain": merit.blockchain.toJSON(),
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Transactions/ClaimedMint.json", "w")
vectors.write(json.dumps(result))
vectors.close()
