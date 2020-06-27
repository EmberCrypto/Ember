from typing import IO, Any
import json

import ed25519

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

transactions: Transactions = Transactions()
dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(1)

#Create the Data and a successor.
first: Data = Data(bytes(32), edPubKey.to_bytes())
first.sign(edPrivKey)
first.beat(dataFilter)
transactions.add(first)

second: Data = Data(first.hash, bytes(1))
second.sign(edPrivKey)
second.beat(dataFilter)
transactions.add(second)

proto.add(
  packets=[
    VerificationPacket(first.hash, [0]),
    VerificationPacket(second.hash, [0])
  ]
)

for _ in range(5):
  proto.add()

#Create a Data competing with the now-finalized second Data.
competitor: Data = Data(first.hash, bytes(2))
competitor.sign(edPrivKey)
competitor.beat(dataFilter)
transactions.add(competitor)

proto.add(packets=[VerificationPacket(competitor.hash, [0])])

vectors: IO[Any] = open("e2e/Vectors/Transactions/CompetingFinalized.json", "w")
vectors.write(json.dumps({
  "blockchain": proto.toJSON(),
  "transactions": transactions.toJSON()
}))
vectors.close()
