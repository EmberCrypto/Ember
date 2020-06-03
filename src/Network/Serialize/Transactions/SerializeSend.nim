#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Send object.
import ../../../Database/Transactions/objects/SendObj

#Common serialization functions.
import ../SerializeCommon

#SerializeTransaction method.
import SerializeTransaction
export SerializeTransaction

#Serialization functions.
method serializeHash*(
  send: Send
): string {.forceCheck: [].} =
  result = "\2" & char(send.inputs.len)
  for input in send.inputs:
    result &=
      input.hash.serialize() &
      cast[FundedInput](input).nonce.toBinary(BYTE_LEN)
  result &= char(send.outputs.len)
  for output in send.outputs:
    result &=
      cast[SendOutput](output).key.toString() &
      output.amount.toBinary(MEROS_LEN)

method serialize*(
  send: Send
): string {.inline, forceCheck: [].} =
  #Serialize the inputs.
  result = $char(send.inputs.len)
  for input in send.inputs:
    result &=
      input.hash.serialize() &
      char(cast[FundedInput](input).nonce)

  #Serialize the outputs.
  result &= char(send.outputs.len)
  for output in send.outputs:
    result &=
      cast[SendOutput](output).key.toString() &
      output.amount.toBinary(MEROS_LEN)

  result &=
    send.signature.toString() &
    send.proof.toBinary(INT_LEN)
