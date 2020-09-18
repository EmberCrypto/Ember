import json

import ed25519

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=False)

data: Data = Data(bytes(32), edPubKey.to_bytes())
data.signature = edPrivKey.sign(b"INVALID")
data.beat(dataFilter)

proto.add(packets=[VerificationPacket(data.hash, [0])])

with open("e2e/Vectors/Consensus/Verification/Parsable.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "data": data.toJSON()
  }))
