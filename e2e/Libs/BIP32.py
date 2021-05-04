#pylint: disable=invalid-name

from typing import List, Tuple
import hashlib
import hmac

#pylint: disable=no-name-in-module
from gmpy2 import mpz

import e2e.Libs.ed25519 as ed

HARDENED_THRESHOLD: int = 1 << 31

def hmac512(
  key: bytes,
  msg: bytes
) -> bytes:
  return hmac.new(key, msg, hashlib.sha512).digest()

def deriveKeyAndChainCode(
  secret: bytes,
  path: List[int]
) -> Tuple[bytes, bytes]:
  #Clamp the secret.
  k: bytes = ed.H(secret)
  kL: bytes = k[:32]
  kR: bytes = k[32:]
  if kL[31] & 0b00100000 != 0:
    raise Exception("Invalid secret to derive from.")
  kLArr: bytearray = bytearray(kL)
  kLArr[0] = (kL[0] >> 3) << 3
  kLArr[31] = ((kL[31] << 1) & 255) >> 1
  kLArr[31] = kLArr[31] | (1 << 6)
  kL = bytes(kLArr)
  k = kL + kR

  #Parent public key/chain code.
  A: bytes = ed.encodepoint(ed.scalarmult(ed.B, ed.decodeint(kL)))
  c: bytes = hashlib.sha256(bytes([1]) + secret).digest()

  #Derive each child.
  for i in path:
    iBytes: bytes = i.to_bytes(4, "little")
    Z: bytes
    if i < HARDENED_THRESHOLD:
      Z = hmac512(c, bytes([2]) + A + iBytes)
      c = hmac512(c, bytes([3]) + A + iBytes)[32:]
    else:
      Z = hmac512(c, bytes([0]) + k + iBytes)
      c = hmac512(c, bytes([1]) + k + iBytes)[32:]

    zL: bytearray = bytearray(Z[:28])
    for _ in range(4):
      zL.append(0)
    zR: bytes = Z[32:]
    #This should probably be mod l. That said, the paper isn't clear, and Meros defers to the existing impl.
    #Said existing impl is probably wrong.
    #While we could move to the proper form, it's unclear, and Meros is planning on moving to Ristretto anyways.
    #That will void all these concerns.
    kL = ed.encodeint((mpz(8) * ed.decodeint(bytes(zL))) + ed.decodeint(kL))
    if (ed.decodeint(kL) % ed.l) == 0:
      raise Exception("Invalid child.")
    kR = ed.encodeint((ed.decodeint(zR) + ed.decodeint(kR)) % mpz(1 << 256))
    k = kL + kR

    A = ed.encodepoint(ed.scalarmult(ed.B, ed.decodeint(kL)))

  return (k, c)

def derive(
  secret: bytes,
  path: List[int]
) -> bytes:
  key: bytes
  key, _ = deriveKeyAndChainCode(secret, path)
  return key
