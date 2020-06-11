from typing import Dict, List, Optional, Any

from e2e.Classes.Transactions.Mint import Mint
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Classes.Merit.State import State
from e2e.Classes.Merit.Epochs import Epochs

class Merit:
  def __init__(
    self
  ) -> None:
    self.blockchain: Blockchain = Blockchain()
    self.state: State = State()
    self.epochs = Epochs()
    self.mints: List[Mint] = []

  def add(
    self,
    block: Block
  ) -> None:
    self.blockchain.add(block)

    mint: Optional[Mint] = self.epochs.shift(
      self.state,
      self.blockchain,
      len(self.blockchain.blocks) - 1
    )
    if mint is not None:
      self.mints.append(mint)

    self.state.add(self.blockchain, len(self.blockchain.blocks) - 1)

  def toJSON(
    self
  ) -> List[Dict[str, Any]]:
    return self.blockchain.toJSON()

  @staticmethod
  def fromJSON(
    json: List[Dict[str, Any]]
  ) -> Any:
    result: Merit = Merit.__new__(Merit)
    result.blockchain = Blockchain.fromJSON(json)
    result.state = State()
    result.epochs = Epochs()
    result.mints = []

    for b in range(1, len(result.blockchain.blocks)):
      mint: Optional[Mint] = result.epochs.shift(
        result.state,
        result.blockchain,
        b
      )
      if mint is not None:
        result.mints.append(mint)

      result.state.add(result.blockchain, b)
    return result
