#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeSend

#Entry object.
import objects/EntryObj

#Send object.
import objects/SendObj
export SendObj

#Finals lib.
import finals

#Used to handle data strings.
import strutils

#Create a new Send.
proc newSend*(
    output: string,
    amount: BN,
    nonce: uint
): Send {.raises: [ValueError, FinalAttributeError].} =
    #Verify output.
    if not Address.verify(output):
        raise newException(ValueError, "Send output address is not valid.")

    #Verify the amount.
    if amount <= newBN(0):
        raise newException(ValueError, "Send amount is negative or zero.")

    #Craft the result.
    result = newSendObj(
        output,
        amount
    )

    #Set the nonce.
    result.nonce = nonce

    #Set the SHA512.
    result.sha512 = SHA512(result.serialize())

#'Mine' a TX (beat the spam filter).
proc mine*(
    send: Send,
    networkDifficulty: BN
) {.raises: [ValueError, ArgonError, FinalAttributeError].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: uint = 0
        hash: ArgonHash = Argon(send.sha512.toString(), proof.toBinary(), true)

    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(send.sha512.toString(), proof.toBinary(), true)

    send.proof = proof
    send.hash = hash

#Sign a TX.
func sign*(wallet: Wallet, send: Send): bool {.raises: [ValueError, SodiumError, FinalAttributeError].} =
    result = true

    #Make sure the Send was mined.
    if send.hash.toBN() == newBN():
        return false

    #Set the sender behind the Entry.
    send.sender = wallet.address
    #Sign the hash of the Send.
    send.signature = wallet.sign(send.hash.toString())
