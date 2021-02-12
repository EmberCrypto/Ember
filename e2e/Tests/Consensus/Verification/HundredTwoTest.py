#https://github.com/MerosCrypto/Meros/issues/102.

from typing import Dict, Any
import json

from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def HundredTwoTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/Verification/HundredTwo.json", "r") as file:
    vectors = json.loads(file.read())

  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  #Verifies the Transaction is added, it has the right holders, the holders Merit surpasses the threshold, yet it isn't verified.
  def verify() -> None:
    for tx in transactions.txs:
      status: Dict[str, Any] = rpc.call("consensus", "getStatus", {"hash": tx.hex()})
      if set(status["verifiers"]) != set([0, 1]):
        raise TestError("Meros doesn't have the right list of verifiers for this Transaction.")

      if status["merit"] != 80:
        raise TestError("Meros doesn't have the right amount of Merit for this Transaction.")

      if (
        rpc.call("merit", "getMerit", {"nick": 0})["merit"] +
        rpc.call("merit", "getMerit", {"nick": 1})["merit"]
      ) < status["threshold"]:
        raise TestError("Merit sum of holders is less than the threshold.")

      if status["verified"]:
        raise TestError("Meros verified the Transaction which won't have enough Merit by the time the Transaction finalizes.")

  Liver(rpc, vectors["blockchain"], transactions, callbacks={100: verify}).live()
