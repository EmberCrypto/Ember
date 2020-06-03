import ../../../../../lib/[Errors, Util]
import ../../../../../Wallet/Wallet

import ../../../../Transactions/objects/TransactionObj

import ../../../../../Network/Serialize/SerializeCommon

proc parseSendOutput*(
  outputStr: string
): SendOutput {.forceCheck: [
  ValueError
].} =
  #Key | Amount
  var outputSeq: seq[string] = outputStr.deserialize(
    ED_PUBLIC_KEY_LEN,
    MEROS_LEN
  )

  #Create the SendOutput.
  try:
    result = newSendOutput(
      newEdPublicKey(outputSeq[0]),
      uint64(outputSeq[1].fromBinary())
    )
  except ValueError as e:
    raise e
