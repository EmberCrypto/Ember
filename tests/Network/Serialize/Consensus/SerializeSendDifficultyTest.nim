#Serialize SendDifficulty Test.

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../Database/Consensus/Elements/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeSendDifficulty
import ../../../../src/Network/Serialize/Consensus/ParseSendDifficulty

#Compare Consensus lib.
import ../../../Database/Consensus/CompareConsensus

#Random standard lib.
import random

suite "SerializeSendDiffculty":
    setup:
        var
            #SignedSendDifficulty Element.
            sendDiff: SignedSendDifficulty = newRandomSendDifficulty()
            #Reloaded SendDifficulty Element.
            reloadedSD: SendDifficulty = sendDiff.serialize().parseSendDifficulty()
            #Reloaded SignedSendDifficulty Element.
            reloadedSSD: SignedSendDifficulty = sendDiff.signedSerialize().parseSignedSendDifficulty()

    lowFuzzTest "Compare the Elements/serializations.":
        compare(sendDiff, reloadedSD)
        compare(sendDiff, reloadedSSD)
        check(sendDiff.signature == reloadedSSD.signature)

        check(sendDiff.serialize() == reloadedSD.serialize())
        check(sendDiff.signedSerialize() == reloadedSSD.signedSerialize())
