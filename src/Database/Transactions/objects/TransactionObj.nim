#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

type
    #Transaction input types.
    Input* = ref object of RootObj
        hash*: Hash[256]
    #FundedInput, which also includes a nonce.
    FundedInput* = ref object of Input
        nonce*: int

    #Transaction output types.
    Output* = ref object of RootObj
        amount*: uint64
    #MintOutput, which sends to a MeritHolder nickname.
    MintOutput* = ref object of Output
        key*: uint16
    #SendOutput, which sends to an EdPublicKey. This also used by Claim.
    SendOutput* = ref object of Output
        key*: EdPublicKey

    #Transaction object.
    Transaction* = ref object of RootObj
        #Input transactions.
        inputs*: seq[Input]
        #Outputs,
        outputs*: seq[Output]
        #Hash.
        hash*: Hash[256]

#Input/Output constructors.
func newInput*(
    hash: Hash[256]
): Input {.inline, forceCheck: [].} =
    Input(
        hash: hash
    )

func newFundedInput*(
    hash: Hash[256],
    nonce: int
): FundedInput {.inline, forceCheck: [].} =
    FundedInput(
        hash: hash,
        nonce: nonce
    )

func newOutput*(
    amount: uint64
): Output {.inline, forceCheck: [].} =
    Output(
        amount: amount
    )

func newMintOutput*(
    key: uint16,
    amount: uint64
): MintOutput {.inline, forceCheck: [].} =
    MintOutput(
        key: key,
        amount: amount
    )

func newClaimOutput*(
    key: EdPublicKey
): SendOutput {.inline, forceCheck: [].} =
    SendOutput(
        key: key
    )

func newSendOutput*(
    key: EdPublicKey,
    amount: uint64
): SendOutput {.inline, forceCheck: [].} =
    SendOutput(
        key: key,
        amount: amount
    )

func newSendOutput*(
    addy: Address,
    amount: uint64
): SendOutput {.forceCheck: [].} =
    case addy.addyType:
        of AddressType.PublicKey:
            var key: EdPublicKey
            for b in 0 ..< 32:
                key.data[b] = cuchar(addy.data[b])

            result = newSendOutput(
                key,
                amount
            )
