#Serialize Claim Tests.

#BLS lib.
import ../../../../src/lib/BLS

#MinerWallet lib.
import ../../../../src/Database/Merit/MinerWallet

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Claim lib.
import ../../../../src/Database/Lattice/Claim

#Serialize lib.
import ../../../../src/Network/Serialize/Lattice/SerializeClaim
import ../../../../src/Network/Serialize/Lattice/ParseClaim

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Claim Serialization/Parsing, iteration " & $i & "."

    var
        #People.
        miner: MinerWallet = newMinerWallet()
        claimer: Wallet = newWallet()
        #Claim.
        claim: Claim

    #Create the Claim.
    claim = newClaim(
        0,
        0
    )

    #Sign it.
    claim.sign(miner, claimer)

    #Serialize it and parse it back.
    var claimParsed: Claim = claim.serialize().parseClaim()

    #Test the serialized versions.
    assert(claim.serialize() == claimParsed.serialize())

    #Test the Entry properties.
    assert(
        claim.descendant == claimParsed.descendant,
        "Descendant:\r\n" & $claim.descendant & "\r\n" & $claimParsed.descendant
    )
    assert(
        claim.sender == claimParsed.sender,
        "Sender:\r\n" & claim.sender & "\r\n" & claimParsed.sender
    )
    assert(
        claim.nonce == claimParsed.nonce,
        "Nonce:\r\n" & $claim.nonce & "\r\n" & $claimParsed.nonce
    )
    assert(
        claim.hash == claimParsed.hash,
        "Hash:\r\n" & $claim.hash & "\r\n" & $claimParsed.hash
    )
    assert(
        claim.signature == claimParsed.signature,
        "Signature:\r\n" & claim.signature & "\r\n" & claimParsed.signature
    )

    #Test the Claim properties.
    assert(
        claim.mintNonce == claimParsed.mintNonce,
        "Mint Nonce:\r\n" & $claim.mintNonce & "\r\n" & $claimParsed.mintNonce
    )
    assert(
        claim.bls == claimParsed.bls,
        "BLS Signature:\r\n" & $claim.bls & "\r\n" & $claimParsed.bls
    )

echo "Finished the Network/Serialize/Lattice/Claim test."
