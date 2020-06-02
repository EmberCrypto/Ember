#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Address and Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/Address

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Transactions lib.
import ../../../Database/Transactions/Transactions

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#String utils standard lib.
import strutils

#Transaction -> JSON.
proc `%`(
  tx: Transaction
): JSONNode {.forceCheck: [].} =
  result = %* {
    "inputs": [],
    "outputs": [],
    "hash": $tx.hash
  }

  try:
    if not (tx of Mint):
      for input in tx.inputs:
        result["inputs"].add(%* {
          "hash": $input.hash
        })

    if not (tx of Data):
      for output in tx.outputs:
        result["outputs"].add(%* {
          "amount": $output.amount
        })
  except KeyError as e:
    panic("Couldn't add inputs/outputs to input/output arrays we just created: " & e.msg)

  case tx:
    of Mint as mint:
      result["descendant"] = % "Mint"

      try:
        for o in 0 ..< result["outputs"].len:
          result["outputs"][o]["key"] = % $cast[MintOutput](mint.outputs[o]).key
      except KeyError as e:
        panic("Couldn't add a Mint's output's key to its output: " & e.msg)

    of Claim as claim:
      result["descendant"] = % "Claim"

      try:
        for i in 0 ..< claim.inputs.len:
          result["inputs"][i]["nonce"] = % cast[FundedInput](claim.inputs[i]).nonce
        for o in 0 ..< claim.outputs.len:
          result["outputs"][o]["key"] = % $cast[SendOutput](claim.outputs[o]).key
      except KeyError as e:
        panic("Couldn't add a Claim's outputs' keys to its outputs: " & e.msg)

      result["signature"] = % $claim.signature

    of Send as send:
      result["descendant"] = % "Send"

      try:
        for i in 0 ..< send.inputs.len:
          result["inputs"][i]["nonce"] = % cast[FundedInput](send.inputs[i]).nonce
        for o in 0 ..< send.outputs.len:
          result["outputs"][o]["key"] = % $cast[SendOutput](send.outputs[o]).key
      except KeyError as e:
        panic("Couldn't add a Send's inputs' nonces/outputs' keys to its inputs/outputs: " & e.msg)

      result["signature"] = % $send.signature
      result["proof"] = % send.proof
      result["argon"] = % $send.argon

    of Data as data:
      result["descendant"] = % "Data"

      result["data"] = % data.data.toHex()

      result["signature"] = % $data.signature
      result["proof"] = % data.proof
      result["argon"] = % $data.argon

#Create the Transactions module.
proc module*(
  functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
  try:
    newRPCFunctions:
      #Get a Transaction by hash.
      "getTransaction" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [
        ParamError,
        JSONRPCError
      ].} =
        #Verify the parameters.
        if (
          (params.len != 1) or
          (params[0].kind != JString)
        ):
          raise newLoggedException(ParamError, "")

        #Get the Transaction.
        try:
          res["result"] = % functions.transactions.getTransaction(params[0].getStr().toHash(256))
        except IndexError:
          raise newJSONRPCError(-2, "Transaction not found")
        except ValueError:
          raise newJSONRPCError(-3, "Invalid hash")

      #Get a key's balance.
      "getBalance" = proc (
        res: JSONNode,
        params: JSONNode
      ) {.forceCheck: [
        ParamError
      ].} =
        #Verify the parameters.
        if (
          (params.len != 1) or
          (params[0].kind != JString)
        ):
          raise newLoggedException(ParamError, "")

        #Get the UTXOs.
        var
          decodedAddy: Address
          utxos: seq[FundedInput]
        try:
          decodedAddy = Address.getEncodedData(params[0].getStr())
        except ValueError:
          raise newLoggedException(ParamError, "")

        case decodedAddy.addyType:
          of AddressType.PublicKey:
            try:
              utxos = functions.transactions.getUTXOs(
                newEdPublicKey(
                  cast[string](decodedAddy.data)
                )
              )
            except ValueError:
              raise newLoggedException(ParamError, "")

        var balance: uint64 = 0
        for utxo in utxos:
          try:
            balance += cast[SendOutput](functions.transactions.getTransaction(utxo.hash).outputs[utxo.nonce]).amount
          except IndexError as e:
            doAssert(false, "Failed to get a Transaction which was a spendable UTXO: " & e.msg)
        res["result"] = % $balance
  except Exception as e:
    panic("Couldn't create the Transactions Module: " & e.msg)
