#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash and Merkle libs.
import ../../lib/Hash
import ../../lib/Merkle

#Sketcher lib.
import ../../lib/Sketcher

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Element libs.
import ../Consensus/Elements/Elements

#BlockHeader object.
import objects/BlockHeaderObj
export BlockHeaderObj

#SerializeCommon lib.
import ../../Network/Serialize/SerializeCommon

#Element Serialization libs.
import ../../Network/Serialize/Consensus/SerializeVerification
import ../../Network/Serialize/Consensus/SerializeSendDifficulty
import ../../Network/Serialize/Consensus/SerializeDataDifficulty
import ../../Network/Serialize/Consensus/SerializeVerificationPacket
import ../../Network/Serialize/Consensus/SerializeMeritRemoval

#BlockHeader Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Algorithm standard lib.
import algorithm

#Sign and hash the header.
proc hash*(
    rx: RandomX,
    miner: MinerWallet,
    header: var BlockHeader,
    proof: uint32
) {.forceCheck: [].} =
    header.proof = proof
    rx.hash(miner, header, header.serializeHash(), proof)

#Hash the header.
proc hash*(
    rx: RandomX,
    header: var BlockHeader
) {.forceCheck: [].} =
    rx.hash(
        header,
        header.serializeHash()
    )

#Create a sketchCheck Merkle.
proc newSketchCheck*(
    sketchSalt: string,
    packets: seq[VerificationPacket]
): Hash[256] {.forceCheck: [].} =
    var
        sketchHashes: seq[uint64] = @[]
        calculated: Merkle = newMerkle()

    for packet in packets:
        sketchHashes.add(sketchHash(sketchSalt, packet))
    sketchHashes.sort(SortOrder.Descending)

    for hash in sketchHashes:
        calculated.add(Blake256(hash.toBinary(SKETCH_HASH_LEN)))

    result = calculated.hash

#Create a contents Merkle.
proc newContents*(
    packets: seq[VerificationPacket],
    elements: seq[BlockElement]
): tuple[packets: Hash[256], contents: Hash[256]] {.forceCheck: [].} =
    var
        packetsMerkle: Merkle = newMerkle()
        elementsMerkle: Merkle = newMerkle()
        empty: bool = true

    for packet in sorted(
        packets,
        func (
            x: VerificationPacket,
            y: VerificationPacket
        ): int {.forceCheck: [].} =
            if x.hash > y.hash:
                result = 1
            else:
                result = -1
        , SortOrder.Descending
    ):
        empty = false
        packetsMerkle.add(Blake256(packet.serializeContents()))

    for elem in elements:
        empty = false
        elementsMerkle.add(Blake256(elem.serializeContents()))

    if not empty:
        result = (
            packets: packetsMerkle.hash,
            contents: Blake256(packetsMerkle.hash.toString() & elementsMerkle.hash.toString())
        )

#Constructor.
proc newBlockHeader*(
    version: uint32,
    last: RandomXHash,
    contents: Hash[256],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[256],
    miner: BLSPublicKey,
    time: uint32,
    proof: uint32 = 0,
    signature: BLSSignature = newBLSSignature(),
    rx: RandomX = nil
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        contents,
        significant,
        sketchSalt,
        sketchCheck,
        miner,
        time,
        proof,
        signature
    )
    if (not signature.isInf) and (not rx.isNil):
        rx.hash(result)

proc newBlockHeader*(
    version: uint32,
    last: RandomXHash,
    contents: Hash[256],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[256],
    miner: uint16,
    time: uint32,
    proof: uint32 = 0,
    signature: BLSSignature = newBLSSignature(),
    rx: RandomX = nil
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        contents,
        significant,
        sketchSalt,
        sketchCheck,
        miner,
        time,
        proof,
        signature
    )
    if (not signature.isInf) and (not rx.isNil):
        rx.hash(result)
