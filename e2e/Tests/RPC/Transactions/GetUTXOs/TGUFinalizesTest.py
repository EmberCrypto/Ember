#Tests a Transaction which is never verified, yet does finalize as the winner, creates UTXOs.

from typing import Dict, Any
import json

import ed25519
from bech32 import convertbits, bech32_encode
from pytest import raises

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.RPC.Transactions.GetUTXOs.Lib import createSend, verify, mineBlock
from e2e.Tests.Errors import TestError, SuccessError

def TGUFinalizesTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "r") as file:
    vectors = json.loads(file.read())
  transactions: Transactions = Transactions.fromJSON(vectors["transactions"])

  def actualTest() -> None:
    recipient: ed25519.SigningKey = ed25519.SigningKey(b'\1' * 32)
    recipientPub: bytes = recipient.get_verifying_key().to_bytes()
    address: str = bech32_encode("mr", convertbits(bytes([0]) + recipientPub, 8, 5))

    otherRecipient: bytes = ed25519.SigningKey(b'\2' * 32).get_verifying_key().to_bytes()
    otherAddress: str = bech32_encode("mr", convertbits(bytes([0]) + otherRecipient, 8, 5))

    #Create a Send.
    send: Send = createSend(rpc, [Claim.fromJSON(vectors["olderMint"])], recipientPub)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros considered an unconfirmed Transaction's outputs as UTXOs.")
    verify(rpc, send.hash)

    #Spend it.
    spendingSend: Send = createSend(rpc, [send], otherRecipient, recipient)
    if rpc.call("transactions", "getUTXOs", {"address": address}) != []:
      raise TestError("Meros didn't consider a Transaction's inputs as spent.")

    #Verify with another party, so it won't be majority verified, yet will still have a Verification.
    mineBlock(rpc, 1)
    verify(rpc, spendingSend.hash, 1)
    #Verify it didn't create a UTXO.
    if rpc.call("transactions", "getUTXOs", {"address": otherAddress}) != []:
      raise TestError("Unverified Transaction created a UTXO.")

    #Finalize.
    for _ in range(6):
      mineBlock(rpc)

    #Check the UTXOs were created.
    if rpc.call("transactions", "getUTXOs", {"address": otherAddress}) != [{"hash": spendingSend.hash.hex().upper(), "nonce": 0}]:
      raise TestError("Meros didn't consider a finalized Transaction's outputs as UTXOs.")

    raise SuccessError()

  #Send Blocks so we have a Merit Holder who can instantly verify Transactions, not to mention Mints.
  with raises(SuccessError):
    Liver(rpc, vectors["blockchain"], transactions, {50: actualTest}).live()
