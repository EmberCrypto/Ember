from typing import Dict, List, IO, Any
import json

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

correctVectorsHeight: bool = False
def PendingDieRegainTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/LockedMerit/PendingDieRegain.json", "r")
  chain: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  def verifyCorrectlyLocked(
    height: int
  ) -> None:
    merit: Dict[str, Any] = rpc.call("merit", "getMerit", [0])
    merit = {
      "merit": merit["merit"],
      "status": merit["status"]
    }

    if height < 9:
      if merit != {
        "merit": 1,
        "status": "Unlocked"
      }:
        raise TestError("Merit was locked early.")
    elif height < 100:
      if merit != {
        "merit": 1,
        "status": "Locked"
      }:
        raise TestError("Merit wasn't locked.")
    elif height == 100:
      if merit != {
        "merit": 1,
        "status": "Pending"
      }:
        raise TestError("Merit wasn't pending.")
    elif height == 101:
      if merit != {
        "merit": 0,
        "status": "Unlocked"
      }:
        raise TestError("Merit didn't die and become unlocked.")
    elif height == 102:
      #pylint: disable=global-statement
      global correctVectorsHeight
      correctVectorsHeight = True
      if merit != {
        "merit": 1,
        "status": "Unlocked"
      }:
        raise TestError("Didn't regain Merit which was unlocked.")

  Liver(rpc, chain, everyBlock=verifyCorrectlyLocked).live()

  if not correctVectorsHeight:
    raise Exception("PendingDieRegain vectors have an invalid length.")
