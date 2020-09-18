#This used to be a dependency for other generators.
#Now, it's solely used by tests who need a blank chain.

import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

with open("e2e/Vectors/Merit/BlankBlocks.json", "w") as vectors:
  vectors.write(json.dumps(PrototypeChain(25, keepUnlocked=False).toJSON()))
