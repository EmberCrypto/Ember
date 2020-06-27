from typing import IO, Any
import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

main: PrototypeChain = PrototypeChain(25, False)
alt: PrototypeChain = PrototypeChain(15, False)

#Update the time of the alt chain to be much short, causing a much higher amount of work per Block.
alt.timeOffset = 1
for _ in range(5):
  alt.add(1)

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/ShorterChainMoreWork.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
