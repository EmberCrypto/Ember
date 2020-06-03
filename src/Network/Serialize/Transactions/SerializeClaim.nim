#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/Wallet
import ../../../Wallet/MinerWallet

#Claim object.
import ../../../Database/Transactions/objects/ClaimObj

#SerializeTransaction method.
import SerializeTransaction
export SerializeTransaction

#Serialization functions.
method serializeHash*(
  claim: Claim
): string {.inline, forceCheck: [].} =
  "\1" &
  claim.signature.serialize()

method serialize*(
  claim: Claim
): string {.inline, forceCheck: [].} =
  #Serialize the inputs.
  result = $char(claim.inputs.len)
  for input in claim.inputs:
    result &= input.hash.serialize() & char(cast[FundedInput](input).nonce)

  #Serialize the output and signature.
  result &=
    cast[SendOutput](claim.outputs[0]).key.toString() &
    claim.signature.serialize()
