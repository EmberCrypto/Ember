#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DataDifficulty object.
import ../../../Database/Consensus/Elements/objects/DataDifficultyObj

#Common serialization functions.
import ../SerializeCommon

#SerializeElement method.
import SerializeElement
export SerializeElement

#Serialize a DataDifficulty.
method serialize*(
  dataDiff: DataDifficulty
): string {.inline, forceCheck: [].} =
  dataDiff.holder.toBinary(NICKNAME_LEN) &
  dataDiff.nonce.toBinary(INT_LEN) &
  dataDiff.difficulty.toBinary(INT_LEN)

#Serialize a DataDifficulty for signing or a MeritRemoval.
method serializeWithoutHolder*(
  dataDiff: DataDifficulty
): string {.inline, forceCheck: [].} =
  char(DATA_DIFFICULTY_PREFIX) &
  dataDiff.nonce.toBinary(INT_LEN) &
  dataDiff.difficulty.toBinary(INT_LEN)

#Serialize a DataDifficulty for inclusion in a BlockHeader's contents Merkle.
method serializeContents*(
  dataDiff: DataDifficulty
): string {.inline, forceCheck: [].} =
  char(DATA_DIFFICULTY_PREFIX) &
  dataDiff.serialize()

#Serialize a Signed DataDifficulty.
method signedSerialize*(
  dataDiff: SignedDataDifficulty
): string {.inline, forceCheck: [].} =
  dataDiff.serialize() &
  dataDiff.signature.serialize()
