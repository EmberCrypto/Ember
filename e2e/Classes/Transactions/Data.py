from typing import Dict, Tuple, Any
from hashlib import blake2b

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transaction import Transaction
from e2e.Classes.Consensus.SpamFilter import SpamFilter

class Data(
  Transaction
):
  def __init__(
    self,
    txInput: bytes,
    data: bytes,
    signature: bytes = bytes(64),
    proof: int = 0
  ) -> None:
    self.txInput: bytes = txInput
    self.data: bytes = data
    self.hash: bytes = blake2b(b"\3" + txInput + data, digest_size=32).digest()
    self.signature: bytes = signature

    self.proof: int = proof
    self.argon: bytes = SpamFilter.run(self.hash, self.proof)

  #Satisifes static typing requirements.
  @staticmethod
  def fromTransaction(
    tx: Transaction
  ) -> Any:
    return tx

  def sign(
    self,
    privKey: Ristretto.SigningKey
  ) -> None:
    self.signature = privKey.sign(b"MEROS" + self.hash)

  def beat(
    self,
    spamFilter: SpamFilter
  ) -> None:
    result: Tuple[bytes, int] = spamFilter.beat(self.hash, (101 + len(self.data)) // 102)
    self.argon = result[0]
    self.proof = result[1]

  def serialize(
    self
  ) -> bytes:
    return (
      self.txInput +
      (len(self.data) - 1).to_bytes(1, "little") +
      self.data +
      self.signature +
      self.proof.to_bytes(4, "little")
    )

  def toJSON(
    self
  ) -> Dict[str, Any]:
    return {
      "descendant": "Data",
      "inputs": [{
        "hash": self.txInput.hex().upper()
      }],
      "outputs": [],
      "hash": self.hash.hex().upper(),
      "data": self.data.hex().upper(),
      "signature": self.signature.hex().upper(),

      "proof": self.proof
    }

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return Data(
      bytes.fromhex(json["inputs"][0]["hash"]),
      bytes.fromhex(json["data"]),
      bytes.fromhex(json["signature"]),
      json["proof"]
    )
