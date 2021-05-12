import hashes

import mc_ristretto
export toPublicKey, `$`

import ../lib/[Errors, Hash]

#SIGN_PREFIX applied to every message, stopping cross-network replays.
const SIGN_PREFIX {.strdefine.}: string = "MEROS"

#Export the Private/Public Key objects (with a prefix).
type
  RistrettoPrivateKey* = PrivateKey
  RistrettoPublicKey* = PublicKey

proc newRistrettoPrivateKey*(
  key: seq[byte]
): RistrettoPrivateKey {.forceCheck: [].} =
  try:
    result = newPrivateKey(key)
  except ValueError as e:
    panic("Ristretto threw an error when parsing a private key: " & e.msg)

proc newRistrettoPublicKey*(
  key: string
): RistrettoPublicKey {.forceCheck: [].} =
  try:
    result = newPublicKey(cast[seq[byte]](key))
  except ValueError as e:
    panic("Ristretto threw an error when parsing a public key: " & e.msg)

func sign*(
  key: RistrettoPrivateKey,
  msg: string
): seq[byte] {.inline, forceCheck: [].} =
  mc_ristretto.sign(key, SIGN_PREFIX & msg)

func serialize*(
  key: RistrettoPublicKey
): string {.inline, forceCheck: [].} =
  cast[string](mc_ristretto.serialize(key))

proc verify*(
  key: RistrettoPublicKey,
  msg: string,
  sig: seq[byte]
): bool {.forceCheck: [].} =
  try:
    result = mc_ristretto.verify(key, SIGN_PREFIX & msg, sig)
  except ValueError as e:
    panic("Ristretto threw an error when verifying a signature: " & e.msg)

proc hasMultipleKeys*(
  keys: seq[RistrettoPrivateKey or RistrettoPublicKey]
): bool {.forceCheck: [].} =
  for key in keys:
    if key != keys[0]:
      return true

#Generates the `a` value to use for each key.
proc generateAs(
  keys: seq[RistrettoPublicKey]
): seq[Scalar] {.forceCheck: [].} =
  var L: string = ""
  for key in keys:
    L &= cast[string](key.serialize())
  L = Blake512(L).serialize()

  for key in keys:
    try:
      result.add(newScalar(@(Blake512("agg" & L & cast[string](key.serialize())).data)))
    except ValueError as e:
      panic("Ristretto couldn't reduce a 64-byte value to a Scalar: " & e.msg)

#Aggregate Public Keys for MuSig.
proc aggregate*(
  keys: seq[RistrettoPublicKey]
): RistrettoPublicKey {.forceCheck: [].} =
  if not keys.hasMultipleKeys:
    return keys[0]

  var As: seq[Scalar] = keys.generateAs()
  for k in 0 ..< keys.len:
    if k == 0:
      result = As[k] * keys[k]
    else:
      result = result + (As[k] * keys[k])

#Private key aggregation to create a private key matching the MuSig public key aggregation.
#Insecure in the scope of MuSig as it is solely meant to be used by internally known private keys.
#Not even close to what MuSig does.
proc aggregate*(
  keys: seq[RistrettoPrivateKey]
): RistrettoPrivateKey {.forceCheck: [].} =
  if not keys.hasMultipleKeys:
    return keys[0]

  var pubKeys: seq[RistrettoPublicKey] = @[]
  for key in keys:
    pubKeys.add(key.toPublicKey())

  var
    As: seq[Scalar] = generateAs(pubKeys)
    res: Scalar
  for k in 0 ..< keys.len:
    var key: RistrettoPrivateKey = keys[k]
    if k == 0:
      res = key * As[k]
    else:
      res = res + (key * As[k])

  #Traditional secret key expansion would be H512(secret), with the left half mod l.
  #We have a scalar, not a secret. In response, H512(scalar). Then, the scalar is the left half already.
  #This leaves us with just the right half left, which is still the right half of the H512 result.
  #We could also call urandom, which wouldn't be deterministic, or call H256 and just use that.
  var expanded: Hash.Hash[512] = Blake512(cast[string](res.serialize()))
  result = newRistrettoPrivateKey(res.serialize() & expanded.data[32 ..< 64])

proc hash*(
  key: RistrettoPublicKey
): hashes.Hash {.forceCheck: [].} =
  for b in key.serialize():
    result = result !& int(b)
  result = !$ result
