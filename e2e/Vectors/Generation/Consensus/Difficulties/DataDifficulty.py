import json

from e2e.Classes.Consensus.DataDifficulty import DataDifficulty

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(25)
proto.add(elements=[DataDifficulty(2, 0, 0)])
for _ in range(24):
  proto.add()
proto.add(elements=[DataDifficulty(1, 1, 0)])

proto.add(elements=[DataDifficulty(2, 1, 0)])

with open("e2e/Vectors/Consensus/Difficulties/DataDifficulty.json", "w") as vectors:
  vectors.write(json.dumps(proto.toJSON()))
