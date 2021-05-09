from typing import List, Union

#pylint: disable=no-name-in-module,c-extension-no-member
import gmpy2
from gmpy2 import mpz

ZERO: mpz = mpz(0)
ONE: mpz = mpz(1)
TWO: mpz = mpz(2)
THREE: mpz = mpz(3)
FOUR: mpz = mpz(4)
EIGHT: mpz = mpz(8)

q: mpz = mpz(2**255 - 19)

class FieldElement:
  underlying: mpz

  def __init__(
    self,
    value: Union[mpz, int]
  ) -> None:
    if isinstance(value, int):
      value = mpz(value)
    self.underlying = (value + q) % q

  def __add__(
    self,
    other: 'FieldElement'
  ) -> 'FieldElement':
    return FieldElement(self.underlying + other.underlying)

  def __mul__(
    self,
    other: 'FieldElement'
  ) -> 'FieldElement':
    return FieldElement(self.underlying * other.underlying)

  def __sub__(
    self,
    other: 'FieldElement'
  ) -> 'FieldElement':
    return FieldElement(self.underlying - other.underlying)

  def isNegative(
    self
  ) -> bool:
    return (self.underlying & ONE) == ONE

  def negate(
    self
  ) -> 'FieldElement':
    return FieldElement(ZERO - self.underlying)

  def __floordiv__(
    self,
    other: mpz
  ) -> 'FieldElement':
    return FieldElement(self.underlying // other)

  def __mod__(
    self,
    other: mpz
  ) -> mpz:
    return self.underlying % other

  def __pow__(
    self,
    other: mpz
  ) -> 'FieldElement':
    return FieldElement(gmpy2.powmod(self.underlying, other, q))

  def inv(
    self
  ) -> 'FieldElement':
    return self ** (q - TWO)

  def recoverX(
    self
  ) -> 'FieldElement':
    d: FieldElement = FieldElement(-121665) * FieldElement(121666).inv()
    I: FieldElement = FieldElement(TWO) ** ((q - ONE) // FOUR)

    y2: FieldElement = self * self
    xx: FieldElement = (y2 - FieldElement(ONE)) * ((d * y2) + FieldElement(ONE)).inv()
    x: FieldElement = xx ** ((q + THREE) // EIGHT)
    if ((x * x) - xx).underlying != ZERO:
      x = x * I
    if x.isNegative():
      x = x.negate()
    return x

d: FieldElement = FieldElement(-121665) * FieldElement(121666).inv()
