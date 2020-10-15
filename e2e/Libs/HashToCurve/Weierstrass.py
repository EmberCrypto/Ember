from typing import Type, Callable, Tuple
from abc import abstractmethod

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement
from e2e.Libs.HashToCurve.HashToCurve import Curve, SuiteParameters

#pylint: disable=too-few-public-methods
class WeierstrassCurve(
  Curve
):
  def __init__(
    self,
    fieldType: Type[FieldElement],
    groupType: Type[GroupElement],
    primeField: bool,
    p: int,
    m: int,
    #pylint: disable=invalid-name
    A: int,
    #pylint: disable=invalid-name
    B: int,
    #pylint: disable=invalid-name
    isogenousA: int,
    #pylint: disable=invalid-name
    isogenousB: int,
    #pylint: disable=invalid-name
    Z: int
  ) -> None:
    Curve.__init__(self, fieldType, groupType, primeField, p, m)
    #pylint: disable=invalid-name
    self.A: int = A
    #pylint: disable=invalid-name
    self.B: int = B

    #This my be a misuse of isogeny, where we may want the underlying Curve to have these values.
    #The following SSWU algorithms also always use the isogenous points which isn't correct.
    #That said, this code can be used with a curve which isn't complimented by mirroring the A/B values.
    #So theoretically incorrect, yet the code works, especially since we only need this for BLS12-381 G1 which has an isogenous compliment.
    self.isogenousA: int = isogenousA
    self.isogenousB: int = isogenousB

    #pylint: disable=invalid-name
    self.Z: int = Z

  @abstractmethod
  def mapToCurve(
    self,
    u: FieldElement
  ) -> GroupElement:
    ...

#pylint: disable=too-few-public-methods
class WeierstrassSuiteParameters(
  SuiteParameters
):
  curve: WeierstrassCurve

  def __init__(
    self,
    curve: WeierstrassCurve,
    dst: str,
    k: int,
    #pylint: disable=invalid-name
    L: int,
    expandMessage: Callable[[bytes, int], bytes]
  ) -> None:
    SuiteParameters.__init__(self, curve, dst, k, L, expandMessage)

#The following mapToCurve functions aren't usable by BLS12-381 G1.
#They require a wrapping isogeny map.

#pylint: disable=too-many-locals
def mapToCurveSSWU(
  curve: WeierstrassCurve,
  u: FieldElement
) -> Tuple[FieldElement, FieldElement]:
  #pylint: disable=invalid-name
  A: int = curve.isogenousA
  #pylint: disable=invalid-name
  B: int = curve.isogenousB
  #pylint: disable=invalid-name
  Z: FieldElement = curve.FieldType(curve.Z)

  #Steps 1-3.
  tv1: FieldElement = (((Z ** 2) * (u ** 4)) + (Z * (u ** 2))) ** (curve.q - 2)
  x1: FieldElement = (curve.FieldType(B).negative().div(curve.FieldType(A), curve.q)) * (tv1 + 1)
  if tv1 == curve.FieldType(0):
    x1 = curve.FieldType(B).div(Z * A, curve.q)

  #Steps 4-6.
  gx1: FieldElement = (x1 ** 3) + (x1 * A) + B
  x2: FieldElement = Z * (u ** 2) * x1
  gx2: FieldElement = (x2 ** 3) + (x2 * A) + B

  #Steps 7-8.
  x: FieldElement
  y: FieldElement
  sqrCheck: FieldElement = gx1 ** ((curve.q - 1) // 2)
  if (sqrCheck == curve.FieldType(0)) or (sqrCheck == curve.FieldType(1)):
    x = x1
    y = gx1.sqrt()
  else:
    x = x2
    y = gx2.sqrt()

  #Step 9.
  if u.sign() != y.sign():
    y = y.negative()

  #Step 10.
  return (x, y)

#pylint: disable=too-many-locals
def mapToCurveSSWUStraightLine(
  curve: WeierstrassCurve,
  u: FieldElement
) -> Tuple[FieldElement, FieldElement]:
  #pylint: disable=invalid-name
  A: FieldElement = curve.FieldType(curve.isogenousA)
  #pylint: disable=invalid-name
  B: FieldElement = curve.FieldType(curve.isogenousB)
  #pylint: disable=invalid-name
  Z: FieldElement = curve.FieldType(curve.Z)

  C1: FieldElement = B.negative().div(A, curve.q)
  C2: FieldElement = curve.FieldType(1).negative().div(Z, curve.q)

  #Steps 1-2.
  tv1: FieldElement = Z * (u ** 2)
  tv2: FieldElement = tv1 ** 2

  #Steps 3-8.
  x1: FieldElement = ((tv1 + tv2) ** (curve.q - 2)) + 1
  if x1 == curve.FieldType(1):
    x1 = C2
  x1 = x1 * C1

  #Steps 9-12.
  gx1: FieldElement = (((x1 ** 2) + A) * x1) + B

  #Steps 13-15.
  x2: FieldElement = tv1 * x1
  tv2 = tv1 * tv2
  gx2: FieldElement = gx1 * tv2

  #Steps 16-19.
  x: FieldElement
  y: FieldElement
  sqrCheck: FieldElement = gx1 ** ((curve.q - 1) // 2)
  if (sqrCheck == curve.FieldType(0)) or (sqrCheck == curve.FieldType(1)):
    x = x1
    y = gx1
  else:
    x = x2
    y = gx2
  y = y.sqrt()

  #Step 20-21.
  if u.sign() != y.sign():
    y = y.negative()

  #Step 22.
  return (x, y)

#pylint: disable=too-many-locals
def mapToCurveSSWU3Mod4(
  curve: WeierstrassCurve,
  u: FieldElement
) -> Tuple[FieldElement, FieldElement]:
  #Constants.
  #pylint: disable=invalid-name
  C1: int = (curve.q - 3) // 4
  #pylint: disable=invalid-name
  C2: FieldElement = (curve.FieldType(curve.Z) ** 3).negative().sqrt()

  #Steps 1-3.
  tv1: FieldElement = u ** 2
  tv3: FieldElement = tv1 * curve.Z
  tv2: FieldElement = tv3 ** 2

  #Steps 4-7.
  xd: FieldElement = tv2 + tv3
  x1n: FieldElement = (xd + 1) * curve.isogenousB
  xd = xd * curve.FieldType(curve.isogenousA).negative()

  #Steps 8-9.
  if xd == curve.FieldType(0):
    xd = curve.FieldType(curve.isogenousA) * curve.Z

  #Steps 10-12.
  gxd: FieldElement = xd ** 3
  tv2 = (xd ** 2) * curve.isogenousA

  #Steps 13-15.
  gx1: FieldElement = ((x1n ** 2) + tv2) * x1n

  #Steps 16-20.
  tv2 = gxd * curve.isogenousB
  gx1 = gx1 + tv2
  tv4: FieldElement = gxd ** 2
  tv2 = gx1 * gxd
  tv4 = tv4 * tv2

  #Steps 21-26.
  y1: FieldElement = (tv4 ** C1) * tv2
  x2n: FieldElement = tv3 * x1n
  y2: FieldElement = ((y1 * C2) * tv1) * u

  #Steps 27-28.
  tv2 = (y1 ** 2) * gxd

  #Steps 29-33.
  xn: FieldElement
  y: FieldElement
  xn, y = (x1n, y1) if tv2 == gx1 else (x2n, y2)
  if u.sign() != y.sign():
    y = y.negative()

  #Step 34.
  return (xn.div(xd, curve.q), y)
