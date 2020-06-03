import strutils

import ../Errors
import ../Util

import objects/HashObj
export HashObj

proc toHash*[bits: static int](
  hash: string
): Hash[bits] {.forceCheck: [
  ValueError
].} =
  if hash.len != bits div 8:
    panic("toHash (string) not handed the right amount of data.")
  for b in 0 ..< hash.len:
    result.data[b] = byte(hash[b])

proc toHash*[bits: static int](
  hash: openArray[byte]
): Hash[bits] {.forceCheck: [
  ValueError
].} =
  if hash.len != bits div 8:
    panic("toHash (openArray) not handed the right amount of data.")
  for b in 0 ..< hash.len:
    result.data[b] = hash[b]

func serialize*(
  hash: Hash
): string {.forceCheck: [].} =
  for b in hash.data:
    result &= char(b)

func `$`*(
  hash: Hash
): string {.inline, forceCheck: [].} =
  hash.serialize().toHex()

func empty*(
  hash: Hash
): bool {.forceCheck: [].} =
  for b in hash.data:
    if b != 0:
      return false
  result = true

func `<`*[bits: static[int]](
  lhs: Hash[bits],
  rhs: Hash[bits]
): bool =
  var bytes: int = bits div 8
  for i in 0 ..< bytes:
    if lhs.data[i] == rhs.data[i]:
      continue
    elif lhs.data[i] < rhs.data[i]:
      return true
    else:
      return false
  return false

func `<=`*[bits: static[int]](
  lhs: Hash[bits],
  rhs: Hash[bits]
): bool =
  var bytes: int = bits div 8
  for i in 0 ..< bytes:
    if lhs.data[i] == rhs.data[i]:
      continue
    elif lhs.data[i] < rhs.data[i]:
      return true
    else:
      return false
  return true

func `>`*[bits: static[int]](
  lhs: Hash[bits],
  rhs: Hash[bits]
): bool =
  var bytes: int = bits div 8
  for i in 0 ..< bytes:
    if lhs.data[i] == rhs.data[i]:
      continue
    elif lhs.data[i] > rhs.data[i]:
      return true
    else:
      return false
  return false

func `>=`*[bits: static[int]](
  lhs: Hash[bits],
  rhs: Hash[bits]
): bool =
  var bytes: int = bits div 8
  for i in 0 ..< bytes:
    if lhs.data[i] == rhs.data[i]:
      continue
    elif lhs.data[i] > rhs.data[i]:
      return true
    else:
      return false
  return true

func `==`*[bits: static[int]](
  lhs: Hash[bits],
  rhs: Hash[bits]
): bool =
  var bytes: int = bits div 8
  for i in 0 ..< bytes:
    if lhs.data[i] == rhs.data[i]:
      continue
    else:
      return false
  return true
