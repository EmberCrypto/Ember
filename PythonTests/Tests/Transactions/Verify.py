#Transactions classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Transactions.Transactions import Transactions

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#RPC class.
from PythonTests.Meros.RPC import RPC

#Sleep standard function.
from time import sleep

#Verify a Transaction.
def verifyTransaction(
    rpc: RPC,
    tx: Transaction
) -> None:
    if rpc.call("transactions", "getTransaction", [tx.hash.hex()]) != tx.toJSON():
        raise TestError("Transaction doesn't match.")

#Verify the Transactions.
def verifyTransactions(
    rpc: RPC,
    transactions: Transactions
) -> None:
    #Sleep to ensure data races aren't a problem.
    sleep(2)

    for tx in transactions.txs:
        verifyTransaction(rpc, transactions.txs[tx])
